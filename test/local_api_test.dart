import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claude_usage_monitor/core/models/claude_account.dart';
import 'package:claude_usage_monitor/core/local_api/local_api_service.dart';
import 'package:claude_usage_monitor/core/models/app_settings.dart';
import 'package:claude_usage_monitor/core/models/provider_type.dart';
import 'package:claude_usage_monitor/core/models/usage_snapshot.dart';

class _MemorySecretStore implements LocalApiSecretStore {
  String? value = _testSecret;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

const _testSecret = 'test-secret-012345678901234567890123456';

void main() {
  test('port candidates skip development ports and invalid values', () {
    final candidates = LocalApiService.candidatePorts(0);

    expect(candidates, isNotEmpty);
    expect(candidates.first, isNot(8080));
    expect(candidates, everyElement(isNot(5173)));
    expect(candidates, everyElement(inInclusiveRange(1024, 65535)));
  });

  test('authorization comparison is exact and timing-safe', () {
    expect(
      LocalApiService.secretsMatch('local-secret', 'local-secret'),
      isTrue,
    );
    expect(
      LocalApiService.secretsMatch('local-secret', 'local-secret-2'),
      isFalse,
    );
    expect(
      LocalApiService.secretsMatch('local-secret', 'LOCAL-SECRET'),
      isFalse,
    );
  });

  test('existing account id stays unchanged while API id is generated', () {
    final account = ClaudeAccount.fromJson({
      'id': 'webview-profile-1',
      'label': 'Existing',
    });

    expect(account.id, 'webview-profile-1');
    expect(account.apiAccountId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(account.apiAccountId, isNot(account.id));
  });

  test('local API settings clamp persisted values to safe ranges', () {
    final settings = AppSettings.fromJson({
      'localApiPort': 80,
      'localApiRateLimitPerMinute': 9999,
    });

    expect(settings.localApiPort, AppSettings.minLocalApiPort);
    expect(
      settings.localApiRateLimitPerMinute,
      AppSettings.maxLocalApiRateLimitPerMinute,
    );
  });

  test('local API authenticates and returns normalized usage only', () async {
    final secretStore = _MemorySecretStore();
    final service = LocalApiService(secretStore: secretStore);
    final account = ClaudeAccount(
      id: 'webview-profile-1',
      apiAccountId: 'api-account-1',
      label: 'Personal',
      providerType: AccountProviderType.claude,
      lastFetchedAt: DateTime.utc(2026, 8, 28, 12),
      lastKnownUsage: UsageSnapshot(
        fetchedAt: DateTime.utc(2026, 8, 28, 12),
        fiveHourPercent: 21,
        weeklyPercent: 42,
        parseError: 'must not leak',
        rawPageText: 'must not leak',
      ),
    );
    var settings = const AppSettings(
      localApiEnabled: true,
      localApiPort: 0,
      localApiRateLimitPerMinute: 10,
    );
    service.configure(accounts: () => [account], settings: () => settings);

    expect(await service.apply(), isTrue);
    addTearDown(service.stop);

    final unauthorized = await _get(service.actualPort!, null);
    expect(unauthorized.statusCode, HttpStatus.unauthorized);

    final response = await _get(service.actualPort!, _testSecret);
    expect(response.statusCode, HttpStatus.ok);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final usage = (body['data'] as List).single as Map<String, dynamic>;
    expect(usage['accountId'], 'api-account-1');
    expect(usage['fiveHour']['usedPercent'], 21);
    expect(usage.containsKey('parseError'), isFalse);
    expect(usage.containsKey('rawPageText'), isFalse);

    settings = settings.copyWith(localApiRateLimitPerMinute: 1);
    final first = await _get(service.actualPort!, _testSecret);
    final second = await _get(service.actualPort!, _testSecret);
    expect(first.statusCode, HttpStatus.tooManyRequests);
    expect(second.statusCode, HttpStatus.tooManyRequests);
  });
}

Future<({int statusCode, String body})> _get(int port, String? secret) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/v1/usage'),
    );
    if (secret != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
    }
    final response = await request.close();
    return (
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}
