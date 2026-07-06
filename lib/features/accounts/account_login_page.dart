import 'dart:async';
import 'dart:io' show Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/scraping/android_account_cookie_store.dart';
import '../../core/scraping/desktop_webview_lock.dart';
import '../../l10n/app_localizations.dart';

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
    // The shared CookieManager has no per-account isolation on Android (see
    // AndroidAccountCookieStore) -- starting a new login without clearing
    // it first would silently inherit whichever account's session happens
    // to already be sitting there and capture the WRONG account's cookies
    // on Done. Every login starts from a clean slate here.
    await CookieManager.instance().deleteCookies(url: WebUri('https://claude.ai'));
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
    // Desktop: closing the native webview window fires onClose, which is
    // what actually pops this route (see _openDesktopLoginWindow) -- it
    // never runs on Android (initState only opens it `if
    // (!Platform.isAndroid)`), so _desktopWebview stays null there and this
    // button did nothing at all. Android's InAppWebView is just an embedded
    // widget in this same route, not a separate window -- popping directly
    // is the equivalent "close" action.
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
  }

  @override
  void dispose() {
    _desktopWebview?.close();
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
    return Column(
      children: [
        _LoginBanner(text: l10n.loginBanner),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(AccountLoginPage._loginUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              supportMultipleWindows: true,
              javaScriptCanOpenWindowsAutomatically: true,
            ),
            // Google's OAuth "Sign in with Google" opens via window.open();
            // without handling this it silently no-ops on Android WebView.
            // Load the popup target in the same webview instead.
            onCreateWindow: (controller, request) async {
              final url = request.request.url;
              if (url != null) await controller.loadUrl(urlRequest: URLRequest(url: url));
              return true;
            },
          ),
        ),
      ],
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
