/// One recorded reading for a sparkline -- just enough to redraw a trend
/// line, deliberately not the full [UsageSnapshot] (no reset times, no raw
/// API text) since history entries are kept far longer.
class UsageHistoryPoint {
  const UsageHistoryPoint({
    required this.timestamp,
    this.fiveHourPercent,
    this.weeklyPercent,
  });

  final DateTime timestamp;
  final double? fiveHourPercent;
  final double? weeklyPercent;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'fiveHourPercent': fiveHourPercent,
        'weeklyPercent': weeklyPercent,
      };

  factory UsageHistoryPoint.fromJson(Map<String, dynamic> json) => UsageHistoryPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        fiveHourPercent: (json['fiveHourPercent'] as num?)?.toDouble(),
        weeklyPercent: (json['weeklyPercent'] as num?)?.toDouble(),
      );
}
