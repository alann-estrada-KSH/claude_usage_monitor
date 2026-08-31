import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_settings.dart';
import '../models/claude_account.dart';

typedef LocalApiAccountsReader = List<ClaudeAccount> Function();
typedef LocalApiSettingsReader = AppSettings Function();

abstract interface class LocalApiSecretStore {
  Future<String?> read();
  Future<void> write(String value);
}

class _FlutterSecureSecretStore implements LocalApiSecretStore {
  _FlutterSecureSecretStore() : _storage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: 'local_api_secret_v1');

  @override
  Future<void> write(String value) =>
      _storage.write(key: 'local_api_secret_v1', value: value);
}

/// Optional desktop-only read API for local integrations.
///
/// It deliberately serves cached values only. It never reads or returns
/// cookies, tokens, raw provider responses, or diagnostic errors.
class LocalApiService extends ChangeNotifier {
  LocalApiService({LocalApiSecretStore? secretStore})
    : _secretStore = secretStore ?? _FlutterSecureSecretStore();

  static final instance = LocalApiService();

  static const _defaultPort = 47865;
  static const _reservedDevelopmentPorts = {
    3000,
    3001,
    4173,
    5000,
    5173,
    8000,
    8080,
    8888,
    9000,
  };

  final LocalApiSecretStore _secretStore;
  HttpServer? _server;
  String? _secret;
  LocalApiAccountsReader? _accountsReader;
  LocalApiSettingsReader? _settingsReader;
  int? _boundPreferredPort;
  DateTime? _rateWindowStartedAt;
  int _rateWindowRequests = 0;
  String? _lastError;

  bool get isSupported => Platform.isLinux || Platform.isWindows;
  bool get isRunning => _server != null;
  int? get actualPort => _server?.port;
  String? get lastError => _lastError;
  List<ClaudeAccount> get accounts =>
      List.unmodifiable(_accountsReader?.call() ?? const <ClaudeAccount>[]);

  void configure({
    required LocalApiAccountsReader accounts,
    required LocalApiSettingsReader settings,
  }) {
    _accountsReader = accounts;
    _settingsReader = settings;
  }

  static List<int> candidatePorts(int preferred) {
    final ports = <int>[];

    void add(int port) {
      if (port < AppSettings.minLocalApiPort ||
          port > AppSettings.maxLocalApiPort ||
          ports.contains(port)) {
        return;
      }
      ports.add(port);
    }

    add(preferred);
    for (
      var port = _defaultPort;
      ports.length < 256 && port <= AppSettings.maxLocalApiPort;
      port++
    ) {
      if (!_reservedDevelopmentPorts.contains(port)) add(port);
    }
    return ports;
  }

  static bool secretsMatch(String expected, String received) {
    final expectedBytes = sha256.convert(utf8.encode(expected)).bytes;
    final receivedBytes = sha256.convert(utf8.encode(received)).bytes;
    var difference = expectedBytes.length ^ receivedBytes.length;
    for (var i = 0; i < expectedBytes.length; i++) {
      difference |= expectedBytes[i] ^ receivedBytes[i];
    }
    return difference == 0;
  }

  static String _generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<bool> apply() async {
    if (!isSupported) {
      await stop();
      return false;
    }

    final settingsReader = _settingsReader;
    if (settingsReader == null || _accountsReader == null) {
      _lastError = 'Local API is not configured';
      notifyListeners();
      return false;
    }

    final settings = settingsReader();
    if (!settings.localApiEnabled) {
      await stop();
      _lastError = null;
      notifyListeners();
      return true;
    }

    try {
      await _ensureSecret();
      if (_server != null && _boundPreferredPort == settings.localApiPort) {
        _lastError = null;
        notifyListeners();
        return true;
      }

      await stop();
      SocketException? lastSocketError;
      for (final port in candidatePorts(settings.localApiPort)) {
        try {
          _server = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            port,
            shared: false,
          );
          _boundPreferredPort = settings.localApiPort;
          _server!.listen(_handleRequest);
          _lastError = null;
          notifyListeners();
          return true;
        } on SocketException catch (error) {
          lastSocketError = error;
        }
      }
      throw lastSocketError ?? StateError('No local API port available');
    } catch (_) {
      await stop();
      _lastError = 'Local API could not start';
      notifyListeners();
      return false;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _boundPreferredPort = null;
    if (server != null) await server.close(force: true);
    notifyListeners();
  }

  void forgetSecret() => _secret = null;

  Future<String?> readSecret() async {
    if (!isSupported) return null;
    _secret ??= await _secretStore.read();
    return _secret;
  }

  Future<String> regenerateSecret() async {
    final secret = _generateSecret();
    await _secretStore.write(secret);
    _secret = secret;
    notifyListeners();
    return secret;
  }

  Future<void> _ensureSecret() async {
    final current = await readSecret();
    if (current != null && current.length >= 32) return;
    await regenerateSecret();
  }

