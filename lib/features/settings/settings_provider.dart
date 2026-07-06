import 'package:flutter/material.dart';

import '../../core/background/session_keepalive.dart';
import '../../core/models/app_settings.dart';
import '../../core/storage/app_settings_store.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({AppSettingsStore? store}) : _store = store ?? AppSettingsStore();

  final AppSettingsStore _store;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  int get refreshIntervalSeconds => _settings.refreshIntervalSeconds;
  ThemeMode get themeMode => _settings.themeMode;
  String? get languageCode => _settings.languageCode;
  bool get use24HourFormat => _settings.use24HourFormat;
  int get accentColor => _settings.accentColor;
  String get fontChoice => _settings.fontChoice;
  int get statusRefreshIntervalSeconds => _settings.statusRefreshIntervalSeconds;
  bool get debugMode => _settings.debugMode;
  int get warningThresholdPercent => _settings.warningThresholdPercent;
  int get criticalThresholdPercent => _settings.criticalThresholdPercent;
  bool get keepSessionAliveEnabled => _settings.keepSessionAliveEnabled;
  int get keepSessionAliveIntervalMinutes => _settings.keepSessionAliveIntervalMinutes;

  Future<void> init() async {
    await _store.init();
    _settings = _store.load();
    notifyListeners();
    // WorkManager registrations persist at the OS level across app
    // restarts, but re-asserting on every launch (idempotent thanks to
    // ExistingPeriodicWorkPolicy.update) is what picks up a frequency the
    // user changed while the app was closed, and covers the very first
    // launch after enabling it.
    if (_settings.keepSessionAliveEnabled) {
      await SessionKeepAlive.register(Duration(minutes: _settings.keepSessionAliveIntervalMinutes));
    }
  }

  Future<void> setRefreshInterval(int seconds) async {
    final clamped = seconds.clamp(
      AppSettings.minRefreshIntervalSeconds,
      AppSettings.maxRefreshIntervalSeconds,
    );
    _settings = _settings.copyWith(refreshIntervalSeconds: clamped);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _store.save(_settings);
    notifyListeners();
  }

  /// Pass `null` to follow the OS locale again.
  Future<void> setLanguageCode(String? code) async {
    _settings = _settings.copyWith(languageCode: code, clearLanguageCode: code == null);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setUse24HourFormat(bool value) async {
    _settings = _settings.copyWith(use24HourFormat: value);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setAccentColor(int argb) async {
    _settings = _settings.copyWith(accentColor: argb);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setFontChoice(String choice) async {
    _settings = _settings.copyWith(fontChoice: choice);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setStatusRefreshInterval(int seconds) async {
    final clamped = seconds.clamp(
      AppSettings.minStatusRefreshIntervalSeconds,
      AppSettings.maxStatusRefreshIntervalSeconds,
    );
    _settings = _settings.copyWith(statusRefreshIntervalSeconds: clamped);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setDebugMode(bool value) async {
    _settings = _settings.copyWith(debugMode: value);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setWarningThreshold(int percent) async {
    final clamped = percent.clamp(1, criticalThresholdPercent - 1);
    _settings = _settings.copyWith(warningThresholdPercent: clamped);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setCriticalThreshold(int percent) async {
    final clamped = percent.clamp(warningThresholdPercent + 1, 100);
    _settings = _settings.copyWith(criticalThresholdPercent: clamped);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setKeepSessionAliveEnabled(bool value) async {
    _settings = _settings.copyWith(keepSessionAliveEnabled: value);
    await _store.save(_settings);
    if (value) {
      await SessionKeepAlive.register(Duration(minutes: keepSessionAliveIntervalMinutes));
    } else {
      await SessionKeepAlive.cancel();
    }
    notifyListeners();
  }

  Future<void> setKeepSessionAliveInterval(int minutes) async {
    final clamped = minutes.clamp(
      SessionKeepAlive.minIntervalMinutes,
      SessionKeepAlive.maxIntervalMinutes,
    );
    _settings = _settings.copyWith(keepSessionAliveIntervalMinutes: clamped);
    await _store.save(_settings);
    if (keepSessionAliveEnabled) {
      await SessionKeepAlive.register(Duration(minutes: clamped));
    }
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _settings = const AppSettings();
    await _store.save(_settings);
    await SessionKeepAlive.cancel();
    notifyListeners();
  }
}
