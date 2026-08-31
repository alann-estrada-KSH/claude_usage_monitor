import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/claude_account.dart';
import '../../core/local_api/local_api_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/storage/notification_log_store.dart';
import '../../core/update/app_update_info.dart';
import '../../core/update/update_checker.dart';
import '../../core/widgets/android_widget_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_provider.dart';
import '../dashboard/claude_mark.dart';
import 'settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final debugMode = context.watch<SettingsProvider>().debugMode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: l10n.refreshIntervalSection,
            child: const _RefreshIntervalControl(),
          ),
          const SizedBox(height: 16),
          if (Platform.isAndroid) ...[
            _SectionCard(
              title: l10n.keepAliveSection,
              child: const _KeepAliveControl(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.pinnedNotificationSection,
              child: const _PinnedNotificationControl(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.widgetSection,
              child: const _WidgetAccountsControl(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.taskerSection,
              child: const _TaskerControl(),
            ),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: l10n.statusSection,
            child: const _StatusIntervalControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.appearanceSection,
            child: const _ThemeModeControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.accentColorSection,
            child: const _AccentColorControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(title: l10n.fontSection, child: const _FontControl()),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.languageSection,
            child: const _LanguageControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.timeFormatSection,
            child: const _TimeFormatControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.focusModeAccountsSection,
            child: const _FocusModeAccountsControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.thresholdsSection,
            child: const _ThresholdsControl(),
          ),
          const SizedBox(height: 16),
          if (Platform.isLinux || Platform.isWindows) ...[
            _SectionCard(
              title: l10n.floatingWindowSection,
              child: const _FloatingWindowControl(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.localApiSection,
              child: const _LocalApiControl(),
            ),
            const SizedBox(height: 16),
          ],
          if (kDebugMode)
            _SectionCard(
              title: l10n.diagnosticsSection,
              child: const _DiagnosticsPanel(),
            ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.debugModeSection,
              child: const _DebugModeToggle(),
            ),
          ],
          if (kDebugMode && debugMode) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.debugPanelSection,
              child: const _DebugPanel(),
            ),
          ],
          if (Platform.isWindows) ...[
            _SectionCard(
              title: l10n.updatesSection,
              child: const _UpdatesControl(),
            ),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: l10n.resetSection,
            child: const _ResetSettingsControl(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.deleteAllDataSection,
            child: const _DeleteAllDataControl(),
          ),
          const SizedBox(height: 16),
          const _AboutFooter(),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _RefreshIntervalControl extends StatelessWidget {
  const _RefreshIntervalControl();

  static const _presets = [30, 60, 90, 120, 300];

  // 60s and 90s both truncate to "1m" under naive `seconds ~/ 60` -- show
  // the fractional minute (90s -> "1.5m") instead of losing the distinction.
  static String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds % 60 == 0) return '${seconds ~/ 60}m';
    return '${(seconds / 60).toStringAsFixed(1)}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final current = settings.refreshIntervalSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.refreshIntervalDescription(
            AppSettings.minRefreshIntervalSeconds,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((seconds) {
            final selected = current == seconds;
            return ChoiceChip(
              label: Text(_formatSeconds(seconds)),
              selected: selected,
              onSelected: (_) => settings.setRefreshInterval(seconds),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: current.toDouble(),
                min: AppSettings.minRefreshIntervalSeconds.toDouble(),
                max: AppSettings.maxRefreshIntervalSeconds.toDouble(),
                divisions:
                    (AppSettings.maxRefreshIntervalSeconds -
                        AppSettings.minRefreshIntervalSeconds) ~/
                    10,
                label: '${current}s',
                onChanged: (value) =>
                    settings.setRefreshInterval(value.round()),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text('${current}s', textAlign: TextAlign.end),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeepAliveControl extends StatelessWidget {
  const _KeepAliveControl();

  static const _presets = [15, 30, 60, 120, 240];

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.keepAliveDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.keepAliveToggle),
          value: settings.keepSessionAliveEnabled,
          onChanged: settings.setKeepSessionAliveEnabled,
        ),
        if (settings.keepSessionAliveEnabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((minutes) {
              return ChoiceChip(
                label: Text(_formatMinutes(minutes)),
                selected: settings.keepSessionAliveIntervalMinutes == minutes,
                onSelected: (_) =>
                    settings.setKeepSessionAliveInterval(minutes),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _UpdatesControl extends StatefulWidget {
  const _UpdatesControl();

  @override
  State<_UpdatesControl> createState() => _UpdatesControlState();
}

class _UpdatesControlState extends State<_UpdatesControl> {
  static const _checker = UpdateChecker();

  String? _currentVersion;
  bool _checking = false;
  bool _downloading = false;
  double _downloadProgress = 0;
  AppUpdateInfo? _available;
  bool _checkedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final update = await _checker.checkForUpdate();
    if (mounted) {
      setState(() {
        _checking = false;
        _checkedOnce = true;
        _available = update;
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final l10n = AppLocalizations.of(context)!;
    final update = _available;
    if (update == null) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    final installer = await _checker.downloadInstaller(
      update.downloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );
    if (!await _checker.isInstallerSigned(installer)) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.updatesUnsignedInstaller)));
      }
      return;
    }
    if (!await _checker.runInstallerAndExit(installer) && mounted) {
      setState(() => _downloading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.updatesUnsignedInstaller)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final update = _available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentVersion == null
              ? l10n.updatesCurrentVersionUnknown
              : l10n.updatesCurrentVersion(_currentVersion!),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_downloading) ...[
          LinearProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.updatesDownloading,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else if (update != null) ...[
          Text(l10n.updatesAvailable(update.version)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _downloadAndInstall,
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.updatesDownloadAndInstall),
          ),
        ] else ...[
          if (_checkedOnce)
            Text(
              l10n.updatesUpToDate,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_checkedOnce) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_outlined),
            label: Text(
              _checking ? l10n.updatesChecking : l10n.updatesCheckButton,
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeModeControl extends StatelessWidget {
  const _ThemeModeControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text(l10n.themeSystem),
          icon: const Icon(Icons.brightness_auto),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text(l10n.themeLight),
          icon: const Icon(Icons.light_mode),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text(l10n.themeDark),
          icon: const Icon(Icons.dark_mode),
        ),
      ],
      selected: {settings.themeMode},
      onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
    );
  }
}

class _AccentColorControl extends StatelessWidget {
  const _AccentColorControl();

  static const _presets = [
    AppSettings.defaultAccentColor, // Claude orange
    0xFF39FF88, // terminal green
    0xFFFFB000, // amber
    0xFF00E5FF, // cyan
    0xFFFF5555, // red
    0xFFB388FF, // purple
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _presets.map((argb) {
        final selected = settings.accentColor == argb;
        final color = Color(argb);
        return InkWell(
          onTap: () => settings.setAccentColor(argb),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _FontControl extends StatelessWidget {
  const _FontControl();

  String _labelFor(AppLocalizations l10n, String choice) => switch (choice) {
    'comicSans' => l10n.fontComicSans,
    'consolas' => l10n.fontConsolas,
    'courierNew' => l10n.fontCourierNew,
    'georgia' => l10n.fontGeorgia,
    _ => l10n.fontMonospace,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppSettings.fontChoices.map((choice) {
        return ChoiceChip(
          label: Text(_labelFor(l10n, choice)),
          selected: settings.fontChoice == choice,
          onSelected: (_) => settings.setFontChoice(choice),
        );
      }).toList(),
    );
  }
}

class _StatusIntervalControl extends StatelessWidget {
  const _StatusIntervalControl();

  static const _presets = [300, 900, 1800, 3600, 10800, 21600];

  static String _formatSeconds(int seconds) {
    if (seconds < 3600) return '${seconds ~/ 60}m';
    return '${seconds ~/ 3600}h';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final current = settings.statusRefreshIntervalSeconds;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets.map((seconds) {
        return ChoiceChip(
          label: Text(_formatSeconds(seconds)),
          selected: current == seconds,
          onSelected: (_) => settings.setStatusRefreshInterval(seconds),
        );
      }).toList(),
    );
  }
}

class _LanguageControl extends StatelessWidget {
  const _LanguageControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return SegmentedButton<String?>(
      segments: [
        ButtonSegment(value: null, label: Text(l10n.languageSystem)),
        ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
        ButtonSegment(value: 'es', label: Text(l10n.languageSpanish)),
      ],
      selected: {settings.languageCode},
      onSelectionChanged: (selection) =>
          settings.setLanguageCode(selection.first),
    );
  }
}

class _TimeFormatControl extends StatelessWidget {
  const _TimeFormatControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: false, label: Text(l10n.timeFormat12h)),
        ButtonSegment(value: true, label: Text(l10n.timeFormat24h)),
      ],
      selected: {settings.use24HourFormat},
      onSelectionChanged: (selection) =>
          settings.setUse24HourFormat(selection.first),
    );
  }
}

class _FloatingWindowControl extends StatelessWidget {
  const _FloatingWindowControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.floatingWindowToggle),
      subtitle: Text(l10n.floatingWindowDescription),
      value: settings.floatingWindowEnabled,
      onChanged: settings.setFloatingWindowEnabled,
    );
  }
}

