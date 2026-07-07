import 'dart:convert';
import 'dart:io';

import '../models/usage_snapshot.dart';

/// Fetches usage data straight from claude.ai's own internal JSON API
/// (`/api/organizations` then `/api/organizations/<uuid>/usage`) using
/// already-authenticated session cookies, instead of scraping or driving
/// the settings UI. Found by inspecting the real app's network requests.
///
/// Unofficial/undocumented (no public API for this exists), but it's the
/// same plain read-only GET the web app itself makes, and far more
/// reliable than the DOM-scraping/simulated-click approach this app used
/// before: that fought the page's own React app and bot-resistance checks
/// for a long time with no reliable result, while this is a couple of
/// stable, structured JSON calls.
class UsageApiClient {
  const UsageApiClient();

  static const _organizationsUrl = 'https://claude.ai/api/organizations';

  Future<UsageSnapshot> fetchUsage(String cookieHeader) async {
    final client = HttpClient();
    try {
      final orgs = await _getJson(client, Uri.parse(_organizationsUrl), cookieHeader);
      if (orgs is! List || orgs.isEmpty) {
        return UsageSnapshot.unavailable('No organizations found for this account');
      }

      // An account can belong to more than one organization (e.g. a
      // personal workspace plus a team) -- claude.ai's own usage panel
      // reflects whichever workspace you're actively chatting in, but a
      // plain API call has no browsing session to infer that from.
      // Confirmed live with a real multi-org account: the *first* org in
      // this list was a personal workspace that had never been used
      // (0%/0%), while the second, a team workspace, held the account's
      // real usage (7%/41%) -- trusting list order alone silently showed
      // the wrong workspace. Checking every org and keeping the first one
      // that actually shows activity is the only reliable signal available.
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
        if (_hasActivity(usage)) return _parseUsage(usage);
      }
      if (fallback == null) {
        return UsageSnapshot.unavailable(
          'Organization UUID missing from API response',
          rawPageText: jsonEncode(orgs),
        );
      }
      return _parseUsage(fallback);
    } on _ApiHttpException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return UsageSnapshot.unavailable(
          'Session expired (${e.statusCode}) -- log in again',
          sessionExpired: true,
        );
      }
      return UsageSnapshot.unavailable('Usage API request failed: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _getJson(HttpClient client, Uri uri, String cookieHeader) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw _ApiHttpException(response.statusCode, '${response.statusCode} for $uri: $body');
    }
    return jsonDecode(body);
  }

  UsageSnapshot _parseUsage(Map<String, dynamic> json) {
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

  DateTime? _parseIso(String? raw) => raw == null ? null : DateTime.tryParse(raw)?.toLocal();

  bool _hasActivity(Map<String, dynamic> usage) {
    final fiveHour = (usage['five_hour'] as Map?)?['utilization'] as num?;
    final sevenDay = (usage['seven_day'] as Map?)?['utilization'] as num?;
    return (fiveHour != null && fiveHour > 0) || (sevenDay != null && sevenDay > 0);
  }
}

class _ApiHttpException implements Exception {
  _ApiHttpException(this.statusCode, this.message);
  final int statusCode;
  final String message;
}
