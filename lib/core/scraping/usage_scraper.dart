import 'dart:io' show Platform;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/usage_snapshot.dart';
import 'desktop_usage_fetcher.dart';
import 'usage_api_client.dart';

/// Gets Claude's 5-hour/weekly usage percentages from claude.ai's own
/// internal JSON API (`/api/organizations` + `.../usage`), reusing whatever
/// session cookies already exist for claude.ai (set up once via the visible
/// login flow in the accounts feature).
///
/// Read-only: never calls /v1/messages or any inference endpoint, never
/// sends cookies or usage data anywhere off-device.
///
/// Android reads cookies via flutter_inappwebview's CookieManager (backed by
/// Android's persistent, app-wide cookie store -- no webview navigation
/// needed). Linux/Windows use desktop_webview_window's getAllCookies, which
/// needs a webview to have (at least started) loading a claude.ai page
/// first -- see desktop_usage_fetcher.dart.
///
/// Multi-account cookie isolation (each account keeping its own claude.ai
/// login) only exists on Linux/Windows (a per-account WebKitWebContext, see
/// [fetchUsage]'s `profile` param). Android's native CookieManager is a
/// single app-wide singleton with no per-WebView partitioning, so on Android
/// today, adding a second account with a *different* claude.ai login would
/// still overwrite the first one's session.
class UsageScraper {
  UsageScraper({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  static const _apiClient = UsageApiClient();

  /// [profile] should be the account's own id on desktop, so cookies come
  /// from that account's isolated WebKitWebContext rather than the shared
  /// default one (see AccountLoginPage/desktop_usage_fetcher.dart). Ignored
  /// on Android, which has no equivalent per-account cookie isolation --
  /// see the note in usage_scraper's class doc.
  Future<UsageSnapshot> fetchUsage({String? profile}) async {
    try {
      final cookieHeader = Platform.isAndroid
          ? await _cookieHeaderAndroid()
          : await fetchCookieHeaderDesktop(timeout: timeout, profile: profile);
      if (cookieHeader.trim().isEmpty) {
        return UsageSnapshot.unavailable('No session cookies found -- log in first');
      }
      return await _apiClient.fetchUsage(cookieHeader);
    } catch (e) {
      print('[UsageScraper] scrape failed: $e');
      return UsageSnapshot.unavailable('Unexpected scrape error: $e');
    }
  }

  Future<String> _cookieHeaderAndroid() async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri('https://claude.ai'),
    );
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }
}
