import 'package:claude_usage_monitor/core/notifications/usage_alert_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account refresh failure is not reported as provider outage', () {
    final message = UsageAlertService.buildAccountFailureNotification(
      accountLabel: 'Personal',
      providerLabel: 'Claude',
      languageCode: 'es',
    );

    expect(message.title, 'No se pudo actualizar la cuenta');
    expect(message.body, contains('Personal'));
    expect(message.body, contains('Claude'));
    expect(message.body, isNot(contains('Proveedor no disponible')));
  });

  test('hidden privacy removes account and provider names from failure alert', () {
    final message = UsageAlertService.buildAccountFailureNotification(
      accountLabel: 'Personal',
      providerLabel: 'Claude',
      languageCode: 'es',
      privacyMode: 'hidden',
    );

    expect(message.body, isNot(contains('Personal')));
    expect(message.body, isNot(contains('Claude')));
  });
}
