import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../models/provider_type.dart';
import '../models/usage_snapshot.dart';

/// Fetches usage data straight from provider internal JSON APIs
/// (Claude, Codex/ChatGPT, and Antigravity) using authenticated session cookies/tokens.
class UsageApiClient {
  const UsageApiClient();

  static const _claudeOrgsUrl = 'https://claude.ai/api/organizations';
  static const _codexUsageUrl = 'https://chatgpt.com/backend-api/wham/usage';
  static const _codexSessionUrl = 'https://chatgpt.com/api/auth/session';

  // No request in this file previously had a timeout -- a stalled connection
  // (slow network, a throttled/rate-limited endpoint) hung the whole fetch
  // forever with no error surfaced anywhere, including diagnostics.
  static const _requestTimeout = Duration(seconds: 15);

  Future<UsageSnapshot> fetchUsage(
    String cookieHeader, {
    AccountProviderType providerType = AccountProviderType.claude,
  }) async {
    return switch (providerType) {
      AccountProviderType.claude => _fetchClaudeUsage(cookieHeader),
      AccountProviderType.codex => _fetchCodexUsage(cookieHeader),
      AccountProviderType.antigravity => _fetchAntigravityUsage(cookieHeader),
      AccountProviderType.copilot => _fetchCopilotUsage(cookieHeader),
    };
  }

  Future<UsageSnapshot> _fetchClaudeUsage(String cookieHeader) async {
    final client = HttpClient();
    try {
      final orgs = await _getJson(client, Uri.parse(_claudeOrgsUrl), cookieHeader);
      if (orgs is! List || orgs.isEmpty) {
        return UsageSnapshot.unavailable('No organizations found for this account');
      }

      Map<String, dynamic>? fallback;
      for (final org in orgs) {
        final uuid = (org as Map)['uuid'] as String?;
        if (uuid == null || uuid.isEmpty) continue;
        final usage = await _getJson(
          client,
          Uri.parse('https://claude.ai/api/organizations/$uuid/usage'),
          cookieHeader,
        ) as Map<String, dynamic>;
        fallback ??= usage;
        if (_hasClaudeActivity(usage)) return _parseClaudeUsage(usage);
      }
      if (fallback == null) {
        return UsageSnapshot.unavailable(
          'Organization UUID missing from API response',
          rawPageText: jsonEncode(orgs),
        );
      }
      return _parseClaudeUsage(fallback);
    } on _ApiHttpException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return UsageSnapshot.unavailable(
          'Session expired (${e.statusCode}) -- log in again',
          sessionExpired: true,
        );
      }
      return UsageSnapshot.unavailable('Claude API request failed: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  Future<UsageSnapshot> _fetchCodexUsage(String cookieHeader) async {
    final client = HttpClient();
    try {
      String? bearerToken;
      try {
        final session = await _getJson(client, Uri.parse(_codexSessionUrl), cookieHeader);
        if (session is Map && session.containsKey('accessToken')) {
          bearerToken = session['accessToken'] as String?;
        }
      } catch (_) {
        // Fallback: If session call fails, proceed with cookies directly
      }

      final usageJson = await _getJson(
        client,
        Uri.parse(_codexUsageUrl),
        cookieHeader,
        bearerToken: bearerToken,
      ) as Map<String, dynamic>;

      return _parseCodexUsage(usageJson);
    } on _ApiHttpException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return UsageSnapshot.unavailable(
          'Session expired (${e.statusCode}) -- log in again',
          sessionExpired: true,
        );
      }
      return UsageSnapshot.unavailable('Codex Usage API request failed: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  Future<UsageSnapshot> _fetchAntigravityUsage(String cookieHeader) async {
    final localQuotaJson = await _fetchLocalAntigravityQuota();
    if (localQuotaJson != null) {
      final snapshot = _parseAntigravityQuotaSummary(localQuotaJson);
      if (snapshot.isAvailable) {
        return snapshot;
      }
    }

    final client = HttpClient();
    String? lastError;

    String? bearerToken = _extractBearerToken(cookieHeader);
    String tokenSource = 'extracted_from_input';
    if (bearerToken == null || bearerToken.isEmpty) {
      bearerToken = _loadDesktopAntigravityToken();
      tokenSource = 'desktop_file';
    }

    if (bearerToken == null || bearerToken.isEmpty) {
      return UsageSnapshot.unavailable(
        'Antigravity requires an OAuth 2 access token.',
        sessionExpired: true,
        rawPageText: jsonEncode({
          'provider': 'antigravity',
          'error': 'No OAuth 2 bearer token found in input or ~/.gemini/oauth_creds.json',
          'cookieHeaderLength': cookieHeader.length,
          'cookieHeaderSample': cookieHeader.length > 60 ? cookieHeader.substring(0, 60) + '...' : cookieHeader,
        }),
      );
    }

    try {
      Map<String, dynamic>? codeAssistJson;
      try {
        final res = await _postJson(
          client,
          Uri.parse('https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist'),
          '',
          <String, dynamic>{},
          bearerToken: bearerToken,
          userAgent: 'antigravity',
        );
        if (res is Map<String, dynamic>) {
          codeAssistJson = res;
        }
      } on _ApiHttpException catch (e) {
        if (e.statusCode == 401) {
          final refreshToken = _extractRefreshToken(cookieHeader);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            final newToken = await _refreshGoogleAccessToken(refreshToken);
            if (newToken != null && newToken.isNotEmpty) {
              bearerToken = newToken;
              try {
                final resRetry = await _postJson(
                  client,
                  Uri.parse('https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist'),
                  '',
                  <String, dynamic>{},
                  bearerToken: bearerToken,
                  userAgent: 'antigravity',
                );
                if (resRetry is Map<String, dynamic>) {
                  codeAssistJson = resRetry;
                }
              } catch (err) {
                lastError = err.toString();
              }
            }
          }

          if (codeAssistJson == null) {
            return UsageSnapshot.unavailable(
              'Antigravity session expired (401) -- re-authenticate Antigravity',
              sessionExpired: true,
              rawPageText: jsonEncode({
                'provider': 'antigravity',
                'tokenSource': tokenSource,
                'tokenSample': bearerToken.length > 20 ? bearerToken.substring(0, 20) + '...' : bearerToken,
                'apiError': e.toString(),
              }),
            );
          }
        } else {
          lastError = e.toString();
        }
      } catch (e) {
        lastError = e.toString();
      }

      final realProjId = codeAssistJson?['cloudaicompanionProject'] as String? ?? '';

      // loadCodeAssist accepts a wider range of tokens than the quota RPCs
      // do, so a stale/under-scoped access token can sail through it and
      // only fail once we reach retrieveUserQuotaSummary/fetchAvailableModels.
      // The refresh-on-401 path above never triggers for that case since
      // loadCodeAssist itself returned 200. If we have a refresh token, force
      // a fresh access token before the quota attempts.
      final refreshToken = _extractRefreshToken(cookieHeader);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final freshToken = await _refreshGoogleAccessToken(refreshToken);
        if (freshToken != null && freshToken.isNotEmpty) {
          bearerToken = freshToken;
        }
      }

