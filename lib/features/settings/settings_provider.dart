import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/background/session_keepalive.dart';
import '../../core/local_api/local_api_service.dart';
import '../../core/models/app_settings.dart';
import '../../core/storage/app_settings_store.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({AppSettingsStore? store})
    : _store = store ?? AppSettingsStore();

  final AppSettingsStore _store;
  AppSettings _settings = const AppSettings();
  Future<void>? _initialization;

  AppSettings get settings => _settings;
  int get refreshIntervalSeconds => _settings.refreshIntervalSeconds;
  ThemeMode get themeMode => _settings.themeMode;
  String? get languageCode => _settings.languageCode;
  bool get use24HourFormat => _settings.use24HourFormat;
  int get accentColor => _settings.accentColor;
  String get fontChoice => _settings.fontChoice;
  int get statusRefreshIntervalSeconds =>
      _settings.statusRefreshIntervalSeconds;
  bool get debugMode => _settings.debugMode;
  int get warningThresholdPercent => _settings.warningThresholdPercent;
  int get criticalThresholdPercent => _settings.criticalThresholdPercent;
  bool get keepSessionAliveEnabled => _settings.keepSessionAliveEnabled;
  int get keepSessionAliveIntervalMinutes =>
      _settings.keepSessionAliveIntervalMinutes;
  bool get floatingWindowEnabled => _settings.floatingWindowEnabled;
  double get floatingWindowOpacity => _settings.floatingWindowOpacity;
  bool get floatingModeEnabled => _settings.floatingModeEnabled;
  bool get floatingAllAccounts => _settings.floatingAllAccounts;
  List<String> get floatingAccountIds =>
      List.unmodifiable(_settings.floatingAccountIds);
  bool get localApiEnabled => _settings.localApiEnabled;
  int get localApiPort => _settings.localApiPort;
  int get localApiRateLimitPerMinute => _settings.localApiRateLimitPerMinute;
  bool get pinnedNotificationAllAccounts =>
      _settings.pinnedNotificationAllAccounts;
  List<String> get pinnedNotificationAccountIds =>
      List.unmodifiable(_settings.pinnedNotificationAccountIds);
  bool get pinnedNotificationEnabled => _settings.pinnedNotificationEnabled;
  bool get pinnedNotificationShowProvider =>
      _settings.pinnedNotificationShowProvider;
  bool get pinnedNotificationShowFiveHour =>
      _settings.pinnedNotificationShowFiveHour;
  bool get pinnedNotificationShowWeekly =>
      _settings.pinnedNotificationShowWeekly;
  String get pinnedNotificationPrivacyMode =>
      _settings.pinnedNotificationPrivacyMode;
  bool get widgetAllAccounts => _settings.widgetAllAccounts;
  List<String> get widgetAccountIds =>
      List.unmodifiable(_settings.widgetAccountIds);

  Future<void> init() => _initialization ??= _load();

  Future<void> _load() async {
    await _store.init();
    _settings = _store.load();
    notifyListeners();
    // WorkManager registrations persist at the OS level across app
    // restarts, but re-asserting on every launch (idempotent thanks to
    // ExistingPeriodicWorkPolicy.update) is what picks up a frequency the
    // user changed while the app was closed, and covers the very first
    // launch after enabling it.
    if (_settings.keepSessionAliveEnabled) {
      await SessionKeepAlive.register(
        Duration(minutes: _settings.keepSessionAliveIntervalMinutes),
      );
    }
    await _applyFloatingWindow();
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
    _settings = _settings.copyWith(
      languageCode: code,
      clearLanguageCode: code == null,
    );
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

  Future<void> setFloatingWindowEnabled(bool value) async {
    _settings = _settings.copyWith(floatingWindowEnabled: value);
    await _store.save(_settings);
    await _applyFloatingWindow();
    notifyListeners();
  }

  Future<void> setFloatingWindowOpacity(double value) async {
    final clamped = value
        .clamp(
          AppSettings.minFloatingWindowOpacity,
          AppSettings.maxFloatingWindowOpacity,
        )
        .toDouble();
    _settings = _settings.copyWith(floatingWindowOpacity: clamped);
    await _store.save(_settings);
    await _applyFloatingWindow();
    notifyListeners();
  }

  Future<void> setFloatingModeEnabled(bool value) async {
    _settings = _settings.copyWith(floatingModeEnabled: value);
    await _store.save(_settings);
    await _applyFloatingWindow();
    notifyListeners();
  }

  Future<void> setFloatingAccounts({
    required bool allAccounts,
    required List<String> accountIds,
  }) async {
    _settings = _settings.copyWith(
      floatingAllAccounts: allAccounts,
      floatingAccountIds: List.unmodifiable(accountIds),
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setLocalApiEnabled(bool value) async {
    _settings = _settings.copyWith(localApiEnabled: value);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setLocalApiPort(int port) async {
    final clamped = port.clamp(
      AppSettings.minLocalApiPort,
      AppSettings.maxLocalApiPort,
    );
    _settings = _settings.copyWith(localApiPort: clamped);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setLocalApiRateLimitPerMinute(int requests) async {
    final clamped = requests.clamp(
      AppSettings.minLocalApiRateLimitPerMinute,
      AppSettings.maxLocalApiRateLimitPerMinute,
    );
    _settings = _settings.copyWith(localApiRateLimitPerMinute: clamped);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setPinnedNotificationAccounts({
    required bool allAccounts,
    required List<String> accountIds,
  }) async {
    _settings = _settings.copyWith(
      pinnedNotificationAllAccounts: allAccounts,
      pinnedNotificationAccountIds: List.unmodifiable(accountIds),
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setPinnedNotificationDisplay({
    bool? enabled,
    bool? showProvider,
    bool? showFiveHour,
    bool? showWeekly,
    String? privacyMode,
  }) async {
    if (privacyMode != null &&
        !AppSettings.notificationPrivacyModes.contains(privacyMode)) {
      return;
    }
    _settings = _settings.copyWith(
      pinnedNotificationEnabled: enabled,
      pinnedNotificationShowProvider: showProvider,
      pinnedNotificationShowFiveHour: showFiveHour,
      pinnedNotificationShowWeekly: showWeekly,
      pinnedNotificationPrivacyMode: privacyMode,
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> setWidgetAccounts({
    required bool allAccounts,
    required List<String> accountIds,
  }) async {
    _settings = _settings.copyWith(
      widgetAllAccounts: allAccounts,
      widgetAccountIds: List.unmodifiable(accountIds),
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> _applyFloatingWindow() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setAlwaysOnTop(
        _settings.floatingWindowEnabled || _settings.floatingModeEnabled,
      );
      await windowManager.setOpacity(
        _settings.floatingModeEnabled ? _settings.floatingWindowOpacity : 1.0,
      );
    } catch (_) {
      // Desktop window decoration is optional; dashboard remains usable.
    }
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
      await SessionKeepAlive.register(
        Duration(minutes: keepSessionAliveIntervalMinutes),
      );
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
    await LocalApiService.instance.apply();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _settings = const AppSettings();
    await _store.clear();
    await SessionKeepAlive.cancel();
    await LocalApiService.instance.stop();
    LocalApiService.instance.forgetSecret();
    notifyListeners();
  }
}
