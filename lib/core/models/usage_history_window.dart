import 'usage_history_point.dart';

List<UsageHistoryPoint> filterHistory(
  List<UsageHistoryPoint> points, {
  required int days,
  DateTime? now,
}) {
  final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
  return points.where((point) => !point.timestamp.isBefore(cutoff)).toList();
}