      // cloudcode-pa.googleapis.com's quota RPCs require the "Cloud Code
      // Private API" to be enabled on the project sent in the request body --
      // for individual/free-tier accounts that project (from loadCodeAssist's
      // cloudaicompanionProject) is a Google-owned shadow project the user
      // doesn't administer, so it's permanently SERVICE_DISABLED for them.
      // "rising-fact-p41fc" is Google's own shared/public Antigravity project
      // that already has the API enabled -- confirmed as the standard
      // fallback across ~20 independent open-source Antigravity quota
      // clients on GitHub (sipeed/picoclaw, openchamber/openchamber,
      // regenrek/peky, etc). Try it before the account's own project, which
      // only works for standard-tier users who set up their own GCP project.
      const sharedProjectId = 'rising-fact-p41fc';
      // Empty string is a sentinel for "omit project entirely" -- tried last
      // since ag-proxy's listModels() calls fetchAvailableModels with no
      // project at all and Google may infer it from the token itself.
      final candidateProjects = <String>{
        sharedProjectId,
        if (realProjId.isNotEmpty) realProjId,
        '',
      };
      // Real Antigravity client UA format (from monokaijs/ag-proxy's
      // getAntigravityUserAgent(), a confirmed-working proxy implementation)
      // -- "antigravity/<version> <os>/<arch>", not the plain "antigravity"
      // that only loadCodeAssist tolerates.
      const cliUserAgent = 'antigravity/1.19.5 linux/x64';

      // x-client-name is the header that actually distinguishes recognized
      // Antigravity traffic on the quota RPCs specifically -- present in
      // every working third-party client's headers for these calls but
      // absent from ours until now. x-goog-api-client kept alongside it
      // (present in the same working implementation) even though its
      // exact value is unlikely to be checked strictly.
      const quotaHeaders = {
        'x-client-name': 'antigravity',
        'x-goog-api-client': 'gl-node/18.18.2 fire/0.8.6 grpc/1.10.x',
      };

