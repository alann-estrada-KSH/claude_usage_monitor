import 'package:hive_flutter/hive_flutter.dart';

import '../models/claude_account.dart';

/// Persists account metadata (id, label, last known usage) to a local Hive
/// box. Never stores cookies or session tokens — those live only in the
/// platform WebView's own cookie store.
class AccountStore {
  static const _boxName = 'accounts';

  Box<Map>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  Box<Map> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('AccountStore.init() must be called before use');
    }
    return box;
  }

  List<ClaudeAccount> getAll() {
    return _requireBox.values
        .map((raw) => ClaudeAccount.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<void> save(ClaudeAccount account) async {
    await _requireBox.put(account.id, account.toJson());
  }

  Future<void> delete(String accountId) async {
    await _requireBox.delete(accountId);
  }
}
