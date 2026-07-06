import 'dart:ui' show PlatformDispatcher;

import '../models/claude_account.dart';
import '../models/usage_snapshot.dart';
import '../storage/notification_log_store.dart';
import 'notification_service.dart';

/// Watches each refresh for two transitions and fires a local notification
/// exactly once per occurrence (deduped via [NotificationLogStore], keyed by
/// account + window + reset timestamp so a new cycle can alert again):
///
/// - A window that had real usage (>1%) crossing its `resetAt` -- "your
///   limit just reset".
/// - A window reaching 100% -- "you've hit the limit".
///
/// Both are detected on refresh (this app only ever runs "while open" per
/// its own design -- no background service), not scheduled ahead of time.
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
  }) async {
    await _checkWindow(
      account: account,
      windowKey: 'five_hour',
      previousPercent: previous?.fiveHourPercent,
      previousResetAt: previous?.fiveHourResetAt,
      nextPercent: next.fiveHourPercent,
    );
    await _checkWindow(
      account: account,
      windowKey: 'weekly',
      previousPercent: previous?.weeklyPercent,
      previousResetAt: previous?.weeklyResetAt,
      nextPercent: next.weeklyPercent,
    );
  }

  Future<void> _checkWindow({
    required ClaudeAccount account,
    required String windowKey,
    required double? previousPercent,
    required DateTime? previousResetAt,
    required double? nextPercent,
  }) async {
    // ponytail: language for notification text comes from the OS locale,
    // not the in-app language override setting -- wiring that through would
    // mean threading SettingsProvider into AccountProvider/this service for
    // a cosmetic edge case (override language differs from OS language).
    // Upgrade path: pass a `String Function() languageCode` resolver in if
    // that mismatch actually bothers someone.
    final lang = PlatformDispatcher.instance.locale.languageCode == 'es' ? 'es' : 'en';

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
      // Re-arm: next time this window hits 100% again (a future cycle), it
      // should notify again instead of staying silent forever after the
      // first time.
      await _log.clear(exhaustedKey);
    }
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
}