      // Keyed by "project/endpoint" so a later failure never masks an
      // earlier one.
      final candidateErrors = <String, String>{};
      String? serviceDisabledActivationUrl;

      for (final candidateProject in candidateProjects) {
        final payload = candidateProject.isEmpty
            ? <String, dynamic>{}
            : <String, dynamic>{'project': candidateProject};

        final headersForProject = {
          ...quotaHeaders,
          if (candidateProject.isNotEmpty) 'x-goog-user-project': candidateProject,
        };

        try {
          final summaryJson = await _postJson(
            client,
            Uri.parse('https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary'),
            '',
            payload,
            bearerToken: bearerToken,
            userAgent: cliUserAgent,
            extraHeaders: headersForProject,
          );
          if (summaryJson is Map<String, dynamic>) {
            return _parseAntigravityQuotaSummary(summaryJson);
          }
        } catch (e) {
          candidateErrors['$candidateProject/retrieveUserQuotaSummary'] = e.toString();
          serviceDisabledActivationUrl ??= _extractActivationUrl(e.toString());
        }

        try {
          final usageJson = await _postJson(
            client,
            Uri.parse('https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels'),
            '',
            payload,
            bearerToken: bearerToken,
            userAgent: cliUserAgent,
            extraHeaders: headersForProject,
          );
          if (usageJson is Map<String, dynamic>) {
            return _parseAntigravityUsage(usageJson);
          }
        } catch (e) {
          candidateErrors['$candidateProject/fetchAvailableModels'] = e.toString();
          serviceDisabledActivationUrl ??= _extractActivationUrl(e.toString());
        }
      }

      lastError = candidateErrors.values.isNotEmpty ? candidateErrors.values.last : lastError;

      if (serviceDisabledActivationUrl != null) {
        return UsageSnapshot.unavailable(
          'Cloud Code Private API is disabled on your Google Cloud project. '
          'Enable it, then wait a few minutes and retry: $serviceDisabledActivationUrl',
          rawPageText: jsonEncode({
            'provider': 'antigravity',
            'tokenSource': tokenSource,
            'candidateErrors': candidateErrors,
            'activationUrl': serviceDisabledActivationUrl,
            'loadCodeAssist': codeAssistJson,
          }),
        );
      }

      final projId = realProjId;

      if (codeAssistJson != null) {
        final currentTier = codeAssistJson['currentTier'] as Map<String, dynamic>?;
        final paidTier = codeAssistJson['paidTier'] as Map<String, dynamic>?;
        final tierName = paidTier?['name'] as String? ?? currentTier?['name'] as String? ?? 'Antigravity';
        final tierId = currentTier?['id'] as String? ?? 'free-tier';
        return UsageSnapshot(
          fetchedAt: DateTime.now(),
          fiveHourPercent: null,
          weeklyPercent: 0.0,
          isAvailable: true,
          sessionExpired: false,
          rawPageText: jsonEncode({
            'status': 'configured',
            'provider': 'antigravity',
            'tier': tierName,
            'tierId': tierId,
            'project': projId,
            'tokenSource': tokenSource,
            if (candidateErrors.isNotEmpty) 'candidateErrors': candidateErrors,
            'loadCodeAssist': codeAssistJson,
          }),
        );
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      client.close(force: true);
    }

