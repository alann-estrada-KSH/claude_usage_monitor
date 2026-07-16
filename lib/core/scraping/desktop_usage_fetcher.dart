import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';

import '../models/provider_type.dart';
import 'desktop_webview_lock.dart';

/// Grabs session cookies via a `desktop_webview_window` webview
/// (webkit2gtk on Linux, WebView2 on Windows) for the requested provider.
Future<String> fetchCookieHeaderDesktop({
  Duration timeout = const Duration(seconds: 20),
  String? profile,
  AccountProviderType providerType = AccountProviderType.claude,
}) {
  return DesktopWebviewLock.run(
    () => _fetchCookieHeaderDesktop(timeout: timeout, profile: profile, providerType: providerType),
  );
}

Future<String> _fetchCookieHeaderDesktop({
  required Duration timeout,
  String? profile,
  required AccountProviderType providerType,
}) async {
  Webview? webview;
  try {
    webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 1280,
        windowHeight: 800,
        title: 'usage-fetch',
        titleBarHeight: 0,
        profile: profile,
      ),
    );
    await webview.setWebviewWindowVisibility(false);
    webview.launch(providerType.pingUrl);

    await _waitForNavigationToSettle(webview, timeout);
    await Future.delayed(const Duration(milliseconds: 1500));

    final cookies = await webview.getAllCookies();
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  } finally {
    webview?.close();
  }
}

Future<void> _waitForNavigationToSettle(Webview webview, Duration timeout) async {
  final completer = Completer<void>();
  var sawLoading = false;

  void listener() {
    if (webview.isNavigating.value) {
      sawLoading = true;
    } else if (sawLoading && !completer.isCompleted) {
      completer.complete();
    }
  }

  webview.isNavigating.addListener(listener);
  try {
    await completer.future.timeout(timeout, onTimeout: () {});
  } finally {
    webview.isNavigating.removeListener(listener);
  }
}
