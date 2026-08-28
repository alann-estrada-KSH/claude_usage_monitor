import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/claude_account.dart';
import '../notifications/notification_service.dart';

/// Publishes the last known values for Android components that run without a
/// Flutter isolate (home-screen widgets and the Quick Settings tile).
class AndroidWidgetBridge {
  AndroidWidgetBridge._();

  static const _channel = MethodChannel('claude_usage_monitor/widget');

  static Future<void> publish(
    List<ClaudeAccount> accounts, {
    bool notifyNative = true,
    bool persistentNotificationAllAccounts = true,
    List<String> persistentNotificationAccountIds = const [],
    bool widgetAllAccounts = true,
    List<String> widgetAccountIds = const [],
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usage_widget_count', accounts.length);
      await prefs.setBool('widget_all_accounts', widgetAllAccounts);
      await prefs.setStringList('widget_account_ids', widgetAccountIds);
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
      }
      await prefs.setString(
        'usage_widget_updated_at',
        DateTime.now().toIso8601String(),
      );
      await NotificationService.instance.updatePersistentUsage(
        accounts,
        allAccounts: persistentNotificationAllAccounts,
        accountIds: persistentNotificationAccountIds,
      );
      if (notifyNative) await _channel.invokeMethod('updateWidgets');
    } catch (_) {
      // Native surfaces must never break usage refreshes.
    }
  }
}