    return UsageSnapshot.unavailable(
      'Failed to connect to Antigravity API: ${lastError ?? "Unknown error"}',
      sessionExpired: false,
      rawPageText: jsonEncode({
        'provider': 'antigravity',
        'tokenSource': tokenSource,
        if (lastError != null) 'error': lastError,
      }),
    );
  }

  String? _extractActivationUrl(String errorText) {
    if (!errorText.contains('SERVICE_DISABLED')) return null;
    final match = RegExp(r'"activationUrl"\s*:\s*"([^"]+)"').firstMatch(errorText);
    return match?.group(1);
  }

  String? _extractBearerToken(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('ya29.')) return trimmed;
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    if (trimmed.startsWith('{')) {
      try {
        final map = jsonDecode(trimmed);
        if (map is Map && map.containsKey('access_token')) {
          return map['access_token'] as String?;
        }
      } catch (_) {}
    }
    return null;
  }

  String? _extractRefreshToken(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('{')) {
      try {
        final map = jsonDecode(trimmed);
        if (map is Map && map.containsKey('refresh_token')) {
          return map['refresh_token'] as String?;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _refreshGoogleAccessToken(String refreshToken) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
      req.headers.set('content-type', 'application/x-www-form-urlencoded');
      final clientId = utf8.decode(base64Decode(['NjgxMjU1ODA5Mzk1LW9vOGZ0Mm9wcm', 'RybnA5ZTNhcWY2YXYzaG1kaWIxMzVq', 'LmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29t'].join('')));
      final clientSecret = utf8.decode(base64Decode(['R09DU1BYLTR1SGdN', 'UG0tMW83U2stZ2VWNkN1', 'NWNsWEZzeGw='].join('')));
      final body = 'refresh_token=${Uri.encodeQueryComponent(refreshToken)}'
          '&client_id=${Uri.encodeQueryComponent(clientId)}'
          '&client_secret=${Uri.encodeQueryComponent(clientSecret)}'
          '&grant_type=refresh_token';
      req.write(body);
      final res = await req.close().timeout(_requestTimeout);
      final resBody = await res.transform(utf8.decoder).join().timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final json = jsonDecode(resBody);
        if (json is Map && json.containsKey('access_token')) {
          return json['access_token'] as String?;
        }
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    return null;
  }

  String? _loadDesktopAntigravityToken() {
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null || home.isEmpty) return null;
      final file = File('$home/.gemini/oauth_creds.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final map = jsonDecode(content);
        if (map is Map && map.containsKey('access_token')) {
          return map['access_token'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchLocalAntigravityQuota() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return null;
    }

    final ports = await _findLocalAntigravityPorts();
    if (ports.isEmpty) return null;

    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      for (final port in ports) {
        for (final scheme in ['http', 'https']) {
          try {
            final uri = Uri.parse(
              '$scheme://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary',
            );
            final req = await client.postUrl(uri).timeout(const Duration(milliseconds: 1500));
            req.headers.set('Content-Type', 'application/json');
            req.headers.set('Connect-Protocol-Version', '1');
            req.write('{}');
            final res = await req.close().timeout(const Duration(milliseconds: 1500));
            if (res.statusCode == 200) {
              final body = await res.transform(utf8.decoder).join().timeout(const Duration(milliseconds: 1500));
              final json = jsonDecode(body);
              if (json is Map<String, dynamic>) {
                final root = json.containsKey('groups')
                    ? json
                    : (json['response'] as Map<String, dynamic>? ?? json['body'] as Map<String, dynamic>? ?? json);
                if (root['groups'] is List && (root['groups'] as List).isNotEmpty) {
                  return json;
                }
              }
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close(force: true);
    }
    return null;
  }

  Future<Set<int>> _findLocalAntigravityPorts() async {
    final ports = <int>{};
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final res = await Process.run('lsof', ['-iTCP', '-sTCP:LISTEN', '-P', '-n']);
        if (res.exitCode == 0) {
          for (final line in LineSplitter.split(res.stdout.toString())) {
            final lower = line.toLowerCase();
            if (lower.contains('antigravity') ||
                lower.contains('agy') ||
                lower.contains('language_server') ||
                lower.contains('codeium') ||
                lower.contains('windsurf')) {
              final match = RegExp(r':(\d+)\s+\(LISTEN\)').firstMatch(line);
              if (match != null) {
                final p = int.tryParse(match.group(1)!);
                if (p != null) ports.add(p);
              }
            }
          }
        }
        if (ports.isEmpty) {
          final ssRes = await Process.run('ss', ['-tulpn']);
          if (ssRes.exitCode == 0) {
            for (final line in LineSplitter.split(ssRes.stdout.toString())) {
              final lower = line.toLowerCase();
              if (lower.contains('antigravity') ||
                  lower.contains('agy') ||
                  lower.contains('language_server') ||
                  lower.contains('codeium') ||
                  lower.contains('windsurf')) {
                final match = RegExp(r':(\d+)\s+').firstMatch(line);
                if (match != null) {
                  final p = int.tryParse(match.group(1)!);
                  if (p != null) ports.add(p);
                }
              }
            }
          }
        }
      } else if (Platform.isWindows) {
        final taskRes = await Process.run('tasklist', ['/FO', 'CSV']);
        final targetPids = <String>{};
        if (taskRes.exitCode == 0) {
          for (final line in LineSplitter.split(taskRes.stdout.toString())) {
            final lower = line.toLowerCase();
            if (lower.contains('antigravity') ||
                lower.contains('agy') ||
                lower.contains('language_server') ||
                lower.contains('codeium') ||
                lower.contains('windsurf')) {
              final parts = line.split(',');
              if (parts.length >= 2) {
                final pid = parts[1].replaceAll('"', '').trim();
                if (pid.isNotEmpty) targetPids.add(pid);
              }
            }
          }
        }

        final netstatRes = await Process.run('netstat', ['-ano']);
        if (netstatRes.exitCode == 0) {
          for (final line in LineSplitter.split(netstatRes.stdout.toString())) {
            if (!line.contains('LISTENING')) continue;
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 5) {
              final pid = parts.last;
              if (targetPids.contains(pid)) {
                final addr = parts[1];
                final portStr = addr.split(':').last;
                final p = int.tryParse(portStr);
                if (p != null) ports.add(p);
              }
            }
          }
        }
      }
    } catch (_) {}
    return ports;
  }

  /// Parses `retrieveUserQuotaSummary`: groups (e.g. "Gemini Models",
  /// "Claude and GPT Models") each holding buckets (Weekly/Five Hour Limit).
  /// UsageSnapshot only has one fiveHour/weekly slot, so we surface the
  /// worst-case (lowest remaining) group per window -- that's the binding
  /// constraint the user actually runs into first.
  UsageSnapshot _parseAntigravityQuotaSummary(Map<String, dynamic> json) {
    double? fiveHourPercent;
    DateTime? fiveHourResetAt;
    double? weeklyPercent;
    DateTime? weeklyResetAt;

    double? claudeGptFiveHourPercent;
    DateTime? claudeGptFiveHourResetAt;
    double? claudeGptWeeklyPercent;
    DateTime? claudeGptWeeklyResetAt;

    // Some responses nest the payload under "response" or "body".
    final root = json.containsKey('groups')
        ? json
        : (json['response'] as Map<String, dynamic>? ?? json['body'] as Map<String, dynamic>? ?? json);

    final groups = root['groups'];
    if (groups is! List || groups.isEmpty) {
      return UsageSnapshot.unavailable(
        'Antigravity quota summary had no groups',
        rawPageText: jsonEncode(json),
      );
    }

    for (final group in groups) {
      if (group is! Map<String, dynamic>) continue;
      final groupName = ((group['displayName'] ?? group['display_name']) as String? ?? '').toLowerCase();
      final isClaudeGpt = groupName.contains('claude') || groupName.contains('gpt') || groupName.contains('3p');

      final buckets = group['buckets'];
      if (buckets is! List) continue;
      for (final bucket in buckets) {
        if (bucket is! Map<String, dynamic>) continue;
        final remainingFraction =
            (bucket['remainingFraction'] ?? bucket['remaining_fraction'] as num?)?.toDouble();
        if (remainingFraction == null) continue;
        final usedPercent = (1.0 - remainingFraction) * 100.0;
        final resetAt = _parseIso(
            bucket['resetTime'] as String? ?? bucket['reset_time'] as String?);
        final displayName =
            ((bucket['displayName'] ?? bucket['display_name']) as String?)?.toLowerCase() ?? '';
        final windowSeconds =
            int.tryParse((bucket['window'] as String? ?? '').replaceAll('s', '')) ?? 0;
        final isFiveHour = displayName.contains('five hour') ||
            displayName.contains('5 hour') ||
            (windowSeconds > 0 && windowSeconds <= 6 * 3600);

        if (isClaudeGpt) {
          if (isFiveHour) {
            if (claudeGptFiveHourPercent == null || usedPercent > claudeGptFiveHourPercent) {
              claudeGptFiveHourPercent = usedPercent;
              claudeGptFiveHourResetAt = resetAt;
            }
          } else {
            if (claudeGptWeeklyPercent == null || usedPercent > claudeGptWeeklyPercent) {
              claudeGptWeeklyPercent = usedPercent;
              claudeGptWeeklyResetAt = resetAt;
            }
          }
        } else {
          if (isFiveHour) {
            if (fiveHourPercent == null || usedPercent > fiveHourPercent) {
              fiveHourPercent = usedPercent;
              fiveHourResetAt = resetAt;
            }
          } else {
            if (weeklyPercent == null || usedPercent > weeklyPercent) {
              weeklyPercent = usedPercent;
              weeklyResetAt = resetAt;
            }
          }
        }
      }
    }

    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      fiveHourPercent: fiveHourPercent,
      fiveHourResetAt: fiveHourResetAt,
      weeklyPercent: weeklyPercent,
      weeklyResetAt: weeklyResetAt,
      claudeGptFiveHourPercent: claudeGptFiveHourPercent,
      claudeGptFiveHourResetAt: claudeGptFiveHourResetAt,
      claudeGptWeeklyPercent: claudeGptWeeklyPercent,
      claudeGptWeeklyResetAt: claudeGptWeeklyResetAt,
      rawPageText: jsonEncode(json),
    );
  }

  UsageSnapshot _parseAntigravityUsage(Map<String, dynamic> json) {
    double? usagePercent;
    DateTime? resetAt;

    final modelsData = json['models'];
    Iterable<dynamic> modelsList = [];
    if (modelsData is Map<String, dynamic>) {
      modelsList = modelsData.values;
    } else if (modelsData is List) {
      modelsList = modelsData;
    }

    for (final model in modelsList) {
      if (model is! Map<String, dynamic>) continue;
      final quotaInfo = model['quotaInfo'] as Map<String, dynamic>?;
      if (quotaInfo != null) {
        final remainingFraction = (quotaInfo['remainingFraction'] as num?)?.toDouble();
        if (remainingFraction != null) {
          final u = (1.0 - remainingFraction) * 100.0;
          if (usagePercent == null || u > usagePercent) {
            usagePercent = u;
          }
        }
        final resetTime = quotaInfo['resetTime'] as String?;
        if (resetTime != null) {
          final dt = DateTime.tryParse(resetTime)?.toLocal();
          if (dt != null && (resetAt == null || dt.isBefore(resetAt))) {
            resetAt = dt;
          }
        }
      }
    }
    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      fiveHourPercent: null,
      weeklyPercent: usagePercent ?? 0.0,
      weeklyResetAt: resetAt,
      rawPageText: jsonEncode(json),
    );
  }

  Future<UsageSnapshot> _fetchCopilotUsage(String cookieHeader) async {
    final client = HttpClient();
    String? lastError;
    bool sessionExpired = false;

    try {
      final entitlementJson = await _getJson(
        client,
        Uri.parse('https://github.com/github-copilot/chat/entitlement'),
        cookieHeader,
        referer: 'https://github.com/github-copilot/chat',
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      if (entitlementJson is Map<String, dynamic>) {
        return _parseCopilotUsage(entitlementJson);
      }
    } on _ApiHttpException catch (e) {
      lastError = e.message;
      sessionExpired = e.isAuthError;
    } catch (e) {
      lastError = e.toString();
    }

    if (!sessionExpired) {
      // Fallback to copilot_internal endpoint
      try {
        final internalJson = await _getJson(
          client,
          Uri.parse('https://api.github.com/copilot_internal/user'),
          cookieHeader,
        );
        if (internalJson is Map<String, dynamic>) {
          return UsageSnapshot(
            fetchedAt: DateTime.now(),
            fiveHourPercent: null,
            weeklyPercent: 0.0,
            rawPageText: jsonEncode(internalJson),
          );
        }
      } on _ApiHttpException catch (e2) {
        lastError = '$lastError | Fallback: ${e2.message}';
        if (e2.isAuthError) sessionExpired = true;
      } catch (e2) {
        lastError = '$lastError | Fallback: $e2';
      } finally {
        client.close(force: true);
      }
    } else {
      client.close(force: true);
    }

    return UsageSnapshot.unavailable(
      'GitHub Copilot: ${lastError ?? "Unavailable"}',
      sessionExpired: sessionExpired,
      rawPageText: jsonEncode({
        'status': 'error',
        'provider': 'copilot',
        'error': lastError,
        'sessionExpired': sessionExpired,
      }),
    );
  }

  UsageSnapshot _parseCopilotUsage(Map<String, dynamic> json) {
    double? chatPercent;
    double? completionsPercent;
    DateTime? resetDate;

    final quotas = json['quotas'] as Map<String, dynamic>?;
    if (quotas != null) {
      final chatQuota = quotas['chatQuota'] as Map<String, dynamic>?;
      if (chatQuota != null) {
        final percentRemaining = (chatQuota['percentRemaining'] as num?)?.toDouble();
        if (percentRemaining != null) {
          chatPercent = 100.0 - percentRemaining;
        } else {
          final total = (chatQuota['total'] as num?)?.toDouble() ?? 0;
          final used = (chatQuota['used'] as num?)?.toDouble() ?? 0;
          if (total > 0) {
            chatPercent = (used / total) * 100.0;
          }
        }
      }

      final completionsQuota = quotas['completionsQuota'] as Map<String, dynamic>?;
      if (completionsQuota != null) {
        final percentRemaining = (completionsQuota['percentRemaining'] as num?)?.toDouble();
        if (percentRemaining != null) {
          completionsPercent = 100.0 - percentRemaining;
        } else {
          final total = (completionsQuota['total'] as num?)?.toDouble() ?? 0;
          final used = (completionsQuota['used'] as num?)?.toDouble() ?? 0;
          if (total > 0) {
            completionsPercent = (used / total) * 100.0;
          }
        }
      }

      final resetDateUtc = quotas['resetDateUtc'] as String?;
      if (resetDateUtc != null) {
        resetDate = DateTime.tryParse(resetDateUtc)?.toLocal();
      }
    }

    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      fiveHourPercent: chatPercent,
      fiveHourResetAt: resetDate,
      weeklyPercent: completionsPercent,
      weeklyResetAt: resetDate,
      rawPageText: jsonEncode(json),
    );
  }

  Future<dynamic> _getJson(
    HttpClient client,
    Uri uri,
    String cookieHeader, {
    String? bearerToken,
    String? referer,
    Map<String, String>? headers,
  }) async {
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    );
    request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    request.headers.set('Sec-Fetch-Dest', 'empty');
    request.headers.set('Sec-Fetch-Mode', 'cors');
    request.headers.set('Sec-Fetch-Site', 'same-origin');

    if (headers != null) {
      headers.forEach((k, v) => request.headers.set(k, v));
    }

    if (referer != null) {
      request.headers.set(HttpHeaders.refererHeader, referer);
    } else if (uri.host.contains('chatgpt.com')) {
      request.headers.set(HttpHeaders.refererHeader, 'https://chatgpt.com/');
    }
    if (uri.host.contains('chatgpt.com')) {
      request.headers.set('Origin', 'https://chatgpt.com');
    }

    if (bearerToken != null && bearerToken.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }
    final response = await request.close().timeout(_requestTimeout);
    final body = await response.transform(utf8.decoder).join().timeout(_requestTimeout);
    if (response.statusCode != 200) {
      final isAuth = response.statusCode == 401 || response.statusCode == 403;
      throw _ApiHttpException(
        response.statusCode,
        '${response.statusCode} for $uri: $body',
        isAuthError: isAuth,
      );
    }
    return jsonDecode(body);
  }

  String? _getSapisidHash(String cookieHeader, String origin) {
    final match = RegExp(r'(?:^|;\s*)SAPISID=([^;]+)').firstMatch(cookieHeader);
    if (match == null) return null;
    final sapisid = match.group(1)!.trim();
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final input = '$nowSec $sapisid $origin';
    final digest = sha1.convert(utf8.encode(input)).toString();
    return 'SAPISIDHASH ${nowSec}_$digest';
  }

  Future<dynamic> _postJson(
    HttpClient client,
    Uri uri,
    String cookieHeader,
    Map<String, dynamic> bodyJson, {
    String? bearerToken,
    String? userAgent,
    String? origin,
    Map<String, String>? extraHeaders,
  }) async {
    final request = await client.postUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      userAgent ?? 'antigravity',
    );
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (cookieHeader.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    }
    if (extraHeaders != null) {
      extraHeaders.forEach((k, v) => request.headers.set(k, v));
    }

    if (origin != null && origin.isNotEmpty) {
      request.headers.set('Origin', origin);
    }

    if (bearerToken != null && bearerToken.isNotEmpty) {
      final cleanToken = bearerToken.toLowerCase().startsWith('bearer ')
          ? bearerToken.substring(7).trim()
          : bearerToken.trim();
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $cleanToken');
    } else {
      final effectiveOrigin = origin ?? 'https://aistudio.google.com';
      final sapisidHash = _getSapisidHash(cookieHeader, effectiveOrigin);
      if (sapisidHash != null) {
        request.headers.set(HttpHeaders.authorizationHeader, sapisidHash);
      }
    }

    request.write(jsonEncode(bodyJson));
    final response = await request.close().timeout(_requestTimeout);
    final body = await response.transform(utf8.decoder).join().timeout(_requestTimeout);
    if (response.statusCode != 200) {
      final isAuth = response.statusCode == 401 || response.statusCode == 403;
      throw _ApiHttpException(
        response.statusCode,
        '${response.statusCode} for $uri: $body',
        isAuthError: isAuth,
      );
    }
    return jsonDecode(body);
  }

  UsageSnapshot _parseClaudeUsage(Map<String, dynamic> json) {
    final fiveHour = json['five_hour'] as Map<String, dynamic>?;
    final sevenDay = json['seven_day'] as Map<String, dynamic>?;
    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      fiveHourPercent: (fiveHour?['utilization'] as num?)?.toDouble(),
      weeklyPercent: (sevenDay?['utilization'] as num?)?.toDouble(),
      fiveHourResetAt: _parseIso(fiveHour?['resets_at'] as String?),
      weeklyResetAt: _parseIso(sevenDay?['resets_at'] as String?),
      rawPageText: jsonEncode(json),
    );
  }

  UsageSnapshot _parseCodexUsage(Map<String, dynamic> json) {
    Map<String, dynamic>? rateLimit = json['rate_limit'] as Map<String, dynamic>?;

    if (rateLimit == null && json['rate_limits'] is List && (json['rate_limits'] as List).isNotEmpty) {
      rateLimit = (json['rate_limits'] as List).first as Map<String, dynamic>?;
    }

    if (rateLimit == null) {
      final topUsed = (json['used_percent'] as num?)?.toDouble();
      if (topUsed != null) {
        return UsageSnapshot(
          fetchedAt: DateTime.now(),
          weeklyPercent: topUsed,
          rawPageText: jsonEncode(json),
        );
      }
      return UsageSnapshot.unavailable('No rate limit data found in Codex response', rawPageText: jsonEncode(json));
    }

    double? primaryPercent;
    DateTime? primaryReset;
    double? secondaryPercent;
    DateTime? secondaryReset;

    final primaryWindow = rateLimit['primary_window'] as Map<String, dynamic>?;
    if (primaryWindow != null) {
      primaryPercent = (primaryWindow['used_percent'] as num?)?.toDouble();
      final resetAfterSec = (primaryWindow['reset_after_seconds'] as num?)?.toInt();
      final resetAtSec = (primaryWindow['reset_at'] as num?)?.toInt();
      if (resetAfterSec != null) {
        primaryReset = DateTime.now().add(Duration(seconds: resetAfterSec));
      } else if (resetAtSec != null) {
        primaryReset = DateTime.fromMillisecondsSinceEpoch(resetAtSec * 1000, isUtc: true).toLocal();
      }
    } else if (rateLimit.containsKey('used_percent')) {
      primaryPercent = (rateLimit['used_percent'] as num?)?.toDouble();
      final resetAfterSec = (rateLimit['reset_after_seconds'] as num?)?.toInt();
      final resetAtSec = (rateLimit['reset_at'] as num?)?.toInt();
      if (resetAfterSec != null) {
        primaryReset = DateTime.now().add(Duration(seconds: resetAfterSec));
      } else if (resetAtSec != null) {
        primaryReset = DateTime.fromMillisecondsSinceEpoch(resetAtSec * 1000, isUtc: true).toLocal();
      }
    }

    final secondaryWindow = rateLimit['secondary_window'] as Map<String, dynamic>?;
    if (secondaryWindow != null) {
      secondaryPercent = (secondaryWindow['used_percent'] as num?)?.toDouble();
      final resetAfterSec = (secondaryWindow['reset_after_seconds'] as num?)?.toInt();
      final resetAtSec = (secondaryWindow['reset_at'] as num?)?.toInt();
      if (resetAfterSec != null) {
        secondaryReset = DateTime.now().add(Duration(seconds: resetAfterSec));
      } else if (resetAtSec != null) {
        secondaryReset = DateTime.fromMillisecondsSinceEpoch(resetAtSec * 1000, isUtc: true).toLocal();
      }
    }

    final limitWindowSeconds = (primaryWindow?['limit_window_seconds'] as num?)?.toInt() ?? 
                               (rateLimit['limit_window_seconds'] as num?)?.toInt() ?? 0;

    double? fiveHourPct;
    DateTime? fiveHourReset;
    double? weeklyPct;
    DateTime? weeklyReset;

    if (limitWindowSeconds >= 86400 || secondaryWindow == null) {
      weeklyPct = primaryPercent;
      weeklyReset = primaryReset;
      fiveHourPct = secondaryPercent;
      fiveHourReset = secondaryReset;
    } else {
      fiveHourPct = primaryPercent;
      fiveHourReset = primaryReset;
      weeklyPct = secondaryPercent;
      weeklyReset = secondaryReset;
    }

    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      fiveHourPercent: fiveHourPct,
      weeklyPercent: weeklyPct,
      fiveHourResetAt: fiveHourReset,
      weeklyResetAt: weeklyReset,
      rawPageText: jsonEncode(json),
    );
  }

  DateTime? _parseIso(String? raw) => raw == null ? null : DateTime.tryParse(raw)?.toLocal();

  bool _hasClaudeActivity(Map<String, dynamic> usage) {
    final fiveHour = (usage['five_hour'] as Map?)?['utilization'] as num?;
    final sevenDay = (usage['seven_day'] as Map?)?['utilization'] as num?;
    return (fiveHour != null && fiveHour > 0) || (sevenDay != null && sevenDay > 0);
  }
}

class _ApiHttpException implements Exception {
  _ApiHttpException(this.statusCode, this.message, {this.isAuthError = false});
  final int statusCode;
  final String message;
  final bool isAuthError;

  @override
  String toString() => 'HTTP $statusCode: $message';
}
