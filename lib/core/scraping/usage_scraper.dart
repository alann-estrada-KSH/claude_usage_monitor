import 'dart:io' show Platform;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/usage_snapshot.dart';
import 'android_account_cookie_store.dart';
import 'android_usage_fetcher.dart';
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
/// Android reads the per-account snapshot AccountLoginPage captured at login
/// time (see AndroidAccountCookieStore), falling back to
/// flutter_inappwebview's shared CookieManager only if nothing was captured
/// yet (e.g. an account created before this existed). Linux/Windows use
/// desktop_webview_window's getAllCookies against that account's own
/// isolated WebKitWebContext instead -- see desktop_usage_fetcher.dart.
class UsageScraper {
  UsageScraper({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  static const _apiClient = UsageApiClient();
  static const _androidCookies = AndroidAccountCookieStore();

  /// [profile] should be the account's own id -- on desktop it picks that
  /// account's isolated WebKitWebContext (see
  /// AccountLoginPage/desktop_usage_fetcher.dart); on Android it looks up
  /// that account's captured cookie snapshot (see
  /// AndroidAccountCookieStore).
  Future<UsageSnapshot> fetchUsage({String? profile}) async {
    try {
      final cookieHeader = Platform.isAndroid
          ? await _cookieHeaderAndroid(profile)
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

  Future<String> _cookieHeaderAndroid(String? accountId) async {
    if (accountId != null) {
      final stored = await _androidCookies.read(accountId);
      if (stored != null && stored.isNotEmpty) {
        // Refreshes the stored snapshot via a live page load first (see
        // android_usage_fetcher.dart) -- a static snapshot captured once at
        // login goes stale if claude.ai rotates its session cookie over
        // time, which a plain read here can't detect or recover from.
        final refreshed = await refreshAndroidCookieHeader(accountId, _androidCookies);
        return refreshed.isNotEmpty ? refreshed : stored;
      }
    }
    // Fallback for an account created before per-account capture existed,
    // or if nothing was ever captured -- reads whatever is currently in the
    // shared jar, same as the old single-account-only behavior.
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri('https://claude.ai'),
    );
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }
}
