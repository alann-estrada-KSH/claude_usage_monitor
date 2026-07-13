import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Claude Usage Monitor'**
  String get appTitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage Monitor'**
  String get dashboardTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @focusModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Focus mode (full screen)'**
  String get focusModeTooltip;

  /// No description provided for @trayTooltipLine.
  ///
  /// In en, this message translates to:
  /// **'{label} · Session {five}% / Weekly {weekly}%'**
  String trayTooltipLine(String label, String five, String weekly);

  /// No description provided for @trayShowHide.
  ///
  /// In en, this message translates to:
  /// **'Show/Hide'**
  String get trayShowHide;

  /// No description provided for @trayRefreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get trayRefreshNow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @addAccountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccountTooltip;

  /// No description provided for @emptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get emptyStateTitle;

  /// No description provided for @emptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Add a Claude.ai account to start tracking its 5-hour and weekly usage limits.'**
  String get emptyStateBody;

  /// No description provided for @addAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccountButton;

  /// No description provided for @nameAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this account'**
  String get nameAccountDialogTitle;

  /// No description provided for @nameAccountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Work, Personal'**
  String get nameAccountHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueToLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue to login'**
  String get continueToLogin;

  /// No description provided for @refreshNowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get refreshNowTooltip;

  /// No description provided for @removeAccountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get removeAccountTooltip;

  /// No description provided for @renameAccountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rename account'**
  String get renameAccountTooltip;

  /// No description provided for @renameAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename this account'**
  String get renameAccountDialogTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @startCounting.
  ///
  /// In en, this message translates to:
  /// **'Write a message to start counting'**
  String get startCounting;

  /// No description provided for @cachedDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Showing cached data — the last refresh failed.'**
  String get cachedDataWarning;

  /// No description provided for @noUsageDataYet.
  ///
  /// In en, this message translates to:
  /// **'No usage data yet.'**
  String get noUsageDataYet;

  /// No description provided for @usageDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Usage data not available ({reason})'**
  String usageDataUnavailable(String reason);

  /// No description provided for @unknownReason.
  ///
  /// In en, this message translates to:
  /// **'unknown reason'**
  String get unknownReason;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Session expired.'**
  String get sessionExpiredMessage;

  /// No description provided for @reconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnectButton;

  /// No description provided for @fiveHourWindow.
  ///
  /// In en, this message translates to:
  /// **'Session (5 hrs)'**
  String get fiveHourWindow;

  /// No description provided for @weeklyWindow.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit (7 days)'**
  String get weeklyWindow;

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAgo(String time);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// No description provided for @resetsApprox.
  ///
  /// In en, this message translates to:
  /// **'Resets ~{time}'**
  String resetsApprox(String time);

  /// No description provided for @resetNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get resetNow;

  /// No description provided for @resetInHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {hours}h {minutes}m'**
  String resetInHoursMinutes(int hours, int minutes);

  /// No description provided for @resetInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes}m'**
  String resetInMinutes(int minutes);

  /// No description provided for @resetInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days}d'**
  String resetInDays(int days);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @removeAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove account?'**
  String get removeAccountDialogTitle;

  /// No description provided for @removeAccountDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{label}\" from the dashboard. It does not log you out of claude.ai.'**
  String removeAccountDialogBody(String label);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @loginPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Claude.ai'**
  String get loginPageTitle;

  /// No description provided for @loginDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get loginDone;

  /// No description provided for @loginBanner.
  ///
  /// In en, this message translates to:
  /// **'Log in below, then tap \"Done\" once you land on your Claude chat screen. Nothing you type here leaves this device.'**
  String get loginBanner;

  /// No description provided for @loginDesktopHint.
  ///
  /// In en, this message translates to:
  /// **'A separate login window has opened. Log in there, then come back here and tap \"Done\".'**
  String get loginDesktopHint;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'No internet connection -- refreshes paused until it\'s back.'**
  String get offlineMessage;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Claude status unknown (couldn\'t reach status.claude.com)'**
  String get statusUnknown;

  /// No description provided for @statusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking Claude status...'**
  String get statusChecking;

  /// No description provided for @statusSection.
  ///
  /// In en, this message translates to:
  /// **'Claude status refresh'**
  String get statusSection;

  /// No description provided for @statusPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Claude status'**
  String get statusPageTitle;

  /// No description provided for @statusLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked: {time}'**
  String statusLastChecked(String time);

  /// No description provided for @statusIncidentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unresolved incidents'**
  String get statusIncidentsTitle;

  /// No description provided for @statusNoIncidents.
  ///
  /// In en, this message translates to:
  /// **'None reported.'**
  String get statusNoIncidents;

  /// No description provided for @refreshIntervalSection.
  ///
  /// In en, this message translates to:
  /// **'Refresh interval'**
  String get refreshIntervalSection;

  /// No description provided for @refreshIntervalDescription.
  ///
  /// In en, this message translates to:
  /// **'How often to reload claude.ai/settings/usage in the background. Minimum {seconds}s to avoid hammering the site.'**
  String refreshIntervalDescription(int seconds);

  /// No description provided for @appearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accentColorSection.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColorSection;

  /// No description provided for @fontSection.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontSection;

  /// No description provided for @fontMonospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get fontMonospace;

  /// No description provided for @fontComicSans.
  ///
  /// In en, this message translates to:
  /// **'Comic Sans'**
  String get fontComicSans;

  /// No description provided for @fontConsolas.
  ///
  /// In en, this message translates to:
  /// **'Consolas'**
  String get fontConsolas;

  /// No description provided for @fontCourierNew.
  ///
  /// In en, this message translates to:
  /// **'Courier New'**
  String get fontCourierNew;

  /// No description provided for @fontGeorgia.
  ///
  /// In en, this message translates to:
  /// **'Georgia'**
  String get fontGeorgia;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @timeFormatSection.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get timeFormatSection;

  /// No description provided for @timeFormat12h.
  ///
  /// In en, this message translates to:
  /// **'12h'**
  String get timeFormat12h;

  /// No description provided for @timeFormat24h.
  ///
  /// In en, this message translates to:
  /// **'24h'**
  String get timeFormat24h;

  /// No description provided for @focusModeAccountsSection.
  ///
  /// In en, this message translates to:
  /// **'Accounts shown in focus mode'**
  String get focusModeAccountsSection;

  /// No description provided for @thresholdsSection.
  ///
  /// In en, this message translates to:
  /// **'Usage color thresholds'**
  String get thresholdsSection;

  /// No description provided for @thresholdWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning at {percent}%'**
  String thresholdWarning(int percent);

  /// No description provided for @thresholdCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical at {percent}%'**
  String thresholdCritical(int percent);

  /// No description provided for @diagnosticsSection.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsSection;

  /// No description provided for @diagnosticsBackend.
  ///
  /// In en, this message translates to:
  /// **'WebView backend on this platform: {backend}'**
  String diagnosticsBackend(String backend);

  /// No description provided for @diagnosticsBackendAndroid.
  ///
  /// In en, this message translates to:
  /// **'flutter_inappwebview (embedded WebView)'**
  String get diagnosticsBackendAndroid;

  /// No description provided for @diagnosticsBackendDesktop.
  ///
  /// In en, this message translates to:
  /// **'desktop_webview_window (webkit2gtk / WebView2)'**
  String get diagnosticsBackendDesktop;

  /// No description provided for @diagnosticsRunning.
  ///
  /// In en, this message translates to:
  /// **'Scraping...'**
  String get diagnosticsRunning;

  /// No description provided for @diagnosticsRunButton.
  ///
  /// In en, this message translates to:
  /// **'Run scrape now for all accounts'**
  String get diagnosticsRunButton;

  /// No description provided for @diagnosticsNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts to diagnose yet.'**
  String get diagnosticsNoAccounts;

  /// No description provided for @diagnosticsNeverScraped.
  ///
  /// In en, this message translates to:
  /// **'Never scraped'**
  String get diagnosticsNeverScraped;

  /// No description provided for @diagnosticsParsedOk.
  ///
  /// In en, this message translates to:
  /// **'Parsed OK'**
  String get diagnosticsParsedOk;

  /// No description provided for @diagnosticsParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parse failed'**
  String get diagnosticsParseFailed;

  /// No description provided for @diagnosticsFetchedAt.
  ///
  /// In en, this message translates to:
  /// **'Fetched at'**
  String get diagnosticsFetchedAt;

  /// No description provided for @diagnosticsFiveHourPercent.
  ///
  /// In en, this message translates to:
  /// **'5-hour %'**
  String get diagnosticsFiveHourPercent;

  /// No description provided for @diagnosticsFiveHourReset.
  ///
  /// In en, this message translates to:
  /// **'5-hour reset'**
  String get diagnosticsFiveHourReset;

  /// No description provided for @diagnosticsWeeklyPercent.
  ///
  /// In en, this message translates to:
  /// **'Weekly %'**
  String get diagnosticsWeeklyPercent;

  /// No description provided for @diagnosticsWeeklyReset.
  ///
  /// In en, this message translates to:
  /// **'Weekly reset'**
  String get diagnosticsWeeklyReset;

  /// No description provided for @diagnosticsParseError.
  ///
  /// In en, this message translates to:
  /// **'Parse error'**
  String get diagnosticsParseError;

  /// No description provided for @diagnosticsRawPageText.
  ///
  /// In en, this message translates to:
  /// **'Raw API response'**
  String get diagnosticsRawPageText;

  /// No description provided for @diagnosticsCopyRawText.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get diagnosticsCopyRawText;

  /// No description provided for @debugModeSection.
  ///
  /// In en, this message translates to:
  /// **'Debug mode'**
  String get debugModeSection;

  /// No description provided for @debugModeToggle.
  ///
  /// In en, this message translates to:
  /// **'Show notification log and test tools'**
  String get debugModeToggle;

  /// No description provided for @debugPanelSection.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugPanelSection;

  /// No description provided for @debugSendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get debugSendTestNotification;

  /// No description provided for @debugTestNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Test notification'**
  String get debugTestNotificationTitle;

  /// No description provided for @debugTestNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'If you see this, notifications are working.'**
  String get debugTestNotificationBody;

  /// No description provided for @debugSendScheduledTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send scheduled test notification (15s)'**
  String get debugSendScheduledTestNotification;

  /// No description provided for @debugScheduledTestNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'If you see this, scheduled notifications work even in the background.'**
  String get debugScheduledTestNotificationBody;

  /// No description provided for @debugScheduledTestSent.
  ///
  /// In en, this message translates to:
  /// **'Scheduled -- it\'ll arrive in about 15 seconds.'**
  String get debugScheduledTestSent;

  /// No description provided for @keepAliveSection.
  ///
  /// In en, this message translates to:
  /// **'Keep session alive'**
  String get keepAliveSection;

  /// No description provided for @keepAliveDescription.
  ///
  /// In en, this message translates to:
  /// **'Pings Claude periodically in the background (via WorkManager, battery-aware) to stop it logging you out from inactivity. 15-minute floor -- that\'s Android\'s own limit.'**
  String get keepAliveDescription;

  /// No description provided for @keepAliveToggle.
  ///
  /// In en, this message translates to:
  /// **'Keep session alive in the background'**
  String get keepAliveToggle;

  /// No description provided for @debugNotificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Android notification permission granted: {status}'**
  String debugNotificationsEnabled(String status);

  /// No description provided for @debugYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get debugYes;

  /// No description provided for @debugNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get debugNo;

  /// No description provided for @debugNotificationLog.
  ///
  /// In en, this message translates to:
  /// **'Notification log (already-fired keys)'**
  String get debugNotificationLog;

  /// No description provided for @debugNotificationLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get debugNotificationLogEmpty;

  /// No description provided for @updatesSection.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesSection;

  /// No description provided for @updatesCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version: v{version}'**
  String updatesCurrentVersion(String version);

  /// No description provided for @updatesCurrentVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Current version: unknown'**
  String get updatesCurrentVersionUnknown;

  /// No description provided for @updatesCheckButton.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updatesCheckButton;

  /// No description provided for @updatesChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get updatesChecking;

  /// No description provided for @updatesUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version.'**
  String get updatesUpToDate;

  /// No description provided for @updatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} available.'**
  String updatesAvailable(String version);

  /// No description provided for @updatesDownloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get updatesDownloadAndInstall;

  /// No description provided for @updatesDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading... the app will close to install.'**
  String get updatesDownloading;

  /// No description provided for @resetSection.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetSection;

  /// No description provided for @resetDescription.
  ///
  /// In en, this message translates to:
  /// **'Resets all settings (intervals, theme, accent color, font, thresholds, etc.) back to their original values. Doesn\'t touch your accounts or sessions.'**
  String get resetDescription;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get resetButton;

  /// No description provided for @resetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get resetDialogTitle;

  /// No description provided for @resetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will restore all preferences to their original values. This can\'t be undone.'**
  String get resetDialogBody;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings reset.'**
  String get resetDone;

  /// No description provided for @creditsLine.
  ///
  /// In en, this message translates to:
  /// **'Made by Alann Estrada -- github.com/alannnn-estrada'**
  String get creditsLine;

  /// No description provided for @aboutFooter.
  ///
  /// In en, this message translates to:
  /// **'Unofficial tool, not affiliated with or endorsed by Anthropic. 100% local: no telemetry, no analytics, cookies never leave this device.'**
  String get aboutFooter;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