  bool _allowRequest() {
    final now = DateTime.now();
    final started = _rateWindowStartedAt;
    if (started == null ||
        now.difference(started) >= const Duration(minutes: 1)) {
      _rateWindowStartedAt = now;
      _rateWindowRequests = 0;
    }
    final limit = (_settingsReader?.call().localApiRateLimitPerMinute ?? 60)
        .clamp(
          AppSettings.minLocalApiRateLimitPerMinute,
          AppSettings.maxLocalApiRateLimitPerMinute,
        );
    if (_rateWindowRequests >= limit) return false;
    _rateWindowRequests++;
    return true;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final remoteAddress = request.connectionInfo?.remoteAddress.address;
      if (remoteAddress != '127.0.0.1' && remoteAddress != '::1') {
        await _writeError(
          request.response,
          HttpStatus.forbidden,
          'Acceso local requerido',
        );
        return;
      }
      if (request.uri.path.length > 2048 || request.contentLength > 8192) {
        await _writeError(
          request.response,
          HttpStatus.requestEntityTooLarge,
          'Solicitud demasiado grande',
        );
        return;
      }
      if (!_allowRequest()) {
        request.response.headers.set(HttpHeaders.retryAfterHeader, '60');
        await _writeError(
          request.response,
          HttpStatus.tooManyRequests,
          'Límite de solicitudes excedido',
        );
        return;
      }

      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      final receivedSecret =
          authorization != null && authorization.startsWith('Bearer ')
          ? authorization.substring(7).trim()
          : '';
      final expectedSecret = await readSecret();
      if (expectedSecret == null ||
          receivedSecret.isEmpty ||
          !secretsMatch(expectedSecret, receivedSecret)) {
        await _writeError(
          request.response,
          HttpStatus.unauthorized,
          'Autenticación requerida',
        );
        return;
      }

      if (request.method != 'GET') {
        request.response.headers.set(HttpHeaders.allowHeader, 'GET');
        await _writeError(
          request.response,
          HttpStatus.methodNotAllowed,
          'Método no permitido',
        );
        return;
      }

      final segments = request.uri.pathSegments;
      if (segments.length == 2 &&
          segments[0] == 'v1' &&
          segments[1] == 'health') {
        await _writeJson(request.response, HttpStatus.ok, {
          'data': {
            'status': 'ok',
            'port': actualPort,
            'rateLimitPerMinute': _settingsReader!
                .call()
                .localApiRateLimitPerMinute,
          },
        });
        return;
      }

      if (segments.length == 2 &&
          segments[0] == 'v1' &&
          segments[1] == 'accounts') {
        final accounts = _accountsReader!.call();
        await _writeJson(request.response, HttpStatus.ok, {
          'data': accounts.map(_accountData).toList(),
        });
        return;
      }

      if (segments.length == 2 &&
          segments[0] == 'v1' &&
          segments[1] == 'usage') {
        final accounts = _accountsReader!.call();
        await _writeJson(request.response, HttpStatus.ok, {
          'data': accounts.map(_usageData).toList(),
        });
        return;
      }

      if (segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'accounts' &&
          segments[3] == 'usage') {
        ClaudeAccount? account;
        for (final candidate in _accountsReader!.call()) {
          if (candidate.apiAccountId == segments[2]) {
            account = candidate;
            break;
          }
        }
        if (account == null) {
          await _writeError(
            request.response,
            HttpStatus.notFound,
            'Cuenta no encontrada',
          );
          return;
        }
        await _writeJson(request.response, HttpStatus.ok, {
          'data': _usageData(account),
        });
        return;
      }

      await _writeError(
        request.response,
        HttpStatus.notFound,
        'Recurso no encontrado',
      );
    } catch (_) {
      await _writeError(
        request.response,
        HttpStatus.internalServerError,
        'Error interno',
      );
    }
  }

  Map<String, dynamic> _accountData(ClaudeAccount account) => {
    'id': account.apiAccountId,
    'label': account.label,
    'provider': account.providerType.name,
    'usagePath': '/v1/accounts/${account.apiAccountId}/usage',
  };

  Map<String, dynamic> _usageData(ClaudeAccount account) {
    final usage = account.lastKnownUsage;
    return {
      'accountId': account.apiAccountId,
      'label': account.label,
      'provider': account.providerType.name,
      'status': usage == null
          ? 'pending'
          : usage.isAvailable
          ? 'available'
          : account.lastFetchSessionExpired
          ? 'session_expired'
          : 'unavailable',
      'fetchedAt': account.lastFetchedAt?.toUtc().toIso8601String(),
      'fiveHour': {
        'usedPercent': usage?.fiveHourPercent,
        'resetAt': usage?.fiveHourResetAt?.toUtc().toIso8601String(),
      },
      'weekly': {
        'usedPercent': usage?.weeklyPercent,
        'resetAt': usage?.weeklyResetAt?.toUtc().toIso8601String(),
      },
      'monthly': {
        'usedPercent': usage?.monthlyPercent,
        'resetAt': usage?.monthlyResetAt?.toUtc().toIso8601String(),
      },
      'claudeGptFiveHour': {
        'usedPercent': usage?.claudeGptFiveHourPercent,
        'resetAt': usage?.claudeGptFiveHourResetAt?.toUtc().toIso8601String(),
      },
      'claudeGptWeekly': {
        'usedPercent': usage?.claudeGptWeeklyPercent,
        'resetAt': usage?.claudeGptWeeklyResetAt?.toUtc().toIso8601String(),
      },
    };
  }

  Future<void> _writeJson(
    HttpResponse response,
    int status,
    Map<String, dynamic> payload,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.write(jsonEncode(payload));
    await response.close();
  }

  Future<void> _writeError(HttpResponse response, int status, String message) =>
      _writeJson(response, status, {
        'error': {'code': _errorCode(status), 'message': message},
      });

  String _errorCode(int status) => switch (status) {
    HttpStatus.unauthorized => 'unauthorized',
    HttpStatus.forbidden => 'forbidden',
    HttpStatus.notFound => 'not_found',
    HttpStatus.methodNotAllowed => 'method_not_allowed',
    HttpStatus.requestEntityTooLarge => 'request_too_large',
    HttpStatus.tooManyRequests => 'rate_limited',
    _ => 'internal_error',
  };
}
