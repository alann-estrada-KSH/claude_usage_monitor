import 'dart:convert';

import 'package:claude_usage_monitor/core/models/claude_account.dart';
import 'package:claude_usage_monitor/core/models/provider_type.dart';
import 'package:claude_usage_monitor/core/models/usage_snapshot.dart';
import 'package:claude_usage_monitor/core/widgets/android_surface_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected account ids use JSON compatible with Android readers', () {
    final encoded = encodeSelectedAccountIds(['one', 'two']);
    expect(jsonDecode(encoded), ['one', 'two']);
  });

  test('wear payload contains usage but no secret or raw response fields', () {
    final payload = buildAndroidSurfacePayload(
      [
        ClaudeAccount(
          id: 'internal-profile',
          apiAccountId: 'public-id',
          label: 'Personal',
          providerType: AccountProviderType.claude,
          lastFetchedAt: DateTime.utc(2026, 8, 30, 10),
          lastKnownUsage: UsageSnapshot(
            fetchedAt: DateTime.utc(2026, 8, 30, 10),
            fiveHourPercent: 20,
            weeklyPercent: 35,
            rawPageText: 'secret response',
          ),
        ),
      ],
      now: DateTime.utc(2026, 8, 30, 10, 10),
      staleAfter: const Duration(minutes: 5),
    );
    final encoded = jsonEncode(payload);

    expect(encoded, contains('Personal'));
    expect(encoded, contains('claude'));
    expect(encoded, isNot(contains('internal-profile')));
    expect(encoded, isNot(contains('secret response')));
    expect(encoded.toLowerCase(), isNot(contains('cookie')));
    expect(encoded.toLowerCase(), isNot(contains('token')));
    expect((payload['accounts'] as List).single['stale'], isTrue);
  });
}
