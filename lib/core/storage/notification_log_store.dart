import 'package:hive_flutter/hive_flutter.dart';

/// Tracks which (account, window, event, reset-timestamp) alerts have
/// already fired, so a "limit reached"/"limit reset" notification goes out
/// exactly once per cycle instead of on every refresh or app relaunch while
/// the condition still holds.
class NotificationLogStore {
  static const _boxName = 'notification_log';

  Box<bool>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<bool>(_boxName);
  }

  Box<bool> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('NotificationLogStore.init() must be called before use');
    }
    return box;
  }

  bool hasFired(String key) => _requireBox.get(key) ?? false;

  Future<void> markFired(String key) => _requireBox.put(key, true);

  /// Un-marks a key -- used to re-arm the "exhausted" alert once a window's
  /// usage drops back under 100%, so the *next* time it hits 100% notifies
  /// again instead of staying silent forever after the first time.
  Future<void> clear(String key) => _requireBox.delete(key);

  /// For the debug panel: every key currently marked as fired.
  List<String> firedKeys() => _requireBox.keys.cast<String>().toList()..sort();
}
