// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Usage Monitor';

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
  String get floatingWindowSection => 'Floating window';

  @override
  String get floatingWindowToggle => 'Keep dashboard above other windows';

  @override
  String get floatingWindowDescription =>
      'Linux and Windows: keep usage percentages visible while you work.';

  @override
  String get localApiSection => 'Local API';

  @override
  String get localApiToggle => 'Enable local API';

  @override
  String get localApiDescription =>
      'Read-only API on this computer. Disabled by default; it only exposes normalized usage data and never exposes session cookies.';

  @override
  String get localApiPortLabel => 'Preferred port';

  @override
  String get localApiRateLimitLabel => 'Requests per minute';

  @override
  String get localApiSave => 'Save API settings';

  @override
  String localApiRunning(int port) {
    return 'Running at http://127.0.0.1:$port';
  }

  @override
  String get localApiStopped => 'API is stopped';

  @override
  String get localApiDetails => 'Integration details';

  @override
  String get localApiDetailsTitle => 'Local API integration';

  @override
  String get localApiSecretLabel => 'Secret key';

  @override
  String get localApiAuth =>
      'Use the key as: Authorization: Bearer YOUR_SECRET_KEY';

  @override
  String get localApiEndpoints =>
      'GET /v1/health\nGET /v1/accounts\nGET /v1/usage\nGET /v1/accounts/account_id/usage';

  @override
  String get localApiAccountsLabel => 'Account IDs';

  @override
  String get localApiNoAccounts => 'No accounts available.';

  @override
  String get localApiCopy => 'Copy';

  @override
  String get localApiRegenerate => 'Regenerate key';

  @override
  String get localApiRegenerateWarning =>
      'Existing integrations will stop working until they use the new key.';

  @override
  String get localApiStartError =>
      'The local API could not start. Check the port and system credentials.';

  @override
  String get localApiInvalidSettings => 'Enter a valid port and request limit.';

  @override
  String get pinnedNotificationSection => 'Persistent notification';

  @override
  String get pinnedNotificationAllAccounts => 'Show all accounts';

  @override
  String get pinnedNotificationDescription =>
      'Android only. Unselect all accounts to hide this notification.';

  @override
  String get pinnedNotificationAccounts => 'Accounts shown in the notification';

  @override
  String get pinnedNotificationNoAccounts => 'No accounts available.';

  @override
  String get widgetSection => 'Android widgets';

  @override
  String get widgetAllAccounts => 'Show all accounts in widgets';

  @override
  String get widgetDescription =>
      'Choose which accounts appear in Android widgets. Unselect all to hide account data.';

  @override
  String get widgetAccounts => 'Accounts shown in widgets';

  @override
  String get widgetNoAccounts => 'No accounts available.';

  @override
  String get enterFloatingMode => 'Enter floating mode';

  @override
  String get exitFloatingMode => 'Exit floating mode';

  @override
  String get floatingModeTitle => 'Usage monitor';

  @override
  String get floatingModeDescription =>
      'This window stays above other windows.';

  @override
  String get floatingOpacity => 'Window opacity';

  @override
  String get antigravityGeminiFiveHour => 'Gemini (5 hours)';

  @override
  String get antigravityGeminiWeekly => 'Gemini (weekly)';

  @override
  String get antigravityClaudeGptFiveHour => 'Claude / GPT (5 hours)';

  @override
  String get antigravityClaudeGptWeekly => 'Claude / GPT (weekly)';

  @override
  String get floatingAccounts => 'Floating mode accounts';

  @override
  String get floatingAllAccounts => 'Show all accounts';

  @override
  String get floatingNoAccounts => 'No accounts selected.';

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
  String get updatesUnsignedInstaller =>
      'Installer is not signed. Automatic installation was blocked.';

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

  @override
  String get apiConnectionErrorTitle => 'Could not connect to the API';

  @override
  String get apiConnectionErrorReasonsTitle =>
      'Possible reasons for this failure:';

  @override
  String get apiConnectionReasonCliClosed =>
      'The Antigravity CLI or Desktop app is closed or not running.';

  @override
  String get apiConnectionReasonNetwork =>
      'No internet connection or local/remote server is unresponsive.';

  @override
  String get apiConnectionReasonSession =>
      'Session or OAuth token expired or is not configured.';

  @override
  String get apiConnectionReasonFirewall =>
      'Firewall or network settings block connections to 127.0.0.1 or the API.';

  @override
  String get viewPossibleReasons => 'View possible causes';

  @override
  String get hidePossibleReasons => 'Hide causes';

  @override
  String get retryConnection => 'Retry connection';

  @override
  String get copilotReasonSession =>
      'GitHub session expired or no active GitHub Copilot subscription.';

  @override
  String get copilotReason2FA =>
      'Two-factor authentication (2FA) or device verification required by GitHub.';

  @override
  String get copilotReasonNetwork =>
      'No internet connection or GitHub API (api.github.com) is unresponsive.';

  @override
  String get copilotReasonFirewall =>
      'Network, proxy, or VPN blocking connections to GitHub.';

  @override
  String get codexReasonSession =>
      'ChatGPT/OpenAI session not signed in or expired.';

  @override
  String get codexReasonCloudflare =>
      'Cloudflare or Arkose security check requires logging in again.';

  @override
  String get codexReasonNetwork =>
      'No internet connection or ChatGPT servers are unresponsive.';

  @override
  String get codexReasonFirewall =>
      'Network or VPN blocking access to chatgpt.com.';

  @override
  String get notificationEnabled => 'Keep status notification';

  @override
  String get notificationShowProvider => 'Show provider';

  @override
  String get notificationShowFiveHour => 'Show 5-hour usage';

  @override
  String get notificationShowWeekly => 'Show weekly usage';

  @override
  String get notificationPrivacy => 'Lock-screen privacy';

  @override
  String get notificationPrivacyFull => 'Account and usage';

  @override
  String get notificationPrivacyHideAccounts => 'Hide account names';

  @override
  String get notificationPrivacyHidden => 'Hide all usage';

  @override
  String get historyWindow => 'History';

  @override
  String get history24Hours => '24h';

  @override
  String get history7Days => '7d';

  @override
  String get history30Days => '30d';

  @override
  String get allAccountsFilter => 'All accounts';

  @override
  String get allProvidersFilter => 'All providers';

  @override
  String get providerOverview => 'Provider comparison';

  @override
  String get providerHealthy => 'Healthy';

  @override
  String get providerStale => 'Stale data';

  @override
  String get providerProblem => 'Needs attention';

  @override
  String get providerNoData => 'No data';

  @override
  String get manualReloginTooltip => 'Log in again';

  @override
  String get customLimitsTooltip => 'Custom limits';

  @override
  String customLimitsTitle(String account) {
    return 'Custom limits for $account';
  }

  @override
  String get customLimitsUseDefaults => 'Use global limits';

  @override
  String get deleteAllDataSection => 'Delete all data';

  @override
  String get deleteAllDataDescription =>
      'Deletes accounts, sessions, encrypted credentials, history, notification records and settings from this device.';

  @override
  String get deleteAllDataButton => 'Delete all app data';

  @override
  String get deleteAllDataTitle => 'Delete all app data?';

  @override
  String get deleteAllDataBody =>
      'You will need to sign in again. This cannot be undone.';

  @override
  String get deleteAllDataDone => 'All app data was deleted.';

  @override
  String get deleteAllDataConfirm => 'Delete everything';

  @override
  String get diagnosticsSafeDescription =>
      'Shows account and refresh health only. Tokens, cookies and raw provider responses are never included.';

  @override
  String get dashboardFilters => 'View';

  @override
  String dashboardFilterSummary(
    String account,
    String provider,
    String period,
  ) {
    return '$account · $provider · $period';
  }

  @override
  String get clearDashboardFilters => 'Clear filters';

  @override
  String get filterAccount => 'Account';

  @override
  String get filterProvider => 'Provider';

  @override
  String get filterHistory => 'History';

  @override
  String get filterDone => 'Done';

  @override
  String get wearSection => 'Wear OS';

  @override
  String get wearDescription =>
      'The watch receives sanitized usage data from this phone. Sessions and credentials stay on the phone.';

  @override
  String get wearSyncButton => 'Send current data to watch';

  @override
  String get wearSyncSent => 'Current data sent to watch.';

  @override
  String get wearSyncUnavailable => 'Watch sync is not available right now.';

  @override
  String get taskerSection => 'Tasker';

  @override
  String get taskerDescription =>
      'Send this broadcast from Tasker to open the app and run a rate-limited refresh.';

  @override
  String get taskerCopyAction => 'Copy broadcast action';
}
