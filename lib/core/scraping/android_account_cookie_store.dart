import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android-only per-account cookie storage.
///
/// `android.webkit.CookieManager` (which flutter_inappwebview sits on top
/// of) is a single global cookie jar for the whole app -- there is no OS
/// API for a second isolated one. Confirmed by reading the plugin's own
/// Android source: its `incognito` setting doesn't isolate a WebView's
/// cookies at all, it calls `CookieManager.getInstance().removeAllCookies()`
/// -- i.e. "start clean by wiping everyone", not "give me my own jar". That
/// makes true concurrent multi-account sessions impossible through the
/// shared CookieManager the way desktop does it with a separate
/// WebKitWebContext per account.
///
/// The workaround: each account's login (see AccountLoginPage) clears the
/// shared cookie jar first so it starts from a clean slate, then captures
/// whatever cookies land there right when the user taps Done and stores
/// them here, keyed by account id. UsageScraper reads from here on Android
/// instead of the shared CookieManager. Storage is Android
/// Keystore-backed (EncryptedSharedPreferences via flutter_secure_storage)
/// -- still 100% local, never transmitted anywhere except claude.ai itself,
/// same as the cookie already living in the WebView's own store.
class AndroidAccountCookieStore {
  const AndroidAccountCookieStore();

  static const _storage = FlutterSecureStorage();

  String _keyFor(String accountId) => 'android_cookie_header_$accountId';

  Future<String?> read(String accountId) => _storage.read(key: _keyFor(accountId));

  Future<void> save(String accountId, String cookieHeader) =>
      _storage.write(key: _keyFor(accountId), value: cookieHeader);

  Future<void> delete(String accountId) => _storage.delete(key: _keyFor(accountId));
}
