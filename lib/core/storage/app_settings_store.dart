import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';

class AppSettingsStore {
  static const _boxName = 'settings';
  static const _key = 'app_settings';

  Box<Map>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  Box<Map> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('AppSettingsStore.init() must be called before use');
    }
    return box;
  }

  AppSettings load() {
    final raw = _requireBox.get(_key);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> save(AppSettings settings) async {
    await _requireBox.put(_key, settings.toJson());
  }
}
