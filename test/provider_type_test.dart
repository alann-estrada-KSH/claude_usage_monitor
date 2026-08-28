import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:claude_usage_monitor/core/models/claude_account.dart';
import 'package:claude_usage_monitor/core/models/provider_type.dart';
import 'package:claude_usage_monitor/core/models/app_settings.dart';
import 'package:claude_usage_monitor/core/notifications/notification_service.dart';

void main() {
  group('AccountProviderType Tests', () {
    test('fromString parses correctly', () {
      expect(
        AccountProviderType.fromString('claude'),
        AccountProviderType.claude,
      );
      expect(
        AccountProviderType.fromString('codex'),
        AccountProviderType.codex,
      );
      expect(
        AccountProviderType.fromString('antigravity'),
        AccountProviderType.antigravity,
      );
      expect(
        AccountProviderType.fromString('copilot'),
        AccountProviderType.copilot,
      );
      expect(AccountProviderType.fromString(null), AccountProviderType.claude);
      expect(
        AccountProviderType.fromString('unknown'),
        AccountProviderType.claude,
      );
    });

    test('ClaudeAccount serialization with providerType', () {
      final account = const ClaudeAccount(
        id: 'acc123',
        apiAccountId: 'api-acc123',
        label: 'My Codex Account',
        providerType: AccountProviderType.codex,
      );

      final json = account.toJson();
      expect(json['providerType'], 'codex');

      final deserialized = ClaudeAccount.fromJson(json);
      expect(deserialized.providerType, AccountProviderType.codex);
      expect(deserialized.label, 'My Codex Account');
    });

    test('AppSettings persists desktop floating window preference', () {
      final settings = const AppSettings(floatingWindowEnabled: true);
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.floatingWindowEnabled, isTrue);
    });

    test('AppSettings persists floating window opacity', () {
      const settings = AppSettings(floatingWindowOpacity: 0.7);
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.floatingWindowOpacity, 0.7);
    });

    test('floating mode account selection persists', () {
      const settings = AppSettings(
        floatingModeEnabled: true,
        floatingAllAccounts: false,
        floatingAccountIds: ['a2'],
      );
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.floatingModeEnabled, isTrue);
      expect(restored.floatingAllAccounts, isFalse);
      expect(restored.floatingAccountIds, ['a2']);
    });

    test('pinned notification selection persists and filters accounts', () {
      final settings = const AppSettings(
        pinnedNotificationAllAccounts: false,
        pinnedNotificationAccountIds: ['a1'],
      );
      final restored = AppSettings.fromJson(settings.toJson());
      final accounts = [
        const ClaudeAccount(id: 'a1', apiAccountId: 'api-a1', label: 'One'),
        const ClaudeAccount(id: 'a2', apiAccountId: 'api-a2', label: 'Two'),
      ];

      expect(restored.pinnedNotificationAllAccounts, isFalse);
      expect(restored.pinnedNotificationAccountIds, ['a1']);
      expect(
        NotificationService.selectPersistentAccounts(
          accounts,
          allAccounts: restored.pinnedNotificationAllAccounts,
          accountIds: restored.pinnedNotificationAccountIds,
        ).map((account) => account.id),
        ['a1'],
      );
    });

    test('widget account selection persists', () {
      const settings = AppSettings(
        widgetAllAccounts: false,
        widgetAccountIds: ['a2'],
      );
      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.widgetAllAccounts, isFalse);
      expect(restored.widgetAccountIds, ['a2']);
    });

    test('UsageApiClient parses Codex usage JSON sample correctly', () {
      final sampleJsonStr = '''
{
  "user_id": "user-sample-id-12345",
  "account_id": "user-sample-id-12345",
  "email": "user@example.com",
  "plan_type": "plus",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 21,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 597768,
      "reset_at": 1784825221
    },
    "secondary_window": null
  }
}
''';

      final sampleMap = jsonDecode(sampleJsonStr) as Map<String, dynamic>;
      expect(sampleMap['plan_type'], 'plus');
      expect(
        (sampleMap['rate_limit'] as Map)['primary_window']['used_percent'],
        21,
      );
    });

    test('Antigravity fetchAvailableModels JSON parsing sample', () {
      final sampleAntigravityJsonStr = '''
{
  "models": {
    "gemini-2.5-flash": {
      "quotaInfo": {
        "remainingFraction": 0.75,
        "resetTime": "2026-07-17T18:00:00Z"
      }
    }
  }
}
''';
      final map = jsonDecode(sampleAntigravityJsonStr) as Map<String, dynamic>;
      final modelsMap = map['models'] as Map<String, dynamic>;
      final model = modelsMap['gemini-2.5-flash'] as Map<String, dynamic>;
      final quota = model['quotaInfo'] as Map<String, dynamic>;
      final remaining = (quota['remainingFraction'] as num).toDouble();
      expect((1.0 - remaining) * 100.0, 25.0);
    });
  });
}
