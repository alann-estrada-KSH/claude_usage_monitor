import 'package:claude_usage_monitor/core/models/usage_history_point.dart';
import 'package:claude_usage_monitor/core/models/usage_history_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history window keeps only requested period', () {
    final now = DateTime.utc(2026, 8, 30, 12);
    final points = [
      UsageHistoryPoint(timestamp: now.subtract(const Duration(hours: 2))),
      UsageHistoryPoint(timestamp: now.subtract(const Duration(days: 2))),
      UsageHistoryPoint(timestamp: now.subtract(const Duration(days: 10))),
    ];

    expect(filterHistory(points, days: 1, now: now), hasLength(1));
    expect(filterHistory(points, days: 7, now: now), hasLength(2));
    expect(filterHistory(points, days: 30, now: now), hasLength(3));
  });
}
