/// A single reading of Claude's two usage windows, scraped from
/// claude.ai/settings/usage. Percentages are 0-100, null when unknown.
class UsageSnapshot {
  const UsageSnapshot({
    required this.fetchedAt,
    this.fiveHourPercent,
    this.fiveHourResetAt,
    this.weeklyPercent,
    this.weeklyResetAt,
    this.claudeGptFiveHourPercent,
    this.claudeGptFiveHourResetAt,
    this.claudeGptWeeklyPercent,
    this.claudeGptWeeklyResetAt,
    this.isAvailable = true,
    this.parseError,
    this.rawPageText,
    this.sessionExpired = false,
  });

  final DateTime fetchedAt;
  final double? fiveHourPercent;
  final DateTime? fiveHourResetAt;
  final double? weeklyPercent;
  final DateTime? weeklyResetAt;

  final double? claudeGptFiveHourPercent;
  final DateTime? claudeGptFiveHourResetAt;
  final double? claudeGptWeeklyPercent;
  final DateTime? claudeGptWeeklyResetAt;

  /// False when the scrape ran but the page structure could not be parsed.
  final bool isAvailable;
  final String? parseError;

  /// True when the API rejected the request as unauthenticated (401/403) --
  /// distinct from other failures because the fix is "log back in", not
  /// "wait and retry".
  final bool sessionExpired;

  /// The scraped page text, kept around purely so Settings > Diagnostics can
  /// show/copy it for tuning the parser's selectors when Anthropic changes
  /// the page. Deliberately excluded from toJson/fromJson -- never persisted
  /// to disk, in-memory for the current session only.
  final String? rawPageText;

  factory UsageSnapshot.unavailable(
    String reason, {
    DateTime? fetchedAt,
    String? rawPageText,
    bool sessionExpired = false,
  }) {
    return UsageSnapshot(
      fetchedAt: fetchedAt ?? DateTime.now(),
      isAvailable: false,
      parseError: reason,
      rawPageText: rawPageText,
      sessionExpired: sessionExpired,
    );
  }

  UsageSnapshot copyWith({
    DateTime? fetchedAt,
    double? fiveHourPercent,
    DateTime? fiveHourResetAt,
    double? weeklyPercent,
    DateTime? weeklyResetAt,
    double? claudeGptFiveHourPercent,
    DateTime? claudeGptFiveHourResetAt,
    double? claudeGptWeeklyPercent,
    DateTime? claudeGptWeeklyResetAt,
    bool? isAvailable,
    String? parseError,
    bool? sessionExpired,
  }) {
    return UsageSnapshot(
      fetchedAt: fetchedAt ?? this.fetchedAt,
      fiveHourPercent: fiveHourPercent ?? this.fiveHourPercent,
      fiveHourResetAt: fiveHourResetAt ?? this.fiveHourResetAt,
      weeklyPercent: weeklyPercent ?? this.weeklyPercent,
      weeklyResetAt: weeklyResetAt ?? this.weeklyResetAt,
      claudeGptFiveHourPercent: claudeGptFiveHourPercent ?? this.claudeGptFiveHourPercent,
      claudeGptFiveHourResetAt: claudeGptFiveHourResetAt ?? this.claudeGptFiveHourResetAt,
      claudeGptWeeklyPercent: claudeGptWeeklyPercent ?? this.claudeGptWeeklyPercent,
      claudeGptWeeklyResetAt: claudeGptWeeklyResetAt ?? this.claudeGptWeeklyResetAt,
      isAvailable: isAvailable ?? this.isAvailable,
      parseError: parseError ?? this.parseError,
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'fiveHourPercent': fiveHourPercent,
        'fiveHourResetAt': fiveHourResetAt?.toIso8601String(),
        'weeklyPercent': weeklyPercent,
        'weeklyResetAt': weeklyResetAt?.toIso8601String(),
        'claudeGptFiveHourPercent': claudeGptFiveHourPercent,
        'claudeGptFiveHourResetAt': claudeGptFiveHourResetAt?.toIso8601String(),
        'claudeGptWeeklyPercent': claudeGptWeeklyPercent,
        'claudeGptWeeklyResetAt': claudeGptWeeklyResetAt?.toIso8601String(),
        'isAvailable': isAvailable,
        'parseError': parseError,
        'sessionExpired': sessionExpired,
      };

  factory UsageSnapshot.fromJson(Map<String, dynamic> json) {
    return UsageSnapshot(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      fiveHourPercent: (json['fiveHourPercent'] as num?)?.toDouble(),
      fiveHourResetAt: json['fiveHourResetAt'] != null
          ? DateTime.parse(json['fiveHourResetAt'] as String)
          : null,
      weeklyPercent: (json['weeklyPercent'] as num?)?.toDouble(),
      weeklyResetAt: json['weeklyResetAt'] != null
          ? DateTime.parse(json['weeklyResetAt'] as String)
          : null,
      claudeGptFiveHourPercent: (json['claudeGptFiveHourPercent'] as num?)?.toDouble(),
      claudeGptFiveHourResetAt: json['claudeGptFiveHourResetAt'] != null
          ? DateTime.parse(json['claudeGptFiveHourResetAt'] as String)
          : null,
      claudeGptWeeklyPercent: (json['claudeGptWeeklyPercent'] as num?)?.toDouble(),
      claudeGptWeeklyResetAt: json['claudeGptWeeklyResetAt'] != null
          ? DateTime.parse(json['claudeGptWeeklyResetAt'] as String)
          : null,
      isAvailable: json['isAvailable'] as bool? ?? true,
      parseError: json['parseError'] as String?,
      sessionExpired: json['sessionExpired'] as bool? ?? false,
    );
  }
}