class _PinnedNotificationControl extends StatelessWidget {
  const _PinnedNotificationControl();

  Future<void> _save(
    SettingsProvider settings,
    AccountProvider accounts,
    bool allAccounts,
    List<String> accountIds,
  ) async {
    await settings.setPinnedNotificationAccounts(
      allAccounts: allAccounts,
      accountIds: accountIds,
    );
    await AndroidWidgetBridge.publish(
      accounts.accounts,
      persistentNotificationEnabled: settings.pinnedNotificationEnabled,
      persistentNotificationAllAccounts: allAccounts,
      persistentNotificationAccountIds: accountIds,
      persistentNotificationShowProvider:
          settings.pinnedNotificationShowProvider,
      persistentNotificationShowFiveHour:
          settings.pinnedNotificationShowFiveHour,
      persistentNotificationShowWeekly: settings.pinnedNotificationShowWeekly,
      persistentNotificationPrivacyMode: settings.pinnedNotificationPrivacyMode,
    );
  }

  Future<void> _saveDisplay(
    SettingsProvider settings,
    AccountProvider accounts, {
    bool? enabled,
    bool? showProvider,
    bool? showFiveHour,
    bool? showWeekly,
    String? privacyMode,
  }) async {
    await settings.setPinnedNotificationDisplay(
      enabled: enabled,
      showProvider: showProvider,
      showFiveHour: showFiveHour,
      showWeekly: showWeekly,
      privacyMode: privacyMode,
    );
    await _save(
      settings,
      accounts,
      settings.pinnedNotificationAllAccounts,
      settings.pinnedNotificationAccountIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final accounts = context.watch<AccountProvider>();
    if (accounts.accounts.isEmpty) {
      return Text(l10n.pinnedNotificationNoAccounts);
    }
    final selected = settings.pinnedNotificationAccountIds.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationEnabled),
          value: settings.pinnedNotificationEnabled,
          onChanged: (value) =>
              _saveDisplay(settings, accounts, enabled: value),
        ),
        if (settings.pinnedNotificationEnabled) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationShowProvider),
            value: settings.pinnedNotificationShowProvider,
            onChanged: (value) =>
                _saveDisplay(settings, accounts, showProvider: value ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationShowFiveHour),
            value: settings.pinnedNotificationShowFiveHour,
            onChanged: (value) =>
                _saveDisplay(settings, accounts, showFiveHour: value ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notificationShowWeekly),
            value: settings.pinnedNotificationShowWeekly,
            onChanged: (value) =>
                _saveDisplay(settings, accounts, showWeekly: value ?? true),
          ),
          const SizedBox(height: 8),
          Text(l10n.notificationPrivacy),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: settings.pinnedNotificationPrivacyMode,
            items: [
              DropdownMenuItem(
                value: 'full',
                child: Text(l10n.notificationPrivacyFull),
              ),
              DropdownMenuItem(
                value: 'hideAccounts',
                child: Text(l10n.notificationPrivacyHideAccounts),
              ),
              DropdownMenuItem(
                value: 'hidden',
                child: Text(l10n.notificationPrivacyHidden),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                _saveDisplay(settings, accounts, privacyMode: value);
              }
            },
          ),
          const Divider(height: 28),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.pinnedNotificationAllAccounts),
          subtitle: Text(l10n.pinnedNotificationDescription),
          value: settings.pinnedNotificationAllAccounts,
          onChanged: (value) => _save(
            settings,
            accounts,
            value,
            value
                ? const []
                : accounts.accounts.map((account) => account.id).toList(),
          ),
        ),
        if (!settings.pinnedNotificationAllAccounts) ...[
          const SizedBox(height: 8),
          Text(
            l10n.pinnedNotificationAccounts,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final account in accounts.accounts)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(account.label),
              value: selected.contains(account.id),
              onChanged: (value) {
                final next = {...selected};
                if (value == true) {
                  next.add(account.id);
                } else {
                  next.remove(account.id);
                }
                _save(settings, accounts, false, next.toList());
              },
            ),
        ],
      ],
    );
  }
}

