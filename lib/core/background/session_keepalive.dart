import 'dart:io' show Platform;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../scraping/usage_scraper.dart';
import '../storage/account_store.dart';

const _uniqueName = 'claude_usage_monitor.session_keepalive';
const _taskName = 'session_keepalive';

/// Runs in a separate background isolate the OS spins up on its own
/// schedule -- none of the running app's state (Provider, Hive boxes
/// already open in the foreground isolate, etc.) is available here, so it
/// re-opens what it needs from scratch.
@pragma('vm:entry-point')
void sessionKeepAliveCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();
      final store = AccountStore();
      await store.init();
      final scraper = UsageScraper();
      for (final account in store.getAll()) {
        // Just needs to hit the API with the existing session cookies to
        // keep Claude from expiring it due to inactivity -- the result
        // isn't surfaced anywhere from here, there's no UI to show it to.
        await scraper.fetchUsage(profile: account.id);
      }
    } catch (_) {
      // Best-effort ping with nobody watching this run -- never let a
      // failure here retry-storm or crash the WorkManager task.
    }
    return true;
  });
}

/// Android-only periodic background ping to keep Claude's session cookies
/// from expiring between foreground opens -- plain Dart `Timer`s stop the
/// moment Android suspends or kills the process, so WorkManager (via the
/// `workmanager` plugin) is the only way to actually run something on a
/// schedule while the app isn't in the foreground. No-op everywhere else.
class SessionKeepAlive {
  static bool get isSupported => Platform.isAndroid;

  /// WorkManager's own hard floor -- Android silently clamps anything
  /// shorter than this to 15 minutes anyway.
  static const minIntervalMinutes = 15;
  static const maxIntervalMinutes = 360;

  static Future<void> initialize() async {
    if (!isSupported) return;
    await Workmanager().initialize(sessionKeepAliveCallbackDispatcher);
  }

  static Future<void> register(Duration interval) async {
    if (!isSupported) return;
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: interval,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> cancel() async {
    if (!isSupported) return;
    await Workmanager().cancelByUniqueName(_uniqueName);
  }
}
