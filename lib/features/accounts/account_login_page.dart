import 'dart:async';
import 'dart:io' show Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/scraping/android_account_cookie_store.dart';
import '../../core/scraping/android_cookie_jar_lock.dart';
import '../../core/scraping/desktop_webview_lock.dart';
import '../../l10n/app_localizations.dart';

/// Chrome-for-Android UA with the "; wv)" WebView marker stripped. Google's
/// OAuth login blocks with `disallowed_useragent` the instant it sees that
/// marker (a documented anti-embedded-webview policy), regardless of
/// whether the popup opens in a new window or loads in the same view --
/// confirmed live: the same "load the popup URL in this view" approach that
/// works fine on Linux's WebKitGTK window fails on Android specifically
/// because of this UA fingerprint, not the popup handling itself. This is
/// the standard, widely-used workaround; still just a fingerprint tweak, it
/// can stop working if Google's detection changes.
const _androidLoginUserAgent =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// Shows the real claude.ai login page so the user can sign in normally.
///
/// On desktop, session cookies land in that account's own isolated
/// WebKitWebContext as a side effect -- this screen never reads or touches
/// them directly. Android has no equivalent per-WebView cookie isolation
/// (see AndroidAccountCookieStore for why), so there this screen clears the
/// shared cookie jar before login and captures+stores the result itself on
/// Done -- still 100% local, never sent anywhere but claude.ai.
///
/// Login completion is confirmed by the user tapping "Done" rather than by
/// guessing Anthropic's auth redirect URLs, which can change without notice.
class AccountLoginPage extends StatefulWidget {
  const AccountLoginPage({super.key, this.profile});

  /// The target account's id. On desktop it picks that account's isolated
  /// WebKitWebContext (see third_party/desktop_webview_window); on Android
  /// it's the key under which the captured cookies get stored (see
  /// AndroidAccountCookieStore). `null` falls back to the old
  /// shared-context/no-capture behavior (used to be the only behavior at
  /// all, before multi-account support existed).
  final String? profile;

  static const _loginUrl = 'https://claude.ai/login';

  @override
  State<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  Webview? _desktopWebview;
  static const _androidCookies = AndroidAccountCookieStore();

  // _confirmDone does real async work now (cookie capture) before popping,
  // where it used to be instant -- a quick double-tap on Done fired it
  // twice concurrently and the second Navigator.pop() landed while the
  // first was still resolving, crashing with the Navigator's own
  // '!_debugLocked' reentrancy assertion (confirmed live on-device).
  bool _confirming = false;

  // Gates mounting the InAppWebView itself. initState can't be awaited, so
  // build() used to run synchronously right after it and mount the webview
  // (with initialUrlRequest already pointed at claude.ai/login) immediately
  // -- starting navigation, and racing, the still-in-flight cookie/storage
  // clear below. Confirmed live: the old account's session routinely won
  // that race, landing straight on its chat screen before the clear ever
  // finished. Not mounting the webview at all until the clear is done
  // removes the race instead of trying to win it.
  bool _androidReadyToLoad = false;

  // Google's OAuth popup ("Sign in with Google" calls window.open()) --
  // confirmed live: the request flutter_inappwebview's onCreateWindow hands
  // over at popup-creation time is just claude.ai's own placeholder icon
  // (https://claude.ai/images/google.svg), not the OAuth URL. claude.ai
  // opens a blank/placeholder popup immediately (the standard trick to
  // dodge popup blockers) and only navigates *that popup* to the real
  // Google URL a moment later via JS. Loading the placeholder request's URL
  // into the main view (the old approach) hijacks the wrong content and
  // leaves the real OAuth navigation with nowhere to land -- exactly the
  // "just a tiny G icon, nothing else" symptom seen live. A real popup
  // WebView bound to the same windowId is what lets that later JS
  // navigation actually go somewhere.
  CreateWindowAction? _googlePopupRequest;