class _TaskerControl extends StatelessWidget {
  const _TaskerControl();

  static const _action =
      'com.claudeusagemonitor.claude_usage_monitor.TASKER_REFRESH';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.taskerDescription),
        const SizedBox(height: 8),
        SelectableText(
          _action,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              Clipboard.setData(const ClipboardData(text: _action)),
          icon: const Icon(Icons.copy),
          label: Text(l10n.taskerCopyAction),
        ),
      ],
    );
  }
}

class _WidgetAccountsControl extends StatelessWidget {
  const _WidgetAccountsControl();

  Future<void> _save(
    SettingsProvider settings,
    AccountProvider accounts,
    bool allAccounts,
    List<String> accountIds,
  ) async {
    await settings.setWidgetAccounts(
      allAccounts: allAccounts,
      accountIds: accountIds,
    );
    await AndroidWidgetBridge.publish(
      accounts.accounts,
      persistentNotificationEnabled: settings.pinnedNotificationEnabled,
      persistentNotificationAllAccounts: settings.pinnedNotificationAllAccounts,
      persistentNotificationAccountIds: settings.pinnedNotificationAccountIds,
      persistentNotificationShowProvider:
          settings.pinnedNotificationShowProvider,
      persistentNotificationShowFiveHour:
          settings.pinnedNotificationShowFiveHour,
      persistentNotificationShowWeekly: settings.pinnedNotificationShowWeekly,
      persistentNotificationPrivacyMode: settings.pinnedNotificationPrivacyMode,
      widgetAllAccounts: allAccounts,
      widgetAccountIds: accountIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final accounts = context.watch<AccountProvider>();
    if (accounts.accounts.isEmpty) {
      return Text(l10n.widgetNoAccounts);
    }
    final selected = settings.widgetAccountIds.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.widgetAllAccounts),
          subtitle: Text(l10n.widgetDescription),
          value: settings.widgetAllAccounts,
          onChanged: (value) => _save(
            settings,
            accounts,
            value,
            value
                ? const []
                : accounts.accounts.map((account) => account.id).toList(),
          ),
        ),
        if (!settings.widgetAllAccounts) ...[
          const SizedBox(height: 8),
          Text(
            l10n.widgetAccounts,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final account in accounts.accounts)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(account.label),
              value: selected.contains(account.id),
              onChanged: (value) {
                final next = {...selected};
                if (value == true) {
                  next.add(account.id);
                } else {
                  next.remove(account.id);
                }
                _save(settings, accounts, false, next.toList());
              },
            ),
        ],
      ],
    );
  }
}

