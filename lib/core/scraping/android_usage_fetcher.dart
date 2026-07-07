import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_account_cookie_store.dart';
import 'android_cookie_jar_lock.dart';

const _claudeUrl = 'https://claude.ai';

/// Refreshes an Android account's stored cookie snapshot via a real, live
/// page load before every usage fetch -- mirroring what
/// desktop_usage_fetcher.dart already does on Linux/Windows (open a hidden
/// webview, load a live page, read back whatever cookies come out of it).
///
/// AndroidAccountCookieStore's snapshot is captured exactly once, at login
/// time. If claude.ai rotates or extends its session cookie on ordinary
/// requests (a common sliding-expiration pattern), that static snapshot
/// slowly goes stale even though the account is still genuinely logged in
/// -- confirmed live: usage read correctly right after login, then
/// degraded to 0%/0% over time on Android while the same claude.ai account
/// kept working fine on Linux, which never reuses a stale cookie in the
/// first place. Loading a live page through the shared CookieManager jar
/// and writing back whatever comes out keeps Android's snapshot as fresh
/// as desktop's is by construction, instead of trying to predict which
/// cookie rotates or when.
Future<String> refreshAndroidCookieHeader(String accountId, AndroidAccountCookieStore store) {
  return AndroidCookieJarLock.run(() => _refresh(accountId, store));
}

Future<String> _refresh(String accountId, AndroidAccountCookieStore store) async {
  final stored = await store.read(accountId);
  if (stored == null || stored.isEmpty) return '';

  // The shared jar may still hold a different account's cookies from
  // whatever ran before this under the lock -- start clean so only this
  // account's session drives the page load.
  await CookieManager.instance().deleteAllCookies();
  for (final pair in stored.split('; ')) {
    final i = pair.indexOf('=');
    if (i <= 0) continue;
    await CookieManager.instance().setCookie(
      url: WebUri(_claudeUrl),
      name: pair.substring(0, i),
      value: pair.substring(i + 1),
    );
  }

  HeadlessInAppWebView? headless;
  try {
    final loaded = Completer<void>();
    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('$_claudeUrl/new')),
      onLoadStop: (controller, url) {
        if (!loaded.isCompleted) loaded.complete();
      },
    );
    await headless.run();
    await loaded.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  } finally {
    await headless?.dispose();
  }

  final cookies = await CookieManager.instance().getCookies(url: WebUri(_claudeUrl));
  final refreshed = cookies.map((c) => '${c.name}=${c.value}').join('; ');
  if (refreshed.isEmpty) return stored;
  await store.save(accountId, refreshed);
  return refreshed;
}
