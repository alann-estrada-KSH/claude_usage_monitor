import 'package:claude_usage_monitor/core/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification display preferences round-trip', () {
    const settings = AppSettings(
      pinnedNotificationEnabled: false,
      pinnedNotificationShowProvider: false,
      pinnedNotificationShowFiveHour: true,
      pinnedNotificationShowWeekly: false,
      pinnedNotificationPrivacyMode: 'hidden',
    );

    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.pinnedNotificationEnabled, isFalse);
    expect(restored.pinnedNotificationShowProvider, isFalse);
    expect(restored.pinnedNotificationShowFiveHour, isTrue);
    expect(restored.pinnedNotificationShowWeekly, isFalse);
    expect(restored.pinnedNotificationPrivacyMode, 'hidden');
  });

  test('invalid notification privacy mode falls back to full', () {
    final restored = AppSettings.fromJson({
      'pinnedNotificationPrivacyMode': 'invalid',
    });
    expect(restored.pinnedNotificationPrivacyMode, 'full');
  });
}
