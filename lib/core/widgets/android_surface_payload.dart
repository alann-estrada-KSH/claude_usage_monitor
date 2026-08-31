import 'dart:convert';

import '../models/claude_account.dart';

String encodeSelectedAccountIds(List<String> accountIds) =>
    jsonEncode(accountIds);

Map<String, dynamic> buildAndroidSurfacePayload(
  List<ClaudeAccount> accounts, {
  required DateTime now,
  required Duration staleAfter,
}) {
  return {
    'version': 1,
    'updatedAt': now.toUtc().toIso8601String(),
    'accounts': accounts.map((account) {
      final usage = account.lastKnownUsage;
      final fetchedAt = account.lastFetchedAt;
      return {
        'id': account.apiAccountId,
        'label': account.label,
        'provider': account.providerType.name,
        'fiveHourPercent': usage?.fiveHourPercent,
        'weeklyPercent': usage?.weeklyPercent,
        'monthlyPercent': usage?.monthlyPercent,
        'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
        'stale': fetchedAt == null || now.difference(fetchedAt) > staleAfter,
        'sessionExpired': account.lastFetchSessionExpired,
        'hasError': account.lastFetchError != null,
      };
    }).toList(),
  };
}
