import 'dart:async';

/// Serializes all `desktop_webview_window` usage app-wide.
///
/// The plugin's native side keeps a single shared window registry and
/// method channel; letting the background usage-scraper create/destroy a
/// headless window while the login flow's window is also open led to a
/// `MissingPluginException` and, eventually, a crash. There's no real need
/// for concurrency here anyway -- only ever run one native webview window
/// operation at a time.
class DesktopWebviewLock {
  DesktopWebviewLock._();
  static Future<void> _queue = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() action) {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}
