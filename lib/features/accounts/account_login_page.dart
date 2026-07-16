import 'dart:async';
import 'dart:io' show Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/models/provider_type.dart';
import '../../core/scraping/android_account_cookie_store.dart';
import '../../core/scraping/android_cookie_jar_lock.dart';
import '../../core/scraping/desktop_webview_lock.dart';
import '../../l10n/app_localizations.dart';

const _androidLoginUserAgent =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// Shows the provider login page so the user can sign in normally.
class AccountLoginPage extends StatefulWidget {
  const AccountLoginPage({
    super.key,
    this.profile,
    this.providerType = AccountProviderType.claude,
  });

  final String? profile;
  final AccountProviderType providerType;

  @override
  State<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  Webview? _desktopWebview;
  static const _androidCookies = AndroidAccountCookieStore();

  bool _confirming = false;
  bool _androidReadyToLoad = false;
  CreateWindowAction? _googlePopupRequest;
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
    await CookieManager.instance().deleteAllCookies();
    await WebStorageManager.instance().deleteAllData();
    if (mounted) setState(() => _androidReadyToLoad = true);
  }

  Future<void> _openDesktopLoginWindow() async {
    await DesktopWebviewLock.run(() async {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 480,
          windowHeight: 720,
          title: 'Sign in to ${widget.providerType.displayName}',
          titleBarHeight: 32,
          profile: widget.profile,
        ),
      );
      webview.launch(widget.providerType.defaultLoginUrl);
      if (mounted) setState(() => _desktopWebview = webview);

      final closed = Completer<void>();
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
      if (Platform.isAndroid) {
        final profile = widget.profile;
        if (profile != null) {
          final cookies = await CookieManager.instance().getCookies(
            url: WebUri(widget.providerType.cookieDomainUrl),
          );
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
        title: Text('${l10n.loginPageTitle} (${widget.providerType.displayName})'),
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
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Column(
          children: [
            _LoginBanner(text: l10n.loginBanner),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.providerType.defaultLoginUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  userAgent: _androidLoginUserAgent,
                ),
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
