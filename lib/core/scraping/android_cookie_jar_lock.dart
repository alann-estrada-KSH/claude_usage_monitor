import 'dart:async';

/// Serializes every operation that touches Android's single shared
/// CookieManager jar (see AndroidAccountCookieStore for why there's only
/// one jar at all). The login flow's clear-then-capture and each account's
/// periodic cookie refresh (see android_usage_fetcher.dart) all read/write
/// that same jar -- letting two run concurrently would mix accounts'
/// cookies together, the same class of bug the login flow's own
/// clear-before-login step exists to prevent.
class AndroidCookieJarLock {
  AndroidCookieJarLock._();
  static Future<void> _queue = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() action) {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  /// For callers that need to hold the lock across multiple separate async
  /// steps rather than one contiguous action -- AccountLoginPage clears the
  /// jar when the screen opens, then doesn't capture from it again until
  /// the user taps Done, possibly minutes later. Must be called exactly
  /// once when the caller is finished.
  static Future<void Function()> acquire() async {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    await previous;
    return completer.complete;
  }
}