  // Held from the moment this screen starts clearing the shared jar until
  // it's disposed (Done, back-press, anything) -- see AndroidCookieJarLock.
  // Without this, the background usage-refresh (android_usage_fetcher.dart)
  // firing on its ~90s timer mid-login would clear/repopulate the same
  // shared jar this screen is actively using, corrupting both.
  void Function()? _releaseAndroidLock;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) {
      _openDesktopLoginWindow();
    } else {
      _prepareAndroidLogin();
    }
  }

  Future<void> _prepareAndroidLogin() async {
    _releaseAndroidLock = await AndroidCookieJarLock.acquire();
    // The shared CookieManager has no per-account isolation on Android (see
    // AndroidAccountCookieStore) -- starting a new login without clearing
    // it first would silently inherit whichever account's session happens
    // to already be sitting there and capture the WRONG account's cookies
    // on Done. Every login starts from a clean slate here.
    //
    // deleteAllCookies() (app-wide), not the URL-scoped deleteCookies(url:)
    // this used to call -- claude.ai's session cookie may be scoped to a
    // dot-domain (.claude.ai) that an exact-URL match doesn't reliably hit.
    await CookieManager.instance().deleteAllCookies();
    // claude.ai also recognizes a returning session via localStorage/
    // IndexedDB, not just the cookie -- confirmed live on-device: clearing
    // only the cookie still landed straight on the chat screen for a
    // *different* account's login attempt, skipping the login form
    // entirely. This wipes WebView-wide local storage; safe here since
    // this WebView only ever navigates to claude.ai.
    await WebStorageManager.instance().deleteAllData();
    if (mounted) setState(() => _androidReadyToLoad = true);
  }

  Future<void> _openDesktopLoginWindow() async {
    // Held for the whole login session (open -> close), not just creation:
    // the background usage-scraper also creates/destroys its own native
    // webview window on a timer, and letting that race with an open login
    // window caused a MissingPluginException and, eventually, a crash.
    await DesktopWebviewLock.run(() async {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 480,
          windowHeight: 720,
          title: 'Sign in to Claude.ai',
          titleBarHeight: 32,
          profile: widget.profile,
        ),
      );
      // Popup handling (Google's OAuth "Sign in with Google" opens one) is
      // patched at the native layer -- see third_party/desktop_webview_window.
      // titleBarHeight > 0 also gets that native window a plain "x" close
      // button (patched in the same file), since window-manager decorations
      // aren't guaranteed reachable/visible in every WM configuration.
      webview.launch(AccountLoginPage._loginUrl);
      if (mounted) setState(() => _desktopWebview = webview);

      final closed = Completer<void>();
      // Single source of truth for "the login flow is over": whether the
      // user hits the in-app "Done" button (which just requests a native
      // close below) or the popup's own x/window-manager close, this same
      // callback fires and is the only place that pops the route. Treating
      // every close as a completed login (not just the "Done" button) is
      // also simply what a user expects "closing the login window" to mean.
      webview.onClose.then((_) {
        if (mounted) Navigator.of(context).pop(true);
        if (!closed.isCompleted) closed.complete();
      });
      await closed.future;
    });
  }

  Future<void> _confirmDone() async {
    if (_confirming) return;
    _confirming = true;
    try {
      // Desktop: closing the native webview window fires onClose, which is
      // what actually pops this route (see _openDesktopLoginWindow) -- it
      // never runs on Android (initState only opens it `if
      // (!Platform.isAndroid)`), so _desktopWebview stays null there and
      // this button did nothing at all. Android's InAppWebView is just an
      // embedded widget in this same route, not a separate window --
      // popping directly is the equivalent "close" action.
      if (Platform.isAndroid) {
        final profile = widget.profile;
        if (profile != null) {
          // Capture now, while this account's session is still the only
          // thing in the shared cookie jar (see _prepareAndroidLogin) --
          // this snapshot is what UsageScraper reads from on Android from
          // here on, not the shared jar (which the next login will clear).
          final cookies = await CookieManager.instance().getCookies(url: WebUri('https://claude.ai'));
          final header = cookies.map((c) => '${c.name}=${c.value}').join('; ');
          if (header.isNotEmpty) await _androidCookies.save(profile, header);
        }
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _desktopWebview?.close();
      }
    } finally {
      _confirming = false;
    }
  }

  @override
  void dispose() {
    _desktopWebview?.close();
    _releaseAndroidLock?.call();
    _releaseAndroidLock = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginPageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _confirmDone,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.loginDone),
            ),
          ),
        ],
      ),
      body: Platform.isAndroid ? _buildAndroidWebView(l10n) : _buildDesktopHint(l10n),
    );
  }

  Widget _buildAndroidWebView(AppLocalizations l10n) {
    if (!_androidReadyToLoad) {
      // Cookie/storage clear (see _prepareAndroidLogin) still in flight --
      // must not mount InAppWebView yet, since its initialUrlRequest starts
      // loading claude.ai the instant it's built, racing the clear.
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Column(
          children: [
            _LoginBanner(text: l10n.loginBanner),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(AccountLoginPage._loginUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  userAgent: _androidLoginUserAgent,
                ),
                // Real popup, not a same-view redirect -- see
                // _googlePopupRequest's doc comment for why a same-view
                // loadUrl(request.request.url) doesn't work here.
                onCreateWindow: (controller, request) async {
                  setState(() => _googlePopupRequest = request);
                  return true;
                },
              ),
            ),
          ],
        ),
        if (_googlePopupRequest != null) _buildGooglePopup(),
      ],
    );
  }

  Widget _buildGooglePopup() {
    return Positioned.fill(
      child: Material(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  // The user backing out of the Google popup shouldn't be
                  // stuck -- closing it just returns to the claude.ai tab
                  // underneath, where "Continue with email" still works.
                  onPressed: () => setState(() => _googlePopupRequest = null),
                ),
              ),
            ),
            Expanded(
              child: InAppWebView(
                windowId: _googlePopupRequest!.windowId,
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  userAgent: _androidLoginUserAgent,
                ),
                // Google's OAuth flow closes its own popup (window.close())
                // once it's done redirecting back to claude.ai -- the same
                // shared CookieManager jar means the session it set is
                // already visible to the claude.ai tab underneath once this
                // closes, no extra plumbing needed.
                onCloseWindow: (controller) {
                  if (mounted) setState(() => _googlePopupRequest = null);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHint(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 48),
            const SizedBox(height: 16),
            Text(l10n.loginDesktopHint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _LoginBanner extends StatelessWidget {
  const _LoginBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
