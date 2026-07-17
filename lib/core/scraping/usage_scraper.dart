import 'dart:io' show Platform;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/provider_type.dart';
import '../models/usage_snapshot.dart';
import 'android_account_cookie_store.dart';
import 'android_usage_fetcher.dart';
import 'desktop_usage_fetcher.dart';
import 'usage_api_client.dart';

/// Gets usage percentages from provider internal JSON APIs (Claude, Codex, Antigravity).
class UsageScraper {
  UsageScraper({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  static const _apiClient = UsageApiClient();
  static const _androidCookies = AndroidAccountCookieStore();

  Future<UsageSnapshot> fetchUsage({
    String? profile,
    AccountProviderType providerType = AccountProviderType.claude,
  }) async {
    try {
      String cookieHeader = '';
      if (profile != null) {
        final stored = await _androidCookies.read(profile);
        if (stored != null && stored.isNotEmpty) {
          cookieHeader = stored;
        }
      }

      if (cookieHeader.trim().isEmpty && providerType != AccountProviderType.antigravity) {
        cookieHeader = Platform.isAndroid
            ? await _cookieHeaderAndroid(profile, providerType: providerType)
            : await fetchCookieHeaderDesktop(
                timeout: timeout,
                profile: profile,
                providerType: providerType,
              );
      }

      if (cookieHeader.trim().isEmpty && providerType != AccountProviderType.antigravity) {
        return UsageSnapshot.unavailable('No session cookies found -- log in first');
      }
      return await _apiClient.fetchUsage(cookieHeader, providerType: providerType);
    } catch (e) {
      print('[UsageScraper] scrape failed: $e');
      return UsageSnapshot.unavailable('Unexpected scrape error: $e');
    }
  }

  Future<String> _cookieHeaderAndroid(
    String? accountId, {
    required AccountProviderType providerType,
  }) async {
    if (accountId != null) {
      final stored = await _androidCookies.read(accountId);
      if (stored != null && stored.isNotEmpty) {
        final refreshed = await refreshAndroidCookieHeader(
          accountId,
          _androidCookies,
          providerType: providerType,
        );
        return refreshed.isNotEmpty ? refreshed : stored;
      }
    }
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(providerType.cookieDomainUrl),
    );
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }
}