class _LocalApiControl extends StatefulWidget {
  const _LocalApiControl();

  @override
  State<_LocalApiControl> createState() => _LocalApiControlState();
}

class _LocalApiControlState extends State<_LocalApiControl> {
  final _portController = TextEditingController();
  final _rateLimitController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _portController.dispose();
    _rateLimitController.dispose();
    super.dispose();
  }

  Future<void> _toggle(
    BuildContext context,
    SettingsProvider settings,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    await settings.setLocalApiEnabled(enabled);
    final started = await LocalApiService.instance.apply();
    if (!started && enabled) {
      await settings.setLocalApiEnabled(false);
      await LocalApiService.instance.apply();
    }
    if (!mounted || !context.mounted) return;
    setState(() => _saving = false);
    if (!started && enabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.localApiStartError)));
    } else if (enabled) {
      await _showDetails(context);
    }
  }

  Future<void> _save(BuildContext context, SettingsProvider settings) async {
    final port = int.tryParse(_portController.text.trim());
    final rateLimit = int.tryParse(_rateLimitController.text.trim());
    final l10n = AppLocalizations.of(context)!;
    if (port == null || rateLimit == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.localApiInvalidSettings)));
      return;
    }
    setState(() => _saving = true);
    await settings.setLocalApiPort(port);
    await settings.setLocalApiRateLimitPerMinute(rateLimit);
    final started = await LocalApiService.instance.apply();
    if (!mounted || !context.mounted) return;
    setState(() => _saving = false);
    if (settings.localApiEnabled && !started) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.localApiStartError)));
    }
  }

  Future<void> _showDetails(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _LocalApiDetailsDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    if (_portController.text.isEmpty) {
      _portController.text = settings.localApiPort.toString();
      _rateLimitController.text = settings.localApiRateLimitPerMinute
          .toString();
    }
    return AnimatedBuilder(
      animation: LocalApiService.instance,
      builder: (context, _) {
        final api = LocalApiService.instance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.localApiToggle),
              subtitle: Text(l10n.localApiDescription),
              value: settings.localApiEnabled,
              onChanged: _saving
                  ? null
                  : (value) => _toggle(context, settings, value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.localApiPortLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rateLimitController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.localApiRateLimitLabel,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _saving ? null : () => _save(context, settings),
              child: Text(l10n.localApiSave),
            ),
            const SizedBox(height: 12),
            Text(
              api.isRunning
                  ? l10n.localApiRunning(api.actualPort!)
                  : l10n.localApiStopped,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (api.isRunning) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showDetails(context),
                child: Text(l10n.localApiDetails),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LocalApiDetailsDialog extends StatelessWidget {
  const _LocalApiDetailsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = LocalApiService.instance;
    return AlertDialog(
      title: Text(l10n.localApiDetailsTitle),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<String?>(
          future: api.readSecret(),
          builder: (context, snapshot) {
            final secret = snapshot.data;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.localApiSecretLabel),
                  const SizedBox(height: 4),
                  if (secret == null)
                    const CircularProgressIndicator()
                  else
                    SelectableText(secret),
                  if (secret != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: secret)),
                        icon: const Icon(Icons.copy),
                        label: Text(l10n.localApiCopy),
                      ),
                    ),
                  Text(l10n.localApiAuth),
                  const SizedBox(height: 8),
                  SelectableText(
                    l10n.localApiEndpoints,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const Divider(),
                  Text(l10n.localApiAccountsLabel),
                  const SizedBox(height: 4),
                  if (api.accounts.isEmpty)
                    Text(l10n.localApiNoAccounts)
                  else
                    ...api.accounts.map(
                      (account) => SelectableText(
                        '${account.label}: ${account.apiAccountId}',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.localApiRegenerateWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: Text(l10n.localApiRegenerateWarning),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.localApiRegenerate),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await api.regenerateSecret();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(l10n.localApiRegenerate),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ThresholdsControl extends StatelessWidget {
  const _ThresholdsControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.thresholdWarning(settings.warningThresholdPercent)),
        Slider(
          value: settings.warningThresholdPercent.toDouble(),
          min: 1,
          max: (settings.criticalThresholdPercent - 1).toDouble(),
          divisions: (settings.criticalThresholdPercent - 2).clamp(1, 98),
          label: '${settings.warningThresholdPercent}%',
          onChanged: (value) => settings.setWarningThreshold(value.round()),
        ),
        const SizedBox(height: 8),
        Text(l10n.thresholdCritical(settings.criticalThresholdPercent)),
        Slider(
          value: settings.criticalThresholdPercent.toDouble(),
          min: (settings.warningThresholdPercent + 1).toDouble(),
          max: 100,
          divisions: (99 - settings.warningThresholdPercent).clamp(1, 98),
          label: '${settings.criticalThresholdPercent}%',
          onChanged: (value) => settings.setCriticalThreshold(value.round()),
        ),
      ],
    );
  }
}

class _FocusModeAccountsControl extends StatelessWidget {
  const _FocusModeAccountsControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountProvider>();
    if (provider.accounts.isEmpty) {
      return Text(
        l10n.diagnosticsNoAccounts,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: provider.reorderAccounts,
      children: [
        for (final account in provider.accounts)
          CheckboxListTile(
            key: ValueKey(account.id),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(account.label),
            value: account.showInFocusMode,
            onChanged: (value) =>
                provider.setShowInFocusMode(account.id, value ?? true),
            secondary: ReorderableDragStartListener(
              index: provider.accounts.indexOf(account),
              child: const Icon(Icons.drag_handle),
            ),
          ),
      ],
    );
  }
}

class _DiagnosticsPanel extends StatefulWidget {
  const _DiagnosticsPanel();

  @override
  State<_DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<_DiagnosticsPanel> {
  bool _running = false;

  String _backendName(AppLocalizations l10n) {
    if (Platform.isAndroid) return l10n.diagnosticsBackendAndroid;
    return l10n.diagnosticsBackendDesktop;
  }

  Future<void> _runDiagnostics(AccountProvider provider) async {
    setState(() => _running = true);
    await provider.refreshAll();
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.diagnosticsBackend(_backendName(l10n)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(l10n.diagnosticsSafeDescription),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _running ? null : () => _runDiagnostics(provider),
          icon: _running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bug_report_outlined),
          label: Text(
            _running ? l10n.diagnosticsRunning : l10n.diagnosticsRunButton,
          ),
        ),
        const SizedBox(height: 12),
        if (provider.accounts.isEmpty)
          Text(l10n.diagnosticsNoAccounts)
        else
          ...provider.accounts.map((a) => _DiagnosticTile(account: a)),
      ],
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.account});

  final ClaudeAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usage = account.lastKnownUsage;
    final ok = usage?.isAvailable ?? false;
    return ExpansionTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        color: ok ? Colors.green : Theme.of(context).colorScheme.error,
      ),
      title: Text(account.label),
      subtitle: Text(
        usage == null
            ? l10n.diagnosticsNeverScraped
            : (ok ? l10n.diagnosticsParsedOk : l10n.diagnosticsParseFailed),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(
                l10n.diagnosticsFetchedAt,
                account.lastFetchedAt?.toIso8601String() ?? '-',
              ),
              _kv(
                l10n.diagnosticsFiveHourPercent,
                usage?.fiveHourPercent?.toStringAsFixed(0) ?? '-',
              ),
              _kv(
                l10n.diagnosticsFiveHourReset,
                usage?.fiveHourResetAt?.toIso8601String() ?? '-',
              ),
              _kv(
                l10n.diagnosticsWeeklyPercent,
                usage?.weeklyPercent?.toStringAsFixed(0) ?? '-',
              ),
              _kv(
                l10n.diagnosticsWeeklyReset,
                usage?.weeklyResetAt?.toIso8601String() ?? '-',
              ),
              if (usage?.parseError != null)
                _kv(l10n.diagnosticsParseError, usage!.parseError!),
              if (usage?.rawPageText != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      l10n.diagnosticsRawPageText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(l10n.diagnosticsCopyRawText),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: usage!.rawPageText!),
                      ),
                    ),
                  ],
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      usage!.rawPageText!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _DebugModeToggle extends StatelessWidget {
  const _DebugModeToggle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.debugModeToggle),
      value: settings.debugMode,
      onChanged: settings.setDebugMode,
    );
  }
}

