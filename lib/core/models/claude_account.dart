import 'usage_snapshot.dart';

/// A Claude.ai account being monitored. [id] doubles as the isolated
/// WebView storage namespace (cookie partition) for this account.
class ClaudeAccount {
  const ClaudeAccount({
    required this.id,
    required this.label,
    this.lastKnownUsage,
    this.lastFetchedAt,
    this.isLoggedIn = false,
    this.showInFocusMode = true,
    this.sortOrder = 0,
    this.lastFetchError,
    this.lastFetchSessionExpired = false,
  });

  final String id;
  final String label;

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
    String? label,
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
      label: label ?? this.label,
      lastKnownUsage: lastKnownUsage ?? this.lastKnownUsage,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      showInFocusMode: showInFocusMode ?? this.showInFocusMode,
      sortOrder: sortOrder ?? this.sortOrder,
      lastFetchError: clearLastFetchError ? null : (lastFetchError ?? this.lastFetchError),
      lastFetchSessionExpired: lastFetchSessionExpired ?? this.lastFetchSessionExpired,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
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
      label: json['label'] as String,
      lastKnownUsage: json['lastKnownUsage'] != null
          ? UsageSnapshot.fromJson(
              Map<String, dynamic>.from(json['lastKnownUsage'] as Map))
          : null,
      lastFetchedAt: json['lastFetchedAt'] != null
          ? DateTime.parse(json['lastFetchedAt'] as String)
          : null,
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      showInFocusMode: json['showInFocusMode'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      lastFetchError: json['lastFetchError'] as String?,
      lastFetchSessionExpired: json['lastFetchSessionExpired'] as bool? ?? false,
    );
  }
}
