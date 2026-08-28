import 'dart:math';

import 'provider_type.dart';
import 'usage_snapshot.dart';

String generateApiAccountId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// An account being monitored (Claude, Codex, Antigravity). [id] doubles as the isolated
/// WebView storage namespace (cookie partition) for this account.
class ClaudeAccount {
  const ClaudeAccount({
    required this.id,
    required this.apiAccountId,
    required this.label,
    this.providerType = AccountProviderType.claude,
    this.lastKnownUsage,
    this.lastFetchedAt,
    this.isLoggedIn = false,
    this.showInFocusMode = true,
    this.sortOrder = 0,
    this.lastFetchError,
    this.lastFetchSessionExpired = false,
  });

  final String id;

  /// Public local-API identifier. Separate from [id], which is the WebView
  /// profile/cookie namespace and must never change during migration.
  final String apiAccountId;
  final String label;
  final AccountProviderType providerType;

  /// Last *successful* usage snapshot -- never overwritten by a failed fetch.
  /// Use [lastFetchError] / [lastFetchSessionExpired] to know if the most
  /// recent attempt failed.
  final UsageSnapshot? lastKnownUsage;
  final DateTime? lastFetchedAt;
  final bool isLoggedIn;

  /// Whether this account appears in the full-screen focus view -- lets an
  /// account be tracked/refreshed normally without cluttering that
  /// distraction-free view.
  final bool showInFocusMode;

  /// Display order everywhere accounts are listed (dashboard, focus mode,
  /// settings) -- lower first. User-reorderable via drag in Settings; see
  /// AccountProvider.reorderAccounts.
  final int sortOrder;

  /// Non-null when the last fetch failed with a non-auth error. Cleared on
  /// the next successful fetch. [lastKnownUsage] still holds the last good
  /// data so the UI can show cached percentages alongside this error.
  final String? lastFetchError;

  /// True when the last fetch failed because the session expired (401/403).
  /// Cleared on the next successful fetch.
  final bool lastFetchSessionExpired;

  ClaudeAccount copyWith({
    String? apiAccountId,
    String? label,
    AccountProviderType? providerType,
    UsageSnapshot? lastKnownUsage,
    DateTime? lastFetchedAt,
    bool? isLoggedIn,
    bool? showInFocusMode,
    int? sortOrder,
    String? lastFetchError,
    bool clearLastFetchError = false,
    bool? lastFetchSessionExpired,
  }) {
    return ClaudeAccount(
      id: id,
      apiAccountId: apiAccountId ?? this.apiAccountId,
      label: label ?? this.label,
      providerType: providerType ?? this.providerType,
      lastKnownUsage: lastKnownUsage ?? this.lastKnownUsage,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      showInFocusMode: showInFocusMode ?? this.showInFocusMode,
      sortOrder: sortOrder ?? this.sortOrder,
      lastFetchError: clearLastFetchError
          ? null
          : (lastFetchError ?? this.lastFetchError),
      lastFetchSessionExpired:
          lastFetchSessionExpired ?? this.lastFetchSessionExpired,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'apiAccountId': apiAccountId,
    'label': label,
    'providerType': providerType.name,
    'lastKnownUsage': lastKnownUsage?.toJson(),
    'lastFetchedAt': lastFetchedAt?.toIso8601String(),
    'isLoggedIn': isLoggedIn,
    'showInFocusMode': showInFocusMode,
    'sortOrder': sortOrder,
    'lastFetchError': lastFetchError,
    'lastFetchSessionExpired': lastFetchSessionExpired,
  };

  factory ClaudeAccount.fromJson(Map<String, dynamic> json) {
    return ClaudeAccount(
      id: json['id'] as String,
      apiAccountId: (json['apiAccountId'] as String?)?.trim().isNotEmpty == true
          ? json['apiAccountId'] as String
          : generateApiAccountId(),
      label: json['label'] as String,
      providerType: AccountProviderType.fromString(
        json['providerType'] as String?,
      ),
      lastKnownUsage: json['lastKnownUsage'] != null
          ? UsageSnapshot.fromJson(
              Map<String, dynamic>.from(json['lastKnownUsage'] as Map),
            )
          : null,
      lastFetchedAt: json['lastFetchedAt'] != null
          ? DateTime.parse(json['lastFetchedAt'] as String)
          : null,
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      showInFocusMode: json['showInFocusMode'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      lastFetchError: json['lastFetchError'] as String?,
      lastFetchSessionExpired:
          json['lastFetchSessionExpired'] as bool? ?? false,
    );
  }
}
