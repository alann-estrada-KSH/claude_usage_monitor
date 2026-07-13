import 'dart:io' show Platform;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../notifications/notification_service.dart';
import '../notifications/usage_alert_service.dart';
import '../scraping/usage_scraper.dart';
import '../storage/account_store.dart';
import '../storage/app_settings_store.dart';
import '../storage/notification_log_store.dart';

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

      final accountStore = AccountStore();
      await accountStore.init();
      final logStore = NotificationLogStore();
      await logStore.init();
      final settingsStore = AppSettingsStore();
      await settingsStore.init();

      await NotificationService.instance.initBackground();
      final alerts = UsageAlertService(
        notifications: NotificationService.instance,
        log: logStore,
      );

      final scraper = UsageScraper();
      final settings = settingsStore.load();

      for (final account in accountStore.getAll()) {
        try {
          final previous = account.lastKnownUsage;
          final snapshot = await scraper.fetchUsage(profile: account.id);
          if (snapshot.isAvailable) {
            final updated = account.copyWith(
              lastKnownUsage: snapshot,
              lastFetchedAt: DateTime.now(),
              clearLastFetchError: true,
              lastFetchSessionExpired: false,
            );
            await accountStore.save(updated);
            await alerts.check(
              account: updated,
              previous: previous,
              next: snapshot,
              warningThreshold: settings.warningThresholdPercent,
              criticalThreshold: settings.criticalThresholdPercent,
            );
          } else if (snapshot.sessionExpired) {
            await accountStore.save(account.copyWith(
              lastFetchedAt: DateTime.now(),
              clearLastFetchError: true,
              lastFetchSessionExpired: true,
            ));
          } else {
            await accountStore.save(account.copyWith(
              lastFetchedAt: DateTime.now(),
              lastFetchError: snapshot.parseError ?? 'Unknown error',
              lastFetchSessionExpired: false,
            ));
          }
        } catch (_) {
          // Per-account failure must not stop other accounts or crash WorkManager.
        }
      }
    } catch (_) {
      // Top-level guard: WorkManager retries on unhandled exceptions, which
      // would storm the API if init itself is broken -- eat it instead.
    }
    return true;
  });
}

/// Android-only periodic background task that keeps Claude's session cookies
/// alive AND runs a full usage fetch + alert check so users get notified of
/// limit resets and threshold crossings even when the app is not open.
/// No-op everywhere else.
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
