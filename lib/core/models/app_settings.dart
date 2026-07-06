import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.refreshIntervalSeconds = 90,
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.use24HourFormat = false,
    this.accentColor = defaultAccentColor,
    this.fontChoice = defaultFontChoice,
    this.statusRefreshIntervalSeconds = 3600,
    this.debugMode = false,
    this.warningThresholdPercent = 80,
    this.criticalThresholdPercent = 95,
    this.keepSessionAliveEnabled = false,
    this.keepSessionAliveIntervalMinutes = 60,
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

  static const minRefreshIntervalSeconds = 30;
  static const maxRefreshIntervalSeconds = 600;

  static const minStatusRefreshIntervalSeconds = 300;
  static const maxStatusRefreshIntervalSeconds = 21600;

  /// Claude's own brand orange -- matches claude.ai's real accent color.
  static const defaultAccentColor = 0xFFD97757;

  static const defaultFontChoice = 'monospace';
  static const fontChoices = ['monospace', 'comicSans', 'consolas', 'courierNew', 'georgia'];

  AppSettings copyWith({
    int? refreshIntervalSeconds,
    ThemeMode? themeMode,
    String? languageCode,
    bool clearLanguageCode = false,
    bool? use24HourFormat,
    int? accentColor,
    String? fontChoice,
    int? statusRefreshIntervalSeconds,
    bool? debugMode,
    int? warningThresholdPercent,
    int? criticalThresholdPercent,
    bool? keepSessionAliveEnabled,
    int? keepSessionAliveIntervalMinutes,
  }) {
    return AppSettings(
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      themeMode: themeMode ?? this.themeMode,
      languageCode: clearLanguageCode ? null : (languageCode ?? this.languageCode),
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      accentColor: accentColor ?? this.accentColor,
      fontChoice: fontChoice ?? this.fontChoice,
      statusRefreshIntervalSeconds: statusRefreshIntervalSeconds ?? this.statusRefreshIntervalSeconds,
      debugMode: debugMode ?? this.debugMode,
      warningThresholdPercent: warningThresholdPercent ?? this.warningThresholdPercent,
      criticalThresholdPercent: criticalThresholdPercent ?? this.criticalThresholdPercent,
      keepSessionAliveEnabled: keepSessionAliveEnabled ?? this.keepSessionAliveEnabled,
      keepSessionAliveIntervalMinutes:
          keepSessionAliveIntervalMinutes ?? this.keepSessionAliveIntervalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'refreshIntervalSeconds': refreshIntervalSeconds,
        'themeMode': themeMode.name,
        'languageCode': languageCode,
        'use24HourFormat': use24HourFormat,
        'accentColor': accentColor,
        'fontChoice': fontChoice,
        'statusRefreshIntervalSeconds': statusRefreshIntervalSeconds,
        'debugMode': debugMode,
        'warningThresholdPercent': warningThresholdPercent,
        'criticalThresholdPercent': criticalThresholdPercent,
        'keepSessionAliveEnabled': keepSessionAliveEnabled,
        'keepSessionAliveIntervalMinutes': keepSessionAliveIntervalMinutes,
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
      statusRefreshIntervalSeconds: json['statusRefreshIntervalSeconds'] as int? ?? 3600,
      debugMode: json['debugMode'] as bool? ?? false,
      warningThresholdPercent: json['warningThresholdPercent'] as int? ?? 80,
      criticalThresholdPercent: json['criticalThresholdPercent'] as int? ?? 95,
      keepSessionAliveEnabled: json['keepSessionAliveEnabled'] as bool? ?? false,
      keepSessionAliveIntervalMinutes: json['keepSessionAliveIntervalMinutes'] as int? ?? 60,
    );
  }
}
