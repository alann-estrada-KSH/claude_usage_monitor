import 'claude_account.dart';
import 'usage_snapshot.dart';

ClaudeAccount applyUsageSnapshot(
  ClaudeAccount account,
  UsageSnapshot snapshot, {
  required DateTime fetchedAt,
}) {
  if (snapshot.isAvailable) {
    return account.copyWith(
      lastKnownUsage: snapshot,
      lastFetchedAt: fetchedAt,
      clearLastFetchError: true,
      lastFetchSessionExpired: false,
      consecutiveFailures: 0,
    );
  }
  if (snapshot.sessionExpired) {
    return account.copyWith(
      lastFetchedAt: fetchedAt,
      clearLastFetchError: true,
      lastFetchSessionExpired: true,
      consecutiveFailures: 0,
    );
  }
  return account.copyWith(
    lastFetchedAt: fetchedAt,
    lastFetchError: snapshot.parseError ?? 'Unknown error',
    lastFetchSessionExpired: false,
    consecutiveFailures: account.consecutiveFailures + 1,
  );
}
