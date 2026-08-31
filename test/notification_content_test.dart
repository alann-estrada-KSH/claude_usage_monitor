import 'package:claude_usage_monitor/core/models/claude_account.dart';
import 'package:claude_usage_monitor/core/models/provider_type.dart';
import 'package:claude_usage_monitor/core/models/usage_snapshot.dart';
import 'package:claude_usage_monitor/core/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final account = ClaudeAccount(
    id: 'internal',
    apiAccountId: 'public',
    label: 'Trabajo',
    providerType: AccountProviderType.codex,
    lastKnownUsage: UsageSnapshot(
      fetchedAt: DateTime.utc(2026, 8, 30),
      fiveHourPercent: 21,
      weeklyPercent: 54,
    ),
  );

  test('full notification includes account, provider, 5h and week', () {
    final body = NotificationService.buildPersistentBody(
      [account],
      languageCode: 'es',
      privacyMode: 'full',
      showProvider: true,
      showFiveHour: true,
      showWeekly: true,
    );
    expect(body, contains('Trabajo'));
    expect(body, contains('Codex'));
    expect(body, contains('5 h 21%'));
    expect(body, contains('7 d 54%'));
  });

  test('hidden notification exposes no account usage', () {
    final body = NotificationService.buildPersistentBody(
      [account],
      languageCode: 'es',
      privacyMode: 'hidden',
      showProvider: true,
      showFiveHour: true,
      showWeekly: true,
    );
    expect(body, 'Datos de uso disponibles');
    expect(body, isNot(contains('Trabajo')));
    expect(body, isNot(contains('21')));
  });
}
