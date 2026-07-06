import 'package:hive_flutter/hive_flutter.dart';

import '../models/usage_history_point.dart';

/// Keeps a bounded recent history of usage readings per account, purely so
/// the dashboard can draw a sparkline -- not a long-term analytics log.
/// Trimmed both by age and by count so it can't grow unbounded even at a
/// very short refresh interval.
class UsageHistoryStore {
  static const _boxName = 'usage_history';
  static const _window = Duration(hours: 48);
  static const _maxPoints = 500;

  Box<List>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<List>(_boxName);
  }

  Box<List> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('UsageHistoryStore.init() must be called before use');
    }
    return box;
  }

  List<UsageHistoryPoint> forAccount(String accountId) {
    final raw = _requireBox.get(accountId) ?? const [];
    return raw
        .map((e) => UsageHistoryPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> append(String accountId, UsageHistoryPoint point) async {
    final cutoff = DateTime.now().subtract(_window);
    final kept = forAccount(accountId).where((p) => p.timestamp.isAfter(cutoff)).toList()
      ..add(point);
    final trimmed = kept.length > _maxPoints ? kept.sublist(kept.length - _maxPoints) : kept;
    await _requireBox.put(accountId, trimmed.map((p) => p.toJson()).toList());
  }
}
