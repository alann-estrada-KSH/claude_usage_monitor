import 'dart:io' show Platform;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../notifications/notification_service.dart';
import '../notifications/usage_alert_service.dart';
import '../models/usage_update.dart';
import '../models/usage_history_point.dart';
import '../scraping/usage_scraper.dart';
import '../storage/account_store.dart';
import '../storage/app_settings_store.dart';
import '../storage/notification_log_store.dart';
import '../storage/usage_history_store.dart';
import '../widgets/android_widget_bridge.dart';

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
      final historyStore = UsageHistoryStore();
      await historyStore.init();

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
          final snapshot = await scraper.fetchUsage(
            profile: account.id,
            providerType: account.providerType,
          );
          final updated = applyUsageSnapshot(
            account,
            snapshot,
            fetchedAt: DateTime.now(),
          );
          await accountStore.save(updated);
          await alerts.checkAccountAvailability(
            account: updated,
            privacyMode: settings.pinnedNotificationPrivacyMode,
            languageCode: settings.languageCode,
          );
          if (snapshot.isAvailable) {
            await alerts.check(
              account: updated,
              previous: previous,
              next: snapshot,
              warningThreshold:
                  account.warningThresholdPercent ??
                  settings.warningThresholdPercent,
              criticalThreshold:
                  account.criticalThresholdPercent ??
                  settings.criticalThresholdPercent,
              privacyMode: settings.pinnedNotificationPrivacyMode,
            );
            await historyStore.append(
              account.id,
              UsageHistoryPoint(
                timestamp: DateTime.now(),
                fiveHourPercent: snapshot.fiveHourPercent,
                weeklyPercent: snapshot.weeklyPercent,
              ),
            );
          }
        } catch (_) {
          // Per-account failure must not stop other accounts or crash WorkManager.
        }
      }
      await AndroidWidgetBridge.publish(
        accountStore.getAll(),
        notifyNative: true,
        persistentNotificationAllAccounts:
            settings.pinnedNotificationAllAccounts,
        persistentNotificationAccountIds: settings.pinnedNotificationAccountIds,
        persistentNotificationEnabled: settings.pinnedNotificationEnabled,
        persistentNotificationShowProvider:
            settings.pinnedNotificationShowProvider,
        persistentNotificationShowFiveHour:
            settings.pinnedNotificationShowFiveHour,
        persistentNotificationShowWeekly: settings.pinnedNotificationShowWeekly,
        persistentNotificationCompact: settings.pinnedNotificationCompact,
        persistentNotificationPrivacyMode:
            settings.pinnedNotificationPrivacyMode,
        widgetAllAccounts: settings.widgetAllAccounts,
        widgetAccountIds: settings.widgetAccountIds,
      );
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
