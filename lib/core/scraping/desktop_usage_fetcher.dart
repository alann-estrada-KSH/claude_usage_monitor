import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'desktop_webview_lock.dart';

/// Grabs claude.ai's session cookies via a `desktop_webview_window` webview
/// (webkit2gtk on Linux, WebView2 on Windows) -- used on Linux/Windows where
/// flutter_inappwebview has no usable headless backend (see README: its
/// Linux plugin needs WPE WebKit, which Ubuntu no longer packages).
///
/// This app used to drive the settings UI itself (simulated clicks through
/// a menu, a dialog, a tab) to scrape rendered percentages off the page.
/// That fought the page's own React app and bot-resistance checks
/// indefinitely with no reliable result. claude.ai's own usage panel gets
/// its numbers from a plain JSON API instead (see UsageApiClient) -- all
/// this needs to do is get the session cookies that API call requires.
Future<String> fetchCookieHeaderDesktop({
  Duration timeout = const Duration(seconds: 20),
  String? profile,
}) {
  return DesktopWebviewLock.run(() => _fetchCookieHeaderDesktop(timeout: timeout, profile: profile));
}

Future<String> _fetchCookieHeaderDesktop({required Duration timeout, String? profile}) async {
  Webview? webview;
  try {
    webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 1280,
        windowHeight: 800,
        title: 'usage-fetch',
        // <= 0 marks this as a background/headless window natively -- see
        // the title_bar_height branch in webview_window.cc, which keeps it
        // off-screen and fully transparent from creation rather than ever
        // showing it (even briefly) on screen.
        titleBarHeight: 0,
        // Must match whatever profile this account logged in under (see
        // AccountLoginPage) -- otherwise this reads the wrong (or the
        // shared default, cookie-less) context's cookies.
        profile: profile,
      ),
    );
    await webview.setWebviewWindowVisibility(false);
    webview.launch('https://claude.ai/new');

    await _waitForNavigationToSettle(webview, timeout);

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
