import 'dart:ui' show PlatformDispatcher;

import '../models/claude_account.dart';
import '../models/usage_snapshot.dart';
import '../storage/notification_log_store.dart';
import 'notification_service.dart';

/// Watches each refresh for transitions that should fire a local notification,
/// deduped via [NotificationLogStore]:
///
/// - Window crossing its `resetAt` -- "limit just reset" (immediate)
/// - Window reaching 100% -- "limit exhausted" (immediate)
/// - Window crossing the warning threshold (upward) -- "usage warning"
/// - Window crossing the critical threshold (upward) -- "usage critical"
/// - Schedules an exact/inexact alarm for each window's next `resetAt` so the
///   reset notification fires even when the app is not in the foreground.
class UsageAlertService {
  UsageAlertService({NotificationService? notifications, NotificationLogStore? log})
      : _notifications = notifications ?? NotificationService.instance,
        _log = log ?? NotificationLogStore();

  final NotificationService _notifications;
  final NotificationLogStore _log;

  Future<void> init() => _log.init();

  Future<void> check({
    required ClaudeAccount account,
    required UsageSnapshot? previous,
    required UsageSnapshot next,
    int warningThreshold = 80,
    int criticalThreshold = 95,
  }) async {
    await _checkWindow(
      account: account,
      windowKey: 'five_hour',
      previousPercent: previous?.fiveHourPercent,
      previousResetAt: previous?.fiveHourResetAt,
      nextPercent: next.fiveHourPercent,
      nextResetAt: next.fiveHourResetAt,
      warningThreshold: warningThreshold,
      criticalThreshold: criticalThreshold,
    );
    await _checkWindow(
      account: account,
      windowKey: 'weekly',
      previousPercent: previous?.weeklyPercent,
      previousResetAt: previous?.weeklyResetAt,
      nextPercent: next.weeklyPercent,
      nextResetAt: next.weeklyResetAt,
      warningThreshold: warningThreshold,
      criticalThreshold: criticalThreshold,
    );
  }

  Future<void> _checkWindow({
    required ClaudeAccount account,
    required String windowKey,
    required double? previousPercent,
    required DateTime? previousResetAt,
    required double? nextPercent,
    required DateTime? nextResetAt,
    required int warningThreshold,
    required int criticalThreshold,
  }) async {
    // ponytail: language for notification text comes from the OS locale,
    // not the in-app language override setting -- wiring that through would
    // mean threading SettingsProvider into AccountProvider/this service for
    // a cosmetic edge case (override language differs from OS language).
    final lang = PlatformDispatcher.instance.locale.languageCode == 'es' ? 'es' : 'en';

    // --- Reset detection (immediate, after the fact) ---
    if (previousResetAt != null &&
        previousPercent != null &&
        previousPercent > 1 &&
        DateTime.now().isAfter(previousResetAt)) {
      final key = '${account.id}:$windowKey:reset:${previousResetAt.toIso8601String()}';
      if (!_log.hasFired(key)) {
        await _log.markFired(key);
        await _notifications.show(
          title: _resetTitle(lang),
          body: _resetBody(lang, windowKey, account.label),
        );
      }
    }

    // --- Exhausted (100%) ---
    final exhaustedKey = '${account.id}:$windowKey:exhausted';
    if (nextPercent != null && nextPercent >= 100) {
      if (!_log.hasFired(exhaustedKey)) {
        await _log.markFired(exhaustedKey);
        await _notifications.show(
          title: _exhaustedTitle(lang),
          body: _exhaustedBody(lang, windowKey, account.label),
        );
      }
    } else if (nextPercent != null && nextPercent < 100) {
      await _log.clear(exhaustedKey);
    }

    // --- Threshold crossings (upward only, re-armed when falling back below) ---
    if (nextPercent != null && previousPercent != null) {
      final prev = previousPercent;
      final next = nextPercent;

      final warnKey = '${account.id}:$windowKey:warning:$warningThreshold';
      if (next >= warningThreshold && prev < warningThreshold) {
        if (!_log.hasFired(warnKey)) {
          await _log.markFired(warnKey);
          await _notifications.show(
            title: _warningTitle(lang),
            body: _thresholdBody(lang, windowKey, account.label, next.toInt()),
          );
        }
      } else if (next < warningThreshold) {
        await _log.clear(warnKey);
      }

      final critKey = '${account.id}:$windowKey:critical:$criticalThreshold';
      if (next >= criticalThreshold && prev < criticalThreshold) {
        if (!_log.hasFired(critKey)) {
          await _log.markFired(critKey);
          await _notifications.show(
            title: _criticalTitle(lang),
            body: _thresholdBody(lang, windowKey, account.label, next.toInt()),
          );
        }
      } else if (next < criticalThreshold) {
        await _log.clear(critKey);
      }
    }

    // --- Schedule an alarm for the next reset (fires even when app is killed) ---
    if (nextResetAt != null && nextResetAt.isAfter(DateTime.now())) {
      final schedId = _scheduleId(account.id, windowKey);
      await _notifications.cancelScheduled(schedId);
      await _notifications.scheduleAt(
        id: schedId,
        title: _resetTitle(lang),
        body: _resetBody(lang, windowKey, account.label),
        when: nextResetAt,
      );
    }
  }

  // Stable IDs in ranges that don't collide with sequential immediate IDs.
  // five_hour → 0x4000-0x7FFF, weekly → 0x8000-0xBFFF.
  int _scheduleId(String accountId, String windowKey) {
    final h = accountId.hashCode.abs() % 0x3FFF;
    return windowKey == 'five_hour' ? 0x4000 + h : 0x8000 + h;
  }

  String _windowLabel(String lang, String windowKey) {
    if (windowKey == 'five_hour') return lang == 'es' ? 'sesión' : 'session';
    return lang == 'es' ? 'límite semanal' : 'weekly limit';
  }

  String _resetTitle(String lang) => lang == 'es' ? 'Límite reiniciado' : 'Limit reset';

  String _resetBody(String lang, String windowKey, String accountLabel) {
    final w = _windowLabel(lang, windowKey);
    return lang == 'es'
        ? 'Tu $w de "$accountLabel" ya se reinició.'
        : 'Your $w for "$accountLabel" just reset.';
  }

  String _exhaustedTitle(String lang) => lang == 'es' ? 'Límite alcanzado' : 'Limit reached';

  String _exhaustedBody(String lang, String windowKey, String accountLabel) {
    final w = _windowLabel(lang, windowKey);
    return lang == 'es'
        ? 'Alcanzaste el límite de $w en "$accountLabel".'
        : 'You hit the $w limit on "$accountLabel".';
  }

  String _warningTitle(String lang) => lang == 'es' ? 'Aviso de uso' : 'Usage warning';

  String _criticalTitle(String lang) => lang == 'es' ? 'Uso crítico' : 'Usage critical';

  String _thresholdBody(String lang, String windowKey, String accountLabel, int percent) {
    final w = _windowLabel(lang, windowKey);
    return lang == 'es'
        ? 'Tu $w de "$accountLabel" está al $percent%.'
        : 'Your $w for "$accountLabel" is at $percent%.';
  }
}
