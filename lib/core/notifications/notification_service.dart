import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/claude_account.dart';

/// Thin wrapper around flutter_local_notifications. Android + Linux only --
/// those are the two platforms this app is actually tested on (see README).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _persistentUsageId = 0x434c4155;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;

  // Linux notification daemons (dunst and others) rate-limit bursts from the
  // same app -- firing several alerts back-to-back (e.g. multiple accounts
  // crossing a threshold in the same refresh cycle) hit
  // "org.freedesktop.Notifications.Error.ExcessNotificationGeneration".
  // Serialize + space out our own show() calls instead of relying on the
  // daemon to queue them.
  Future<void> _queue = Future<void>.value();
  static const _minGapBetweenShows = Duration(milliseconds: 1200);
  DateTime? _lastShownAt;

  bool get isInitialized => _initialized;

  bool get _supported => Platform.isAndroid || Platform.isLinux;

  static List<ClaudeAccount> selectPersistentAccounts(
    List<ClaudeAccount> accounts, {
    required bool allAccounts,
    required List<String> accountIds,
  }) {
    if (allAccounts) return accounts;
    final selected = accountIds.toSet();
    return accounts.where((account) => selected.contains(account.id)).toList();
  }

  /// Lightweight init for the WorkManager background isolate -- skips
  /// permission requests (they require a UI) and only registers the plugin.
  Future<void> initBackground() async {
    if (_initialized || !_supported) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(
            defaultActionName: 'Open Usage Monitor',
          ),
        ),
      );
      _initialized = true;
    } catch (e) {
      print('[NotificationService] background init failed: $e');
    }
  }

  Future<void> init() async {
    if (_initialized || !_supported) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(
            defaultActionName: 'Open Usage Monitor',
          ),
        ),
      );
      _initialized = true;

      if (Platform.isAndroid) {
        // Android 13+ (API 33+) shows nothing at all until this is granted
        // -- easy to miss since older Android versions never needed it,
        // which is exactly the kind of thing that silently breaks
        // notifications on a newer test device without any error.
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
        // Without this, scheduled notifications fall back to *inexact*
        // delivery, which Doze/OEM battery management (confirmed on a
        // Motorola device) can defer by many minutes instead of firing
        // close to the requested time. This opens the system settings
        // screen for the user to grant it; scheduleTest() below checks
        // whether it was actually granted and falls back gracefully if not.
        await androidPlugin?.requestExactAlarmsPermission();
      }
    } catch (e) {
      // No notification daemon reachable over D-Bus (headless/minimal WM),
      // or some other platform quirk -- degrade to notifications simply not
      // firing rather than taking the whole app down at startup.
      print('[NotificationService] init failed, notifications disabled: $e');
    }
  }

  /// Best-effort permission/enablement check for the debug panel. `null`
  /// means "unknown" (e.g. Linux, where there's no equivalent API).
  Future<bool?> areNotificationsEnabled() async {
    if (!_initialized || !Platform.isAndroid) return null;
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.areNotificationsEnabled();
    } catch (e) {
      print('[NotificationService] areNotificationsEnabled failed: $e');
      return null;
    }
  }

  Future<void> show({required String title, required String body}) {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    return previous
        .then((_) => _showThrottled(title, body))
        .whenComplete(completer.complete);
  }

  /// Keeps a quiet, non-dismissible Android status notification with the last
  /// known usage. It is intentionally separate from alert notifications.
  Future<void> updatePersistentUsage(
    List<ClaudeAccount> accounts, {
    bool allAccounts = true,
    List<String> accountIds = const [],
  }) async {
    if (!_initialized || !Platform.isAndroid) return;
    final selected = selectPersistentAccounts(
      accounts,
      allAccounts: allAccounts,
      accountIds: accountIds,
    );
    if (selected.isEmpty) {
      await cancel(_persistentUsageId);
      return;
    }
    final lang = PlatformDispatcher.instance.locale.languageCode == 'es'
        ? 'es'
        : 'en';
    final lines = selected
        .map((account) {
          final usage = account.lastKnownUsage;
          final five = usage?.fiveHourPercent?.toStringAsFixed(0) ?? '--';
          final weekly = usage?.weeklyPercent?.toStringAsFixed(0) ?? '--';
          return lang == 'es'
              ? '${account.label}: sesión $five% · semanal $weekly%'
              : '${account.label}: session $five% · weekly $weekly%';
        })
        .join('\n');
    try {
      await _plugin.show(
        _persistentUsageId,
        lang == 'es' ? 'Monitor de uso' : 'Usage Monitor',
        lines,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'usage_status',
            'Usage status',
            channelDescription: 'Current usage',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            category: AndroidNotificationCategory.status,
          ),
        ),
      );
    } catch (e) {
      print('[NotificationService] persistent usage update failed: $e');
    }
  }

  Future<void> _showThrottled(String title, String body) async {
    if (!_initialized) return;
    final lastShown = _lastShownAt;
    if (lastShown != null) {
      final elapsed = DateTime.now().difference(lastShown);
      if (elapsed < _minGapBetweenShows) {
        await Future.delayed(_minGapBetweenShows - elapsed);
      }
    }
    _lastShownAt = DateTime.now();
    try {
      await _plugin.show(
        _nextId++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'usage_alerts',
            'Usage alerts',
            channelDescription: 'Limit resets and exhausted-limit alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
          linux: LinuxNotificationDetails(),
        ),
      );
    } catch (e) {
      print('[NotificationService] show failed: $e');
    }
  }

  /// Cancels a previously-scheduled notification by [id]. No-op if none exists.
  Future<void> cancelScheduled(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      print('[NotificationService] cancel($id) failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      print('[NotificationService] cancel($id) failed: $e');
    }
  }

  /// Schedules a notification to fire at [when] (absolute local time).
  /// Android only -- desktop never had schedulable background alerts.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_initialized || !Platform.isAndroid) return;
    if (!when.isAfter(DateTime.now())) return;
    try {
      var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (canExact) scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

      final utc = when.toUtc();
      final tzWhen = tz.TZDateTime.utc(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second,
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'usage_alerts',
            'Usage alerts',
            channelDescription: 'Limit resets and exhausted-limit alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('[NotificationService] scheduleAt failed: $e');
    }
  }

  /// Schedules (rather than fires immediately) a test notification -- lets
  /// the debug panel confirm notifications still arrive after the app has
  /// actually been backgrounded for a bit, not just while it's frontmost.
  /// Uses an *exact* alarm when the permission was granted (requested in
  /// init()) so it actually lands close to [delay] -- inexact delivery is
  /// subject to Doze/OEM battery deferral, confirmed on-device to arrive
  /// many minutes late rather than at the requested time. Falls back to
  /// inexact if the user denied the exact-alarm permission, since scheduling
  /// exact without it throws on Android 12+.
  Future<void> scheduleTest({
    required String title,
    required String body,
    Duration delay = const Duration(seconds: 15),
  }) async {
    if (!_initialized) return;
    try {
      var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final canExact =
            await androidPlugin?.canScheduleExactNotifications() ?? false;
        if (canExact) scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
      await _plugin.zonedSchedule(
        _nextId++,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(delay),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'usage_alerts',
            'Usage alerts',
            channelDescription: 'Limit resets and exhausted-limit alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
          linux: LinuxNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('[NotificationService] scheduleTest failed: $e');
    }
  }
}
