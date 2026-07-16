// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Claude Usage Monitor';

  @override
  String get dashboardTitle => 'Usage Monitor';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get focusModeTooltip => 'Focus mode (full screen)';

  @override
  String trayTooltipLine(String label, String five, String weekly) {
    return '$label · Session $five% / Weekly $weekly%';
  }

  @override
  String get trayShowHide => 'Show/Hide';

  @override
  String get trayRefreshNow => 'Refresh now';

  @override
  String get trayQuit => 'Quit';

  @override
  String get addAccountTooltip => 'Add account';

  @override
  String get emptyStateTitle => 'No accounts yet';

  @override
  String get emptyStateBody =>
      'Add a Claude.ai account to start tracking its 5-hour and weekly usage limits.';

  @override
  String get addAccountButton => 'Add account';

  @override
  String get nameAccountDialogTitle => 'Name this account';

  @override
  String get nameAccountHint => 'e.g. Work, Personal';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueToLogin => 'Continue to login';

  @override
  String get refreshNowTooltip => 'Refresh now';

  @override
  String get removeAccountTooltip => 'Remove account';

  @override
  String get renameAccountTooltip => 'Rename account';

  @override
  String get renameAccountDialogTitle => 'Rename this account';

  @override
  String get save => 'Save';

  @override
  String get startCounting => 'Write a message to start counting';

  @override
  String get cachedDataWarning =>
      'Showing cached data — the last refresh failed.';

  @override
  String get noUsageDataYet => 'No usage data yet.';

  @override
  String usageDataUnavailable(String reason) {
    return 'Usage data not available ($reason)';
  }

  @override
  String get unknownReason => 'unknown reason';

  @override
  String get sessionExpiredMessage => 'Session expired.';

  @override
  String get reconnectButton => 'Reconnect';

  @override
  String get fiveHourWindow => 'Session (5 hrs)';

  @override
  String get weeklyWindow => 'Weekly limit (7 days)';

  @override
  String updatedAgo(String time) {
    return 'Updated $time';
  }

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String resetsApprox(String time) {
    return 'Resets ~$time';
  }

  @override
  String get resetNow => 'now';

  @override
  String resetInHoursMinutes(int hours, int minutes) {
    return 'in ${hours}h ${minutes}m';
  }

  @override
  String resetInMinutes(int minutes) {
    return 'in ${minutes}m';
  }

  @override
  String resetInDays(int days) {
    return 'in ${days}d';
  }

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get removeAccountDialogTitle => 'Remove account?';

  @override
  String removeAccountDialogBody(String label) {
    return 'This removes \"$label\" from the dashboard. It does not log you out of claude.ai.';
  }

  @override
  String get remove => 'Remove';

  @override
  String get loginPageTitle => 'Sign in to Claude.ai';

  @override
  String get loginDone => 'Done';

  @override
  String get loginBanner =>
      'Log in below, then tap \"Done\" once you land on your Claude chat screen. Nothing you type here leaves this device.';

  @override
  String get loginDesktopHint =>
      'A separate login window has opened. Log in there, then come back here and tap \"Done\".';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get offlineMessage =>
      'No internet connection -- refreshes paused until it\'s back.';

  @override
  String get statusUnknown =>
      'Claude status unknown (couldn\'t reach status.claude.com)';

  @override
  String get statusChecking => 'Checking Claude status...';

  @override
  String get statusSection => 'Claude status refresh';

  @override
  String get statusPageTitle => 'Claude status';

  @override
  String statusLastChecked(String time) {
    return 'Last checked: $time';
  }

  @override
  String get statusIncidentsTitle => 'Unresolved incidents';

  @override
  String get statusNoIncidents => 'None reported.';

  @override
  String get refreshIntervalSection => 'Refresh interval';

  @override
  String refreshIntervalDescription(int seconds) {
    return 'How often to reload claude.ai/settings/usage in the background. Minimum ${seconds}s to avoid hammering the site.';
  }

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentColorSection => 'Accent color';

  @override
  String get fontSection => 'Font';

  @override
  String get fontMonospace => 'Monospace';

  @override
  String get fontComicSans => 'Comic Sans';

  @override
  String get fontConsolas => 'Consolas';

  @override
  String get fontCourierNew => 'Courier New';

  @override
  String get fontGeorgia => 'Georgia';

  @override
  String get languageSection => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get timeFormatSection => 'Time format';

  @override
  String get timeFormat12h => '12h';

  @override
  String get timeFormat24h => '24h';

  @override
  String get focusModeAccountsSection => 'Accounts shown in focus mode';

  @override
  String get thresholdsSection => 'Usage color thresholds';

  @override
  String thresholdWarning(int percent) {
    return 'Warning at $percent%';
  }

  @override
  String thresholdCritical(int percent) {
    return 'Critical at $percent%';
  }

  @override
  String get diagnosticsSection => 'Diagnostics';

  @override
  String diagnosticsBackend(String backend) {
    return 'WebView backend on this platform: $backend';
  }

  @override
  String get diagnosticsBackendAndroid =>
      'flutter_inappwebview (embedded WebView)';

  @override
  String get diagnosticsBackendDesktop =>
      'desktop_webview_window (webkit2gtk / WebView2)';

  @override
  String get diagnosticsRunning => 'Scraping...';

  @override
  String get diagnosticsRunButton => 'Run scrape now for all accounts';

  @override
  String get diagnosticsNoAccounts => 'No accounts to diagnose yet.';

  @override
  String get diagnosticsNeverScraped => 'Never scraped';

  @override
  String get diagnosticsParsedOk => 'Parsed OK';

  @override
  String get diagnosticsParseFailed => 'Parse failed';

  @override
  String get diagnosticsFetchedAt => 'Fetched at';

  @override
  String get diagnosticsFiveHourPercent => '5-hour %';

  @override
  String get diagnosticsFiveHourReset => '5-hour reset';

  @override
  String get diagnosticsWeeklyPercent => 'Weekly %';

  @override
  String get diagnosticsWeeklyReset => 'Weekly reset';

  @override
  String get diagnosticsParseError => 'Parse error';

  @override
  String get diagnosticsRawPageText => 'Raw API response';

  @override
  String get diagnosticsCopyRawText => 'Copy';

  @override
  String get debugModeSection => 'Debug mode';

  @override
  String get debugModeToggle => 'Show notification log and test tools';

  @override
  String get debugPanelSection => 'Debug';

  @override
  String get debugSendTestNotification => 'Send test notification';

  @override
  String get debugTestNotificationTitle => 'Test notification';

  @override
  String get debugTestNotificationBody =>
      'If you see this, notifications are working.';

  @override
  String get debugSendScheduledTestNotification =>
      'Send scheduled test notification (15s)';

  @override
  String get debugScheduledTestNotificationBody =>
      'If you see this, scheduled notifications work even in the background.';

  @override
  String get debugScheduledTestSent =>
      'Scheduled -- it\'ll arrive in about 15 seconds.';

  @override
  String get keepAliveSection => 'Keep session alive';

  @override
  String get keepAliveDescription =>
      'Pings Claude periodically in the background (via WorkManager, battery-aware) to stop it logging you out from inactivity. 15-minute floor -- that\'s Android\'s own limit.';

  @override
  String get keepAliveToggle => 'Keep session alive in the background';

  @override
  String debugNotificationsEnabled(String status) {
    return 'Android notification permission granted: $status';
  }

  @override
  String get debugYes => 'yes';

  @override
  String get debugNo => 'no';

  @override
  String get debugNotificationLog => 'Notification log (already-fired keys)';

  @override
  String get debugNotificationLogEmpty => 'Nothing logged yet.';

  @override
  String get updatesSection => 'Updates';

  @override
  String updatesCurrentVersion(String version) {
    return 'Current version: v$version';
  }

  @override
  String get updatesCurrentVersionUnknown => 'Current version: unknown';

  @override
  String get updatesCheckButton => 'Check for updates';

  @override
  String get updatesChecking => 'Checking...';

  @override
  String get updatesUpToDate => 'You\'re on the latest version.';

  @override
  String updatesAvailable(String version) {
    return 'Version $version available.';
  }

  @override
  String get updatesDownloadAndInstall => 'Download and install';

  @override
  String get updatesDownloading =>
      'Downloading... the app will close to install.';

  @override
  String get resetSection => 'Reset';

  @override
  String get resetDescription =>
      'Resets all settings (intervals, theme, accent color, font, thresholds, etc.) back to their original values. Doesn\'t touch your accounts or sessions.';

  @override
  String get resetButton => 'Reset settings';

  @override
  String get resetDialogTitle => 'Reset settings?';

  @override
  String get resetDialogBody =>
      'This will restore all preferences to their original values. This can\'t be undone.';

  @override
  String get reset => 'Reset';

  @override
  String get resetDone => 'Settings reset.';

  @override
  String get creditsLine =>
      'Made by Alann Estrada -- github.com/alannnn-estrada';

  @override
  String get aboutFooter =>
      'Unofficial tool, not affiliated with or endorsed by Anthropic. 100% local: no telemetry, no analytics, cookies never leave this device.';

  @override
  String get monthlyWindow => 'Monthly limit (30 days)';

  @override
  String get copilotChatWindow => 'Copilot Chat';

  @override
  String get copilotCompletionsWindow => 'Copilot Completions';

  @override
  String get selectProviderTitle => 'Select provider';
}
