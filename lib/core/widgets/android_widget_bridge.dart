import 'dart:convert';
import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_surface_bridge/android_surface_bridge.dart';

import '../models/claude_account.dart';
import '../notifications/notification_service.dart';
import 'android_surface_payload.dart';

/// Publishes the last known values for Android components that run without a
/// Flutter isolate (home-screen widgets and the Quick Settings tile).
class AndroidWidgetBridge {
  AndroidWidgetBridge._();

  static Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (key) =>
            key.startsWith('usage_widget_') ||
            key.startsWith('widget_') ||
            key == 'wear_usage_payload',
      )) {
        await prefs.remove(key);
      }
      await NotificationService.instance.cancelAll();
      await AndroidSurfaceBridge.requestUpdate();
    } catch (_) {}
  }

  static Future<void> publish(
    List<ClaudeAccount> accounts, {
    bool notifyNative = true,
    bool persistentNotificationAllAccounts = true,
    List<String> persistentNotificationAccountIds = const [],
    bool persistentNotificationEnabled = true,
    bool persistentNotificationShowProvider = true,
    bool persistentNotificationShowFiveHour = true,
    bool persistentNotificationShowWeekly = true,
    String persistentNotificationPrivacyMode = 'full',
    bool widgetAllAccounts = true,
    List<String> widgetAccountIds = const [],
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usage_widget_count', accounts.length);
      await prefs.setBool('widget_all_accounts', widgetAllAccounts);
      await prefs.setString(
        'widget_account_ids_json',
        encodeSelectedAccountIds(widgetAccountIds),
      );
      for (var i = 0; i < accounts.length; i++) {
        final account = accounts[i];
        final usage = account.lastKnownUsage;
        await prefs.setString('usage_widget_${i}_id', account.id);
        await prefs.setString('usage_widget_${i}_label', account.label);
        await prefs.setString(
          'usage_widget_${i}_provider',
          account.providerType.displayName,
        );
        // Android SharedPreferences has no Dart-double type. Integer display
        // values keep the native reader compatible with Flutter storage.
        await prefs.setInt(
          'usage_widget_${i}_five_hour',
          usage?.fiveHourPercent?.round() ?? -1,
        );
        await prefs.setInt(
          'usage_widget_${i}_weekly',
          usage?.weeklyPercent?.round() ?? -1,
        );
        await prefs.setBool(
          'usage_widget_${i}_has_error',
          account.lastFetchError != null && usage == null,
        );
        await prefs.setBool(
          'usage_widget_${i}_session_expired',
          account.lastFetchSessionExpired,
        );
        await prefs.setBool(
          'usage_widget_${i}_stale',
          account.lastFetchedAt == null ||
              DateTime.now().difference(account.lastFetchedAt!) >
                  const Duration(minutes: 5),
        );
      }
      await prefs.setString(
        'usage_widget_updated_at',
        DateTime.now().toIso8601String(),
      );
      await prefs.setString(
        'wear_usage_payload',
        jsonEncode(
          buildAndroidSurfacePayload(
            accounts,
            now: DateTime.now(),
            staleAfter: const Duration(minutes: 5),
          ),
        ),
      );
      await NotificationService.instance.updatePersistentUsage(
        accounts,
        enabled: persistentNotificationEnabled,
        allAccounts: persistentNotificationAllAccounts,
        accountIds: persistentNotificationAccountIds,
        showProvider: persistentNotificationShowProvider,
        showFiveHour: persistentNotificationShowFiveHour,
        showWeekly: persistentNotificationShowWeekly,
        privacyMode: persistentNotificationPrivacyMode,
      );
      if (notifyNative) await AndroidSurfaceBridge.requestUpdate();
    } catch (_) {
      // Native surfaces must never break usage refreshes.
    }
  }
}
