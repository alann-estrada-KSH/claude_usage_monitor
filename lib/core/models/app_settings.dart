import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.refreshIntervalSeconds = 90,
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.use24HourFormat = false,
    this.accentColor = defaultAccentColor,
    this.fontChoice = defaultFontChoice,
    this.showUsageGraphs = true,
    this.statusRefreshIntervalSeconds = 3600,
    this.debugMode = false,
    this.warningThresholdPercent = 80,
    this.criticalThresholdPercent = 95,
    this.keepSessionAliveEnabled = false,
    this.keepSessionAliveIntervalMinutes = 60,
    this.floatingWindowEnabled = false,
    this.floatingWindowOpacity = 1.0,
    this.floatingModeEnabled = false,
    this.floatingAllAccounts = true,
    this.floatingAccountIds = const [],
    this.localApiEnabled = false,
    this.localApiPort = 47865,
    this.localApiRateLimitPerMinute = 60,
    this.pinnedNotificationAllAccounts = true,
    this.pinnedNotificationAccountIds = const [],
    this.pinnedNotificationEnabled = true,
    this.pinnedNotificationShowProvider = true,
    this.pinnedNotificationShowFiveHour = true,
    this.pinnedNotificationShowWeekly = true,
    this.pinnedNotificationCompact = false,
    this.pinnedNotificationPrivacyMode = 'full',
    this.widgetAllAccounts = true,
    this.widgetAccountIds = const [],
  });

  final int refreshIntervalSeconds;
  final ThemeMode themeMode;

  /// `null` means "follow the OS locale". Otherwise an ISO code ('en', 'es').
  final String? languageCode;

  final bool use24HourFormat;

  /// ARGB int rather than a [Color] -- keeps this model free of any
  /// Flutter-version-specific Color API and trivial to store as-is.
  final int accentColor;

  /// One of [fontChoices].
  final String fontChoice;
  final bool showUsageGraphs;

  final int statusRefreshIntervalSeconds;

  /// Shows the notification-log/test-notification panel in Settings.
  final bool debugMode;

  /// Usage bars/cards turn "warning" color at or above this percent.
  final int warningThresholdPercent;

  /// Usage bars/cards turn "critical" color at or above this percent.
  final int criticalThresholdPercent;

  /// Android-only: periodic background ping (via WorkManager) to keep
  /// Claude's session cookies from expiring due to inactivity. Ignored on
  /// every other platform -- see SessionKeepAlive.
  final bool keepSessionAliveEnabled;
  final int keepSessionAliveIntervalMinutes;

  /// Desktop-only: keep the dashboard above other windows.
  final bool floatingWindowEnabled;
  final double floatingWindowOpacity;

  /// Desktop-only: show the compact usage window.
  final bool floatingModeEnabled;
  final bool floatingAllAccounts;
  final List<String> floatingAccountIds;

  /// Desktop-only localhost API. Disabled by default.
  final bool localApiEnabled;
  final int localApiPort;
  final int localApiRateLimitPerMinute;

  /// Android-only persistent notification selection. `true` preserves the
  /// legacy behavior of showing every account.
  final bool pinnedNotificationAllAccounts;
  final List<String> pinnedNotificationAccountIds;
  final bool pinnedNotificationEnabled;
  final bool pinnedNotificationShowProvider;
  final bool pinnedNotificationShowFiveHour;
  final bool pinnedNotificationShowWeekly;
  final bool pinnedNotificationCompact;

  /// One of [notificationPrivacyModes].
  final String pinnedNotificationPrivacyMode;

  /// Android-only widget selection. `true` preserves showing every account.
  final bool widgetAllAccounts;
  final List<String> widgetAccountIds;

  static const minRefreshIntervalSeconds = 30;
  static const maxRefreshIntervalSeconds = 600;

  static const minStatusRefreshIntervalSeconds = 300;
  static const maxStatusRefreshIntervalSeconds = 21600;
  static const minLocalApiPort = 1024;
  static const maxLocalApiPort = 65535;
  static const minLocalApiRateLimitPerMinute = 1;
  static const maxLocalApiRateLimitPerMinute = 600;
  static const minFloatingWindowOpacity = 0.45;
  static const maxFloatingWindowOpacity = 1.0;
  static const notificationPrivacyModes = ['full', 'hideAccounts', 'hidden'];

  /// Claude's own brand orange -- matches claude.ai's real accent color.
  static const defaultAccentColor = 0xFFD97757;

  static const defaultFontChoice = 'monospace';
  static const fontChoices = [
    'monospace',
    'comicSans',
    'consolas',
    'courierNew',
    'georgia',
  ];

  AppSettings copyWith({
    int? refreshIntervalSeconds,
    ThemeMode? themeMode,
    String? languageCode,
    bool clearLanguageCode = false,
    bool? use24HourFormat,
    int? accentColor,
    String? fontChoice,
    bool? showUsageGraphs,
    int? statusRefreshIntervalSeconds,
    bool? debugMode,
    int? warningThresholdPercent,
    int? criticalThresholdPercent,
    bool? keepSessionAliveEnabled,
    int? keepSessionAliveIntervalMinutes,
    bool? floatingWindowEnabled,
    double? floatingWindowOpacity,
    bool? floatingModeEnabled,
    bool? floatingAllAccounts,
    List<String>? floatingAccountIds,
    bool? localApiEnabled,
    int? localApiPort,
    int? localApiRateLimitPerMinute,
    bool? pinnedNotificationAllAccounts,
    List<String>? pinnedNotificationAccountIds,
    bool? pinnedNotificationEnabled,
    bool? pinnedNotificationShowProvider,
    bool? pinnedNotificationShowFiveHour,
    bool? pinnedNotificationShowWeekly,
    bool? pinnedNotificationCompact,
    String? pinnedNotificationPrivacyMode,
    bool? widgetAllAccounts,
    List<String>? widgetAccountIds,
  }) {
    return AppSettings(
      refreshIntervalSeconds:
          refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      themeMode: themeMode ?? this.themeMode,
      languageCode: clearLanguageCode
          ? null
          : (languageCode ?? this.languageCode),
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      accentColor: accentColor ?? this.accentColor,
      fontChoice: fontChoice ?? this.fontChoice,
      showUsageGraphs: showUsageGraphs ?? this.showUsageGraphs,
      statusRefreshIntervalSeconds:
          statusRefreshIntervalSeconds ?? this.statusRefreshIntervalSeconds,
      debugMode: debugMode ?? this.debugMode,
      warningThresholdPercent:
          warningThresholdPercent ?? this.warningThresholdPercent,
      criticalThresholdPercent:
          criticalThresholdPercent ?? this.criticalThresholdPercent,
      keepSessionAliveEnabled:
          keepSessionAliveEnabled ?? this.keepSessionAliveEnabled,
      keepSessionAliveIntervalMinutes:
          keepSessionAliveIntervalMinutes ??
          this.keepSessionAliveIntervalMinutes,
      floatingWindowEnabled:
          floatingWindowEnabled ?? this.floatingWindowEnabled,
      floatingWindowOpacity:
          floatingWindowOpacity ?? this.floatingWindowOpacity,
      floatingModeEnabled: floatingModeEnabled ?? this.floatingModeEnabled,
      floatingAllAccounts: floatingAllAccounts ?? this.floatingAllAccounts,
      floatingAccountIds: floatingAccountIds ?? this.floatingAccountIds,
      localApiEnabled: localApiEnabled ?? this.localApiEnabled,
      localApiPort: localApiPort ?? this.localApiPort,
      localApiRateLimitPerMinute:
          localApiRateLimitPerMinute ?? this.localApiRateLimitPerMinute,
      pinnedNotificationAllAccounts:
          pinnedNotificationAllAccounts ?? this.pinnedNotificationAllAccounts,
      pinnedNotificationAccountIds:
          pinnedNotificationAccountIds ?? this.pinnedNotificationAccountIds,
      pinnedNotificationEnabled:
          pinnedNotificationEnabled ?? this.pinnedNotificationEnabled,
      pinnedNotificationShowProvider:
          pinnedNotificationShowProvider ?? this.pinnedNotificationShowProvider,
      pinnedNotificationShowFiveHour:
          pinnedNotificationShowFiveHour ?? this.pinnedNotificationShowFiveHour,
      pinnedNotificationShowWeekly:
          pinnedNotificationShowWeekly ?? this.pinnedNotificationShowWeekly,
      pinnedNotificationCompact:
          pinnedNotificationCompact ?? this.pinnedNotificationCompact,
      pinnedNotificationPrivacyMode:
          pinnedNotificationPrivacyMode ?? this.pinnedNotificationPrivacyMode,
      widgetAllAccounts: widgetAllAccounts ?? this.widgetAllAccounts,
      widgetAccountIds: widgetAccountIds ?? this.widgetAccountIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'refreshIntervalSeconds': refreshIntervalSeconds,
    'themeMode': themeMode.name,
    'languageCode': languageCode,
    'use24HourFormat': use24HourFormat,
    'accentColor': accentColor,
    'fontChoice': fontChoice,
    'showUsageGraphs': showUsageGraphs,
    'statusRefreshIntervalSeconds': statusRefreshIntervalSeconds,
    'debugMode': debugMode,
    'warningThresholdPercent': warningThresholdPercent,
    'criticalThresholdPercent': criticalThresholdPercent,
    'keepSessionAliveEnabled': keepSessionAliveEnabled,
    'keepSessionAliveIntervalMinutes': keepSessionAliveIntervalMinutes,
    'floatingWindowEnabled': floatingWindowEnabled,
    'floatingWindowOpacity': floatingWindowOpacity,
    'floatingModeEnabled': floatingModeEnabled,
    'floatingAllAccounts': floatingAllAccounts,
    'floatingAccountIds': floatingAccountIds,
    'localApiEnabled': localApiEnabled,
    'localApiPort': localApiPort,
    'localApiRateLimitPerMinute': localApiRateLimitPerMinute,
    'pinnedNotificationAllAccounts': pinnedNotificationAllAccounts,
    'pinnedNotificationAccountIds': pinnedNotificationAccountIds,
    'pinnedNotificationEnabled': pinnedNotificationEnabled,
    'pinnedNotificationShowProvider': pinnedNotificationShowProvider,
    'pinnedNotificationShowFiveHour': pinnedNotificationShowFiveHour,
    'pinnedNotificationShowWeekly': pinnedNotificationShowWeekly,
    'pinnedNotificationCompact': pinnedNotificationCompact,
    'pinnedNotificationPrivacyMode': pinnedNotificationPrivacyMode,
    'widgetAllAccounts': widgetAllAccounts,
    'widgetAccountIds': widgetAccountIds,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      refreshIntervalSeconds: json['refreshIntervalSeconds'] as int? ?? 90,
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      languageCode: json['languageCode'] as String?,
      use24HourFormat: json['use24HourFormat'] as bool? ?? false,
      accentColor: json['accentColor'] as int? ?? defaultAccentColor,
      fontChoice: json['fontChoice'] as String? ?? defaultFontChoice,
      showUsageGraphs: json['showUsageGraphs'] as bool? ?? true,
      statusRefreshIntervalSeconds:
          json['statusRefreshIntervalSeconds'] as int? ?? 3600,
      debugMode: json['debugMode'] as bool? ?? false,
      warningThresholdPercent: json['warningThresholdPercent'] as int? ?? 80,
      criticalThresholdPercent: json['criticalThresholdPercent'] as int? ?? 95,
      keepSessionAliveEnabled:
          json['keepSessionAliveEnabled'] as bool? ?? false,
      keepSessionAliveIntervalMinutes:
          json['keepSessionAliveIntervalMinutes'] as int? ?? 60,
      floatingWindowEnabled: json['floatingWindowEnabled'] as bool? ?? false,
      floatingWindowOpacity: _boundedDouble(
        json['floatingWindowOpacity'],
        1.0,
        minFloatingWindowOpacity,
        maxFloatingWindowOpacity,
      ),
      floatingModeEnabled: json['floatingModeEnabled'] as bool? ?? false,
      floatingAllAccounts: json['floatingAllAccounts'] as bool? ?? true,
      floatingAccountIds: _stringList(json['floatingAccountIds']),
      localApiEnabled: json['localApiEnabled'] as bool? ?? false,
      localApiPort: _boundedInt(
        json['localApiPort'],
        47865,
        minLocalApiPort,
        maxLocalApiPort,
      ),
      localApiRateLimitPerMinute: _boundedInt(
        json['localApiRateLimitPerMinute'],
        60,
        minLocalApiRateLimitPerMinute,
        maxLocalApiRateLimitPerMinute,
      ),
      pinnedNotificationAllAccounts:
          json['pinnedNotificationAllAccounts'] as bool? ?? true,
      pinnedNotificationAccountIds: _stringList(
        json['pinnedNotificationAccountIds'],
      ),
      pinnedNotificationEnabled:
          json['pinnedNotificationEnabled'] as bool? ?? true,
      pinnedNotificationShowProvider:
          json['pinnedNotificationShowProvider'] as bool? ?? true,
      pinnedNotificationShowFiveHour:
          json['pinnedNotificationShowFiveHour'] as bool? ?? true,
      pinnedNotificationShowWeekly:
          json['pinnedNotificationShowWeekly'] as bool? ?? true,
      pinnedNotificationCompact:
          json['pinnedNotificationCompact'] as bool? ?? false,
      pinnedNotificationPrivacyMode: _privacyMode(
        json['pinnedNotificationPrivacyMode'],
      ),
      widgetAllAccounts: json['widgetAllAccounts'] as bool? ?? true,
      widgetAccountIds: _stringList(json['widgetAccountIds']),
    );
  }
}

String _privacyMode(Object? value) {
  return AppSettings.notificationPrivacyModes.contains(value)
      ? value as String
      : 'full';
}

int _boundedInt(Object? value, int fallback, int min, int max) {
  final number = value is num ? value.toInt() : fallback;
  return number.clamp(min, max);
}

double _boundedDouble(Object? value, double fallback, double min, double max) {
  final number = value is num ? value.toDouble() : fallback;
  return number.clamp(min, max).toDouble();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
