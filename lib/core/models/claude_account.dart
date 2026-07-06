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
  });

  final String id;
  final String label;
  final UsageSnapshot? lastKnownUsage;
  final DateTime? lastFetchedAt;
  final bool isLoggedIn;

  /// Whether this account appears in the full-screen focus view -- lets an
  /// account be tracked/refreshed normally without cluttering that
  /// distraction-free view.
  final bool showInFocusMode;

  ClaudeAccount copyWith({
    String? label,
    UsageSnapshot? lastKnownUsage,
    DateTime? lastFetchedAt,
    bool? isLoggedIn,
    bool? showInFocusMode,
  }) {
    return ClaudeAccount(
      id: id,
      label: label ?? this.label,
      lastKnownUsage: lastKnownUsage ?? this.lastKnownUsage,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      showInFocusMode: showInFocusMode ?? this.showInFocusMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lastKnownUsage': lastKnownUsage?.toJson(),
        'lastFetchedAt': lastFetchedAt?.toIso8601String(),
        'isLoggedIn': isLoggedIn,
        'showInFocusMode': showInFocusMode,
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
    );
  }
}
