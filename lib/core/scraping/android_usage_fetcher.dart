import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/provider_type.dart';
import 'android_account_cookie_store.dart';
import 'android_cookie_jar_lock.dart';

/// Refreshes an Android account's stored cookie snapshot via a real, live
/// page load before every usage fetch for the specified provider.
Future<String> refreshAndroidCookieHeader(
  String accountId,
  AndroidAccountCookieStore store, {
  AccountProviderType providerType = AccountProviderType.claude,
}) {
  return AndroidCookieJarLock.run(() => _refresh(accountId, store, providerType));
}

Future<String> _refresh(
  String accountId,
  AndroidAccountCookieStore store,
  AccountProviderType providerType,
) async {
  final stored = await store.read(accountId);
  if (stored == null || stored.isEmpty) return '';

  final domainUrl = providerType.cookieDomainUrl;
  final pingUrl = providerType.pingUrl;

  await CookieManager.instance().deleteAllCookies();
  for (final pair in stored.split('; ')) {
    final i = pair.indexOf('=');
    if (i <= 0) continue;
    await CookieManager.instance().setCookie(
      url: WebUri(domainUrl),
      name: pair.substring(0, i),
      value: pair.substring(i + 1),
    );
  }

  HeadlessInAppWebView? headless;
  try {
    final loaded = Completer<void>();
    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(pingUrl)),
      onLoadStop: (controller, url) {
        if (!loaded.isCompleted) loaded.complete();
      },
    );
    await headless.run();
    await loaded.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  } finally {
    await headless?.dispose();
  }

  final cookies = await CookieManager.instance().getCookies(url: WebUri(domainUrl));
  final refreshed = cookies.map((c) => '${c.name}=${c.value}').join('; ');
  if (refreshed.isEmpty) return stored;
  await store.save(accountId, refreshed);
  return refreshed;
}
