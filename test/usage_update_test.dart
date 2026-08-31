import 'package:claude_usage_monitor/core/models/claude_account.dart';
import 'package:claude_usage_monitor/core/models/provider_type.dart';
import 'package:claude_usage_monitor/core/models/usage_snapshot.dart';
import 'package:claude_usage_monitor/core/models/usage_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cached = UsageSnapshot(
    fetchedAt: DateTime.utc(2026, 8, 30, 10),
    fiveHourPercent: 42,
    weeklyPercent: 61,
  );
  final account = ClaudeAccount(
    id: 'account-1',
    apiAccountId: 'public-1',
    label: 'Work',
    providerType: AccountProviderType.codex,
    lastKnownUsage: cached,
  );

  test('session expiration preserves last successful usage', () {
    final updated = applyUsageSnapshot(
      account,
      UsageSnapshot.unavailable('expired', sessionExpired: true),
      fetchedAt: DateTime.utc(2026, 8, 30, 11),
    );

    expect(updated.lastKnownUsage, same(cached));
    expect(updated.lastFetchSessionExpired, isTrue);
    expect(updated.consecutiveFailures, 0);
  });

  test('transient failures preserve cache and increment failure count', () {
    final updated = applyUsageSnapshot(
      account.copyWith(consecutiveFailures: 1),
      UsageSnapshot.unavailable('timeout'),
      fetchedAt: DateTime.utc(2026, 8, 30, 11),
    );

    expect(updated.lastKnownUsage, same(cached));
    expect(updated.lastFetchError, 'timeout');
    expect(updated.consecutiveFailures, 2);
  });

  test('successful refresh clears failures', () {
    final next = UsageSnapshot(
      fetchedAt: DateTime.utc(2026, 8, 30, 11),
      fiveHourPercent: 12,
      weeklyPercent: 24,
    );
    final updated = applyUsageSnapshot(
      account.copyWith(consecutiveFailures: 3),
      next,
      fetchedAt: next.fetchedAt,
    );

    expect(updated.lastKnownUsage, same(next));
    expect(updated.lastFetchError, isNull);
    expect(updated.consecutiveFailures, 0);
  });
}