class _DebugPanel extends StatefulWidget {
  const _DebugPanel();

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  final _log = NotificationLogStore();
  bool _ready = false;
  bool? _androidEnabled;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _log.init();
    _androidEnabled = await NotificationService.instance
        .areNotificationsEnabled();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _sendTest(AppLocalizations l10n) async {
    await NotificationService.instance.show(
      title: l10n.debugTestNotificationTitle,
      body: l10n.debugTestNotificationBody,
    );
    if (mounted) setState(() {});
  }

  Future<void> _sendScheduledTest(AppLocalizations l10n) async {
    await NotificationService.instance.scheduleTest(
      title: l10n.debugTestNotificationTitle,
      body: l10n.debugScheduledTestNotificationBody,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.debugScheduledTestSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_ready) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final keys = _log.firedKeys();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Platform.isAndroid)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.debugNotificationsEnabled(
                _androidEnabled == true ? l10n.debugYes : l10n.debugNo,
              ),
              style: TextStyle(
                color: _androidEnabled == false
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _sendTest(l10n),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(l10n.debugSendTestNotification),
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _sendScheduledTest(l10n),
            icon: const Icon(Icons.schedule_send_outlined),
            label: Text(l10n.debugSendScheduledTestNotification),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.debugNotificationLog,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (keys.isEmpty)
          Text(
            l10n.debugNotificationLogEmpty,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                keys.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeleteAllDataControl extends StatelessWidget {
  const _DeleteAllDataControl();

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAllDataTitle),
        content: Text(l10n.deleteAllDataBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAllDataConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final accountProvider = context.read<AccountProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    await accountProvider.clearAllData();
    await settingsProvider.clearAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deleteAllDataDone)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.deleteAllDataDescription),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => _confirm(context),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.deleteAllDataButton),
        ),
      ],
    );
  }
}

class _ResetSettingsControl extends StatelessWidget {
  const _ResetSettingsControl();

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetDialogTitle),
        content: Text(l10n.resetDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsProvider>().resetToDefaults();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.resetDone)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.resetDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmReset(context),
          icon: const Icon(Icons.restore_outlined),
          label: Text(l10n.resetButton),
        ),
      ],
    );
  }
}

class _AboutFooter extends StatefulWidget {
  const _AboutFooter();

  @override
  State<_AboutFooter> createState() => _AboutFooterState();
}

class _AboutFooterState extends State<_AboutFooter> {
  String? _versionLine;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _versionLine = 'v${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final mutedStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClaudeMark(size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.appTitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_versionLine != null) ...[
                const SizedBox(width: 8),
                Text(_versionLine!, style: mutedStyle),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.creditsLine, style: mutedStyle),
          const SizedBox(height: 10),
          Text(l10n.aboutFooter, style: mutedStyle),
        ],
      ),
    );
  }
}
