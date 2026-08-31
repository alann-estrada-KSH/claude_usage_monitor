import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/connectivity/connectivity_provider.dart';
import '../../core/local_api/local_api_service.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/claude_account.dart';
import '../../core/models/provider_type.dart';
import '../../core/models/usage_snapshot.dart';
import '../../core/models/usage_history_point.dart';
import '../../core/models/usage_history_window.dart';
import '../../core/polling/usage_poller.dart';
import '../../core/status/claude_status_provider.dart';
import '../../core/tray/app_tray_controller.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_login_page.dart';
import '../accounts/account_provider.dart';
import '../settings/settings_page.dart';
import '../settings/settings_provider.dart';
import 'claude_mark.dart';
import 'focus_mode_page.dart';
import 'live_updated_ago.dart';
import 'offline_banner.dart';
import 'sparkline.dart';
import 'status_banner.dart';
import 'usage_bar.dart';
import 'usage_history_chart.dart';

enum _DashboardMenuAction { addAccount, settings }

enum _AccountAction { rename, relogin, limits, remove }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _watchChannel = MethodChannel('claude_usage_monitor/watch');
  UsagePoller? _poller;
  late final AppTrayController _tray = AppTrayController(
    onRefreshNow: () => context.read<AccountProvider>().refreshAll(),
  );
  AccountProvider? _trayTooltipProvider;

  // On Linux the GTK window's real size can arrive a frame or two after the
  // engine paints its first frame, so that first frame briefly sees a
  // near-zero-width window. A full AppBar (logo + title + menu button)
  // cannot fit in that degenerate width and its debug overflow indicator
  // crashes the whole process trying to paint into it. Render a bare AppBar
  // for that first frame only, then swap in the real chrome once layout has
  // had a chance to settle against the window's actual size.
  bool _chromeReady = false;
  bool _floatingMode = false;
  Size? _sizeBeforeFloating;
  bool? _alwaysOnTopBeforeFloating;
  AccountProviderType? _providerFilter;
  String? _accountFilter;
  int _historyDays = 7;
  AccountProvider? _shortcutProvider;

  @override
  void initState() {
    super.initState();
    _watchChannel.setMethodCallHandler(_handleWatchCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _chromeReady = true);
      _bootstrap();
    });
  }

  Future<void> _handleWatchCall(MethodCall call) async {
    if (call.method != 'refreshNow' || !mounted) return;
    await context.read<AccountProvider>().refreshAll();
  }

  Future<void> _bootstrap() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AccountProvider>();
    final settings = context.read<SettingsProvider>();
    final status = context.read<ClaudeStatusProvider>();
    final connectivity = context.read<ConnectivityProvider>();

    await connectivity.init();
    connectivity.onReconnected = () => provider.refreshAll();

    if (Platform.isAndroid || Platform.isIOS) {
      const quickActions = QuickActions();
      quickActions.initialize((type) {
        if (type == 'refresh_now' && mounted) {
          context.read<AccountProvider>().refreshAll();
        } else if (type.startsWith('account_') && mounted) {
          setState(() => _accountFilter = type.substring('account_'.length));
          context.read<AccountProvider>().refreshUsage(_accountFilter!);
        }
      });
    }

    await provider.init();
    if (Platform.isAndroid || Platform.isIOS) {
      _shortcutProvider = provider;
      provider.addListener(_syncQuickActions);
      await _syncQuickActions();
    }
    await settings.init();
    if (settings.floatingModeEnabled) {
      await windowManager.setAsFrameless();
      await _resizeForFloatingMode();
      if (mounted) setState(() => _floatingMode = true);
    }
    LocalApiService.instance.configure(
      accounts: () => provider.accounts,
      settings: () => settings.settings,
    );
    await LocalApiService.instance.apply();
    if (connectivity.hasConnection) await provider.refreshAll();
    if (!mounted) return;
    _poller = UsagePoller(
      // Skip the fetch entirely while offline instead of letting every
      // tick hit a SocketException -- the offline banner already tells the
      // user why nothing is updating, and onReconnected above catches up
      // immediately once the connection comes back rather than waiting for
      // the next tick.
      onTick: () =>
          connectivity.hasConnection ? provider.refreshAll() : Future.value(),
      interval: Duration(seconds: settings.refreshIntervalSeconds),
    )..start();
    status.start(
      interval: Duration(seconds: settings.statusRefreshIntervalSeconds),
    );
    await _tray.init(
      showHideLabel: l10n.trayShowHide,
      refreshLabel: l10n.trayRefreshNow,
      quitLabel: l10n.trayQuit,
      tooltip: l10n.appTitle,
    );
    if (settings.floatingModeEnabled) _tray.setFloatingMode(true);
    _trayTooltipProvider = provider;
    provider.addListener(_updateTrayTooltip);
    _updateTrayTooltip();
  }

  Future<void> _syncQuickActions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final l10n = AppLocalizations.of(context);
    final provider = _shortcutProvider;
    if (l10n == null || provider == null) return;
    final actions = <ShortcutItem>[
      ShortcutItem(type: 'refresh_now', localizedTitle: l10n.refreshNowTooltip),
      ...provider.accounts
          .take(3)
          .map(
            (account) => ShortcutItem(
              type: 'account_${account.id}',
              localizedTitle: '${l10n.refreshNowTooltip}: ${account.label}',
            ),
          ),
    ];
    await const QuickActions().setShortcutItems(actions);
  }

  // Hovering the tray icon previously always showed the same static app
  // name -- rebuild the tooltip from current usage every time accounts
  // change (refresh, add, remove) so the limits are visible without
  // opening the window.
  void _updateTrayTooltip() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final provider = _trayTooltipProvider;
    if (provider == null || provider.accounts.isEmpty) {
      _tray.updateTooltip(l10n.appTitle);
      _tray.updateUsageSummary(const []);
      return;
    }
    final lines = provider.accounts.map((a) {
      final usage = a.lastKnownUsage;
      final five = usage?.fiveHourPercent?.toStringAsFixed(0) ?? '--';
      final weekly = usage?.weeklyPercent?.toStringAsFixed(0) ?? '--';
      return l10n.trayTooltipLine(a.label, five, weekly);
    }).toList();
    _tray.updateTooltip(lines.join('\n'));
    // Linux tray hosts don't reliably show a hover tooltip (see
    // AppTrayController.updateTooltip) -- these disabled menu lines are
    // what actually surfaces the limits there, visible on click.
    _tray.updateUsageSummary(lines);
  }

  @override
  void dispose() {
    _watchChannel.setMethodCallHandler(null);
    _trayTooltipProvider?.removeListener(_updateTrayTooltip);
    _shortcutProvider?.removeListener(_syncQuickActions);
    _tray.dispose();
    _poller?.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AccountProvider>();
    final hasAntigravity = provider.accounts.any(
      (a) => a.providerType == AccountProviderType.antigravity,
    );

    final selectedProvider = await showDialog<AccountProviderType>(
      context: context,
      builder: (context) =>
          _ProviderSelectionDialog(hasAntigravity: hasAntigravity),
    );
    if (selectedProvider == null || !mounted) return;

    if (selectedProvider == AccountProviderType.antigravity) {
      if (hasAntigravity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya existe una cuenta de Antigravity configurada. Solo se permite 1 cuenta local activa.',
            ),
          ),
        );
        return;
      }

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Antigravity (Cuenta Local)'),
          content: const Text(
            'Las métricas de Antigravity se tomarán automáticamente de la cuenta activa que se esté ejecutando en tu sistema (CLI / Antigravity app).\n\n'
            'No es necesario iniciar sesión mediante navegador.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;

      final label = await showDialog<String>(
        context: context,
        builder: (context) => _LabelDialog(
          initialValue: 'Antigravity',
          title: l10n.nameAccountDialogTitle,
          confirmLabel: l10n.save,
        ),
      );
      if (label == null || label.trim().isEmpty || !mounted) return;

      final accountId = DateTime.now().microsecondsSinceEpoch.toString();
      final account = await provider.addAccount(
        label.trim(),
        id: accountId,
        providerType: AccountProviderType.antigravity,
      );
      await provider.refreshUsage(account.id);
      return;
    }

    final label = await showDialog<String>(
      context: context,
      builder: (context) => _LabelDialog(
        title: l10n.nameAccountDialogTitle,
        confirmLabel: l10n.continueToLogin,
      ),
    );
    if (label == null || label.trim().isEmpty || !mounted) return;

    final accountId = DateTime.now().microsecondsSinceEpoch.toString();
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountLoginPage(
          profile: accountId,
          providerType: selectedProvider,
        ),
      ),
    );
    if (loggedIn != true || !mounted) return;

    final account = await provider.addAccount(
      label.trim(),
      id: accountId,
      providerType: selectedProvider,
    );
    await provider.refreshUsage(account.id);
  }

  Future<void> _enterFloatingMode() async {
    if (!Platform.isLinux && !Platform.isWindows) return;
    final settings = context.read<SettingsProvider>();
    _sizeBeforeFloating ??= await windowManager.getSize();
    _alwaysOnTopBeforeFloating ??= await windowManager.isAlwaysOnTop();
    await settings.setFloatingModeEnabled(true);
    _tray.setFloatingMode(true);
    await windowManager.setAsFrameless();
    await _resizeForFloatingMode();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setAlwaysOnTop(true);
    if (mounted) setState(() => _floatingMode = true);
  }

  Future<void> _exitFloatingMode() async {
    if (!_floatingMode) return;
    final settings = context.read<SettingsProvider>();
    await settings.setFloatingModeEnabled(false);
    _tray.setFloatingMode(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(const Size(-1, -1));
    await windowManager.setAlwaysOnTop(
      settings.floatingWindowEnabled || (_alwaysOnTopBeforeFloating ?? false),
    );
    final previousSize = _sizeBeforeFloating;
    if (previousSize != null) {
      await windowManager.setSize(previousSize, animate: true);
    }
    if (mounted) {
      setState(() {
        _floatingMode = false;
        _sizeBeforeFloating = null;
        _alwaysOnTopBeforeFloating = null;
      });
    }
  }

  Future<void> _resizeForFloatingMode() async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMinimumSize(const Size(280, 220));
    await windowManager.setSize(const Size(390, 330), animate: true);
    await windowManager.center();
  }

  Future<void> _configureFloatingAccounts() async {
    final settings = context.read<SettingsProvider>();
    final accounts = context.read<AccountProvider>().accounts;
    if (accounts.isEmpty) return;
    final selection = await showDialog<_FloatingAccountSelection>(
      context: context,
      builder: (_) => _FloatingAccountsDialog(
        allAccounts: settings.floatingAllAccounts,
        accountIds: settings.floatingAccountIds,
        accounts: accounts,
      ),
    );
    if (selection == null || !mounted) return;
    await settings.setFloatingAccounts(
      allAccounts: selection.allAccounts,
      accountIds: selection.accountIds,
    );
  }

  Future<void> _configureFloatingOpacity() async {
    final settings = context.read<SettingsProvider>();
    final value = await showDialog<double>(
      context: context,
      builder: (_) =>
          _FloatingOpacityDialog(initialValue: settings.floatingWindowOpacity),
    );
    if (value != null && mounted) {
      await settings.setFloatingWindowOpacity(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final interval = context.watch<SettingsProvider>().refreshIntervalSeconds;
    final poller = _poller;
    if (poller != null && poller.interval.inSeconds != interval) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => poller.updateInterval(Duration(seconds: interval)),
      );
    }
    final statusInterval = context
        .watch<SettingsProvider>()
        .statusRefreshIntervalSeconds;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ClaudeStatusProvider>().updateInterval(
        Duration(seconds: statusInterval),
      ),
    );

    final colors = Theme.of(context).colorScheme;

    if (_floatingMode) {
      return _FloatingDashboard(
        onExit: _exitFloatingMode,
        onConfigureAccounts: _configureFloatingAccounts,
        onConfigureOpacity: _configureFloatingOpacity,
        onRefresh: context.read<AccountProvider>().refreshAll,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: _chromeReady ? 48 : 0,
        leading: _chromeReady
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: ClaudeMark(size: 22, color: colors.primary),
              )
            : null,
        title: _chromeReady
            ? Text(l10n.dashboardTitle, overflow: TextOverflow.ellipsis)
            : null,
        actions: !_chromeReady
            ? const []
            : [
                if (Platform.isLinux || Platform.isWindows) ...[
                  IconButton(
                    onPressed: _enterFloatingMode,
                    icon: const Icon(Icons.picture_in_picture_alt_outlined),
                    tooltip: l10n.enterFloatingMode,
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: l10n.focusModeTooltip,
                  onPressed: context.watch<AccountProvider>().accounts.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FocusModePage(),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<_DashboardMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    if (action == _DashboardMenuAction.settings) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    } else {
                      _addAccount();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _DashboardMenuAction.addAccount,
                      child: ListTile(
                        leading: const Icon(Icons.add),
                        title: Text(l10n.addAccountTooltip),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _DashboardMenuAction.settings,
                      child: ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: Text(l10n.settingsTooltip),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const StatusBanner(),
          Expanded(
            child: Consumer<AccountProvider>(
              builder: (context, provider, _) {
                if (provider.accounts.isEmpty) {
                  return _EmptyState(onAddAccount: _addAccount);
                }
                final filtered = provider.accounts.where((account) {
                  final providerMatches =
                      _providerFilter == null ||
                      account.providerType == _providerFilter;
                  final accountMatches =
                      _accountFilter == null || account.id == _accountFilter;
                  return providerMatches && accountMatches;
                }).toList();
                return RefreshIndicator(
                  onRefresh: provider.refreshAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _DashboardFilters(
                        accounts: provider.accounts,
                        accountId: _accountFilter,
                        providerType: _providerFilter,
                        historyDays: _historyDays,
                        onAccountChanged: (value) =>
                            setState(() => _accountFilter = value),
                        onProviderChanged: (value) =>
                            setState(() => _providerFilter = value),
                        onHistoryChanged: (value) =>
                            setState(() => _historyDays = value),
                      ),
                      const SizedBox(height: 12),
                      _ProviderOverview(accounts: filtered),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Center(child: Text(l10n.allAccountsFilter))
                      else
                        ...filtered.map(
                          (account) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AccountCard(
                              account: account,
                              history: filterHistory(
                                provider.historyFor(account.id),
                                days: _historyDays,
                              ),
                              onRefresh: () =>
                                  provider.refreshUsage(account.id),
                              onRemove: () =>
                                  provider.removeAccount(account.id),
                              onRename: (label) =>
                                  provider.renameAccount(account.id, label),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddAccount});

  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: ClaudeMark(size: 40, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.emptyStateTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyStateBody,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
              label: Text(l10n.addAccountButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardFilters extends StatelessWidget {
  const _DashboardFilters({
    required this.accounts,
    required this.accountId,
    required this.providerType,
    required this.historyDays,
    required this.onAccountChanged,
    required this.onProviderChanged,
    required this.onHistoryChanged,
  });

  final List<ClaudeAccount> accounts;
  final String? accountId;
  final AccountProviderType? providerType;
  final int historyDays;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<AccountProviderType?> onProviderChanged;
  final ValueChanged<int> onHistoryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providers = accounts.map((account) => account.providerType).toSet();
    final accountLabel = accountId == null
        ? l10n.allAccountsFilter
        : accounts
              .where((account) => account.id == accountId)
              .map((account) => account.label)
              .firstOrNull ?? l10n.allAccountsFilter;
    final providerLabel = providerType?.displayName ?? l10n.allProvidersFilter;
    final periodLabel = switch (historyDays) {
      1 => l10n.history24Hours,
      30 => l10n.history30Days,
      _ => l10n.history7Days,
    };
    final hasFilters = accountId != null || providerType != null || historyDays != 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.tune,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.dashboardFilterSummary(
                  accountLabel,
                  providerLabel,
                  periodLabel,
                ),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => _DashboardFilterSheet(
                  accounts: accounts,
                  providers: providers,
                  accountId: accountId,
                  providerType: providerType,
                  historyDays: historyDays,
                  onAccountChanged: onAccountChanged,
                  onProviderChanged: onProviderChanged,
                  onHistoryChanged: onHistoryChanged,
                ),
              ),
              icon: const Icon(Icons.tune, size: 16),
              label: Text(l10n.dashboardFilters),
            ),
            if (hasFilters)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.clearDashboardFilters,
                onPressed: () {
                  onAccountChanged(null);
                  onProviderChanged(null);
                  onHistoryChanged(7);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardFilterSheet extends StatelessWidget {
  const _DashboardFilterSheet({
    required this.accounts,
    required this.providers,
    required this.accountId,
    required this.providerType,
    required this.historyDays,
    required this.onAccountChanged,
    required this.onProviderChanged,
    required this.onHistoryChanged,
  });

  final List<ClaudeAccount> accounts;
  final Set<AccountProviderType> providers;
  final String? accountId;
  final AccountProviderType? providerType;
  final int historyDays;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<AccountProviderType?> onProviderChanged;
  final ValueChanged<int> onHistoryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.filterAccount, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.allAccountsFilter),
                  selected: accountId == null,
                  onSelected: (_) => onAccountChanged(null),
                ),
                ...accounts.map(
                  (account) => ChoiceChip(
                    label: Text(account.label, overflow: TextOverflow.ellipsis),
                    selected: account.id == accountId,
                    onSelected: (_) => onAccountChanged(account.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.filterProvider, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.allProvidersFilter),
                  selected: providerType == null,
                  onSelected: (_) => onProviderChanged(null),
                ),
                ...providers.map(
                  (provider) => ChoiceChip(
                    label: Text(provider.displayName),
                    selected: provider == providerType,
                    onSelected: (_) => onProviderChanged(provider),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.filterHistory, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 1, label: Text(l10n.history24Hours)),
                ButtonSegment(value: 7, label: Text(l10n.history7Days)),
                ButtonSegment(value: 30, label: Text(l10n.history30Days)),
              ],
              selected: {historyDays},
              onSelectionChanged: (selection) => onHistoryChanged(selection.first),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check),
                label: Text(l10n.filterDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderOverview extends StatelessWidget {
  const _ProviderOverview({required this.accounts});

  final List<ClaudeAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final grouped = <AccountProviderType, List<ClaudeAccount>>{};
    for (final account in accounts) {
      grouped.putIfAbsent(account.providerType, () => []).add(account);
    }
    if (grouped.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.providerOverview,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final entry in grouped.entries)
              _ProviderOverviewRow(
                provider: entry.key,
                accounts: entry.value,
                staleAfter: Duration(
                  seconds: (settings.refreshIntervalSeconds * 3).clamp(
                    300,
                    1800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderOverviewRow extends StatelessWidget {
  const _ProviderOverviewRow({
    required this.provider,
    required this.accounts,
    required this.staleAfter,
  });

  final AccountProviderType provider;
  final List<ClaudeAccount> accounts;
  final Duration staleAfter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final stale = accounts.any(
      (account) =>
          account.lastFetchedAt == null ||
          now.difference(account.lastFetchedAt!) > staleAfter,
    );
    final problem = accounts.any(
      (account) =>
          account.lastFetchSessionExpired || account.lastFetchError != null,
    );
    final values = accounts
        .map((account) => account.lastKnownUsage?.fiveHourPercent)
        .whereType<double>()
        .toList();
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final status = problem
        ? l10n.providerProblem
        : stale
        ? l10n.providerStale
        : average == null
        ? l10n.providerNoData
        : l10n.providerHealthy;
    final color = problem
        ? Theme.of(context).colorScheme.error
        : stale
        ? Colors.amber.shade800
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(provider.displayName)),
          if (average != null) Text('5 h ${average.round()}%  ·  '),
          Text(status, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FloatingDashboard extends StatelessWidget {
  const _FloatingDashboard({
    required this.onExit,
    required this.onConfigureAccounts,
    required this.onConfigureOpacity,
    required this.onRefresh,
  });

  final VoidCallback onExit;
  final VoidCallback onConfigureAccounts;
  final VoidCallback onConfigureOpacity;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: DragToResizeArea(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                DragToMoveArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: l10n.floatingModeDescription,
                          child: Text(
                            l10n.floatingModeTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onConfigureAccounts,
                        tooltip: l10n.floatingAccounts,
                        icon: const Icon(Icons.manage_accounts_outlined),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onConfigureOpacity,
                        tooltip: l10n.floatingOpacity,
                        icon: const Icon(Icons.opacity_outlined),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onRefresh,
                        tooltip: l10n.refreshNowTooltip,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Consumer2<AccountProvider, SettingsProvider>(
                    builder: (context, provider, settings, _) {
                      final accounts = settings.floatingAllAccounts
                          ? provider.accounts
                          : provider.accounts
                                .where(
                                  (account) => settings.floatingAccountIds
                                      .contains(account.id),
                                )
                                .toList();
                      if (accounts.isEmpty) {
                        return Center(child: Text(l10n.floatingNoAccounts));
                      }
                      return ListView.separated(
                        itemCount: accounts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _FloatingAccountCard(account: accounts[index]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.picture_in_picture_alt_outlined),
                    label: Text(l10n.exitFloatingMode),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingAccountCard extends StatelessWidget {
  const _FloatingAccountCard({required this.account});

  final ClaudeAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usage = account.lastKnownUsage;
    final providerIcon = switch (account.providerType) {
      AccountProviderType.claude => Icons.chat_bubble_outline,
      AccountProviderType.codex => Icons.terminal,
      AccountProviderType.antigravity => Icons.auto_awesome,
      AccountProviderType.copilot => Icons.code,
      AccountProviderType.openCodeGo => Icons.integration_instructions_outlined,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(providerIcon, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.62,
                          ),
                          child: Text(
                            account.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              account.providerType.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._floatingMetrics(
              l10n,
              account.providerType,
              usage,
            ).asMap().entries.expand(
              (entry) => [
                if (entry.key > 0) const SizedBox(height: 6),
                _FloatingUsageLine(
                  label: entry.value.label,
                  percent: entry.value.percent,
                  resetAt: entry.value.resetAt,
                ),
              ],
            ),
            if (account.lastFetchSessionExpired)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.sessionExpiredMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMetric {
  const _FloatingMetric(this.label, this.percent, this.resetAt);

  final String label;
  final double? percent;
  final DateTime? resetAt;
}

List<_FloatingMetric> _floatingMetrics(
  AppLocalizations l10n,
  AccountProviderType providerType,
  UsageSnapshot? usage,
) {
  if (usage == null) {
    return [
      _FloatingMetric(l10n.fiveHourWindow, null, null),
      _FloatingMetric(l10n.weeklyWindow, null, null),
    ];
  }

  if (providerType == AccountProviderType.antigravity) {
    return [
      _FloatingMetric(
        l10n.antigravityGeminiFiveHour,
        usage.fiveHourPercent,
        usage.fiveHourResetAt,
      ),
      _FloatingMetric(
        l10n.antigravityGeminiWeekly,
        usage.weeklyPercent,
        usage.weeklyResetAt,
      ),
      _FloatingMetric(
        l10n.antigravityClaudeGptFiveHour,
        usage.claudeGptFiveHourPercent,
        usage.claudeGptFiveHourResetAt,
      ),
      _FloatingMetric(
        l10n.antigravityClaudeGptWeekly,
        usage.claudeGptWeeklyPercent,
        usage.claudeGptWeeklyResetAt,
      ),
    ];
  }

  final firstLabel = providerType == AccountProviderType.copilot
      ? l10n.copilotChatWindow
      : l10n.fiveHourWindow;
  final secondLabel = providerType == AccountProviderType.copilot
      ? l10n.copilotCompletionsWindow
      : (usage.weeklyResetAt != null &&
                usage.weeklyResetAt!.difference(DateTime.now()).inDays > 14
            ? l10n.monthlyWindow
            : l10n.weeklyWindow);
  final metrics = [
    _FloatingMetric(firstLabel, usage.fiveHourPercent, usage.fiveHourResetAt),
    _FloatingMetric(secondLabel, usage.weeklyPercent, usage.weeklyResetAt),
  ];
  if (providerType == AccountProviderType.openCodeGo) {
    metrics.add(
      _FloatingMetric(
        l10n.monthlyWindow,
        usage.monthlyPercent,
        usage.monthlyResetAt,
      ),
    );
  }
  return metrics;
}

class _FloatingUsageLine extends StatelessWidget {
  const _FloatingUsageLine({
    required this.label,
    required this.percent,
    required this.resetAt,
  });

  final String label;
  final double? percent;
  final DateTime? resetAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = percent?.clamp(0, 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
            Text(
              value == null ? '--' : '${value.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(value: value == null ? 0 : value / 100),
        if (resetAt != null) ...[
          const SizedBox(height: 3),
          Text(
            l10n.resetsApprox(formatRelativeReset(context, l10n, resetAt!)),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}

class _FloatingOpacityDialog extends StatefulWidget {
  const _FloatingOpacityDialog({required this.initialValue});

  final double initialValue;

  @override
  State<_FloatingOpacityDialog> createState() => _FloatingOpacityDialogState();
}

class _FloatingOpacityDialogState extends State<_FloatingOpacityDialog> {
  late double _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.floatingOpacity),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _value,
            min: AppSettings.minFloatingWindowOpacity,
            max: AppSettings.maxFloatingWindowOpacity,
            divisions: 11,
            label: '${(_value * 100).round()}%',
            onChanged: (value) => setState(() => _value = value),
          ),
          Text('${(_value * 100).round()}%'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _FloatingAccountSelection {
  const _FloatingAccountSelection({
    required this.allAccounts,
    required this.accountIds,
  });

  final bool allAccounts;
  final List<String> accountIds;
}

class _FloatingAccountsDialog extends StatefulWidget {
  const _FloatingAccountsDialog({
    required this.allAccounts,
    required this.accountIds,
    required this.accounts,
  });

  final bool allAccounts;
  final List<String> accountIds;
  final List<ClaudeAccount> accounts;

  @override
  State<_FloatingAccountsDialog> createState() =>
      _FloatingAccountsDialogState();
}

class _FloatingAccountsDialogState extends State<_FloatingAccountsDialog> {
  late bool _allAccounts = widget.allAccounts;
  late final Set<String> _accountIds = widget.accountIds.toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.floatingAccounts),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.floatingAllAccounts),
              value: _allAccounts,
              onChanged: (value) => setState(() {
                _allAccounts = value;
                if (value) _accountIds.clear();
              }),
            ),
            if (!_allAccounts)
              for (final account in widget.accounts)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(account.label),
                  value: _accountIds.contains(account.id),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _accountIds.add(account.id);
                    } else {
                      _accountIds.remove(account.id);
                    }
                  }),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _FloatingAccountSelection(
              allAccounts: _allAccounts,
              accountIds: _accountIds.toList(),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _ProviderSelectionDialog extends StatelessWidget {
  const _ProviderSelectionDialog({this.hasAntigravity = false});

  final bool hasAntigravity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SimpleDialog(
      title: Text(l10n.selectProviderTitle),
      children: AccountProviderType.values
          .where((type) {
            if (Platform.isAndroid || Platform.isIOS) {
              if (type == AccountProviderType.antigravity) return false;
            }
            if (hasAntigravity && type == AccountProviderType.antigravity) {
              return false;
            }
            return true;
          })
          .map((type) {
            final icon = switch (type) {
              AccountProviderType.claude => Icons.chat_bubble_outline,
              AccountProviderType.codex => Icons.terminal,
              AccountProviderType.antigravity => Icons.auto_awesome,
              AccountProviderType.copilot => Icons.code,
              AccountProviderType.openCodeGo =>
                Icons.integration_instructions_outlined,
            };
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(type),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      type.displayName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(),
    );
  }
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({
    this.initialValue,
    required this.title,
    required this.confirmLabel,
  });

  final String? initialValue;
  final String title;
  final String confirmLabel;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.nameAccountHint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

enum _Severity { ok, warning, critical, unknown }

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.history,
    required this.onRefresh,
    required this.onRemove,
    required this.onRename,
  });

  final ClaudeAccount account;
  final List<UsageHistoryPoint> history;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;
  final ValueChanged<String> onRename;

  _Severity _severity(BuildContext context) {
    final usage = account.lastKnownUsage;
    if (usage == null || !usage.isAvailable) return _Severity.unknown;
    final worst = [
      usage.fiveHourPercent,
      usage.weeklyPercent,
    ].whereType<double>().fold<double>(0, (a, b) => a > b ? a : b);
    final settings = context.watch<SettingsProvider>();
    if (worst >=
        (account.criticalThresholdPercent ??
            settings.criticalThresholdPercent)) {
      return _Severity.critical;
    }
    if (worst >=
        (account.warningThresholdPercent ?? settings.warningThresholdPercent)) {
      return _Severity.warning;
    }
    return _Severity.ok;
  }

  Color _severityColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (_severity(context)) {
      _Severity.critical => colors.error,
      _Severity.warning => const Color(0xFFB8860B),
      _Severity.ok => colors.primary,
      _Severity.unknown => colors.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usage = account.lastKnownUsage;
    final accent = _severityColor(context);
    final debugMode = context.watch<SettingsProvider>().debugMode;
    final settings = context.watch<SettingsProvider>();
    final stale =
        account.lastFetchedAt == null ||
        DateTime.now().difference(account.lastFetchedAt!) >
            Duration(
              seconds: (settings.refreshIntervalSeconds * 3)
                  .clamp(300, 1800)
                  .toInt(),
            );

    final providerIcon = switch (account.providerType) {
      AccountProviderType.claude => Icons.chat_bubble_outline,
      AccountProviderType.codex => Icons.terminal,
      AccountProviderType.antigravity => Icons.auto_awesome,
      AccountProviderType.copilot => Icons.code,
      AccountProviderType.openCodeGo => Icons.integration_instructions_outlined,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          providerIcon,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  account.providerType.displayName,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (stale)
                          Tooltip(
                            message: l10n.providerStale,
                            child: Icon(
                              Icons.schedule,
                              size: 17,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        const SizedBox(width: 8),
                        PopupMenuButton<_AccountAction>(
                          tooltip: l10n.settingsTooltip,
                          onSelected: (action) {
                            switch (action) {
                              case _AccountAction.rename:
                                _rename(context, l10n);
                              case _AccountAction.relogin:
                                _reconnect(context);
                              case _AccountAction.limits:
                                _configureLimits(context);
                              case _AccountAction.remove:
                                _confirmRemove(context, l10n);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _AccountAction.relogin,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.login),
                                title: Text(l10n.manualReloginTooltip),
                              ),
                            ),
                            PopupMenuItem(
                              value: _AccountAction.limits,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.tune),
                                title: Text(l10n.customLimitsTooltip),
                              ),
                            ),
                            PopupMenuItem(
                              value: _AccountAction.rename,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.edit_outlined),
                                title: Text(l10n.renameAccountTooltip),
                              ),
                            ),
                            PopupMenuItem(
                              value: _AccountAction.remove,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.delete_outline),
                                title: Text(l10n.removeAccountTooltip),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: l10n.refreshNowTooltip,
                          onPressed: onRefresh,
                        ),
                      ],
                    ),
                    if (account.lastFetchSessionExpired) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_clock,
                            size: 16,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.sessionExpiredMessage,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _reconnect(context),
                            icon: const Icon(Icons.login, size: 18),
                            label: Text(l10n.reconnectButton),
                          ),
                          if (debugMode && usage?.rawPageText != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 20),
                              tooltip: 'Ver error detallado',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                      'Detalle de API / Diagnostic',
                                    ),
                                    content: SingleChildScrollView(
                                      child: SelectableText(
                                        usage!.rawPageText!,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cerrar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ] else if (account.lastFetchError != null &&
                        usage == null) ...[
                      _ConnectionErrorView(
                        account: account,
                        errorText: account.lastFetchError ?? l10n.unknownReason,
                        showTechnicalDetails: debugMode,
                        onRetry: onRefresh,
                      ),
                    ] else if (account.lastFetchError != null &&
                        usage != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.cachedDataWarning,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildUsageBars(context, l10n, usage),
                    ] else if (usage == null) ...[
                      const SizedBox(height: 4),
                      Text(l10n.noUsageDataYet),
                    ] else ...[
                      const SizedBox(height: 8),
                      _buildUsageBars(context, l10n, usage),
                    ],
                    if (history.length > 1) ...[
                      const SizedBox(height: 10),
                      UsageHistoryChart(points: history),
                    ],
                    if (account.lastFetchedAt != null) ...[
                      const SizedBox(height: 10),
                      LiveUpdatedAgo(fetchedAt: account.lastFetchedAt!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBars(
    BuildContext context,
    AppLocalizations l10n,
    UsageSnapshot usage,
  ) {
    final isCopilot = account.providerType == AccountProviderType.copilot;
    final isAntigravity =
        account.providerType == AccountProviderType.antigravity;
    final isOpenCodeGo = account.providerType == AccountProviderType.openCodeGo;

    if (isOpenCodeGo) {
      final hasFiveHour =
          usage.fiveHourPercent != null || usage.fiveHourResetAt != null;
      final hasWeekly =
          usage.weeklyPercent != null || usage.weeklyResetAt != null;
      final hasMonthly =
          usage.monthlyPercent != null || usage.monthlyResetAt != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFiveHour) ...[
            UsageBar(
              label: l10n.fiveHourWindow,
              percent: usage.fiveHourPercent,
              resetAt: usage.fiveHourResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.fiveHourPercent),
              ),
            ),
            if (hasWeekly || hasMonthly) const SizedBox(height: 14),
          ],
          if (hasWeekly) ...[
            UsageBar(
              label: l10n.weeklyWindow,
              percent: usage.weeklyPercent,
              resetAt: usage.weeklyResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.weeklyPercent),
              ),
            ),
            if (hasMonthly) const SizedBox(height: 14),
          ],
          if (hasMonthly)
            UsageBar(
              label: l10n.monthlyWindow,
              percent: usage.monthlyPercent,
              resetAt: usage.monthlyResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.monthlyPercent),
              ),
            ),
        ],
      );
    }

    if (isAntigravity) {
      final hasGemini5h =
          usage.fiveHourPercent != null || usage.fiveHourResetAt != null;
      final hasGeminiWeekly =
          usage.weeklyPercent != null || usage.weeklyResetAt != null;
      final hasClaude5h =
          usage.claudeGptFiveHourPercent != null ||
          usage.claudeGptFiveHourResetAt != null;
      final hasClaudeWeekly =
          usage.claudeGptWeeklyPercent != null ||
          usage.claudeGptWeeklyResetAt != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasGemini5h) ...[
            UsageBar(
              label: 'Gemini (5 Horas)',
              percent: usage.fiveHourPercent,
              resetAt: usage.fiveHourResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.fiveHourPercent),
              ),
            ),
            if (hasGeminiWeekly || hasClaude5h || hasClaudeWeekly)
              const SizedBox(height: 14),
          ],
          if (hasGeminiWeekly) ...[
            UsageBar(
              label: 'Gemini (Semanal)',
              percent: usage.weeklyPercent,
              resetAt: usage.weeklyResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.weeklyPercent),
              ),
            ),
            if (hasClaude5h || hasClaudeWeekly) const SizedBox(height: 14),
          ],
          if (hasClaude5h) ...[
            UsageBar(
              label: 'Claude / GPT (5 Horas)',
              percent: usage.claudeGptFiveHourPercent,
              resetAt: usage.claudeGptFiveHourResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.claudeGptFiveHourPercent),
              ),
            ),
            if (hasClaudeWeekly) const SizedBox(height: 14),
          ],
          if (hasClaudeWeekly) ...[
            UsageBar(
              label: 'Claude / GPT (Semanal)',
              percent: usage.claudeGptWeeklyPercent,
              resetAt: usage.claudeGptWeeklyResetAt,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Sparkline(percent: usage.claudeGptWeeklyPercent),
              ),
            ),
          ],
        ],
      );
    }

    final hasFiveHour =
        usage.fiveHourPercent != null || usage.fiveHourResetAt != null;
    final hasWeekly =
        usage.weeklyPercent != null || usage.weeklyResetAt != null;
    final isMonthly =
        usage.weeklyResetAt != null &&
        usage.weeklyResetAt!.difference(DateTime.now()).inDays > 14;

    final firstLabel = isCopilot ? l10n.copilotChatWindow : l10n.fiveHourWindow;
    final secondLabel = isCopilot
        ? l10n.copilotCompletionsWindow
        : (isMonthly ? l10n.monthlyWindow : l10n.weeklyWindow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasFiveHour) ...[
          UsageBar(
            label: firstLabel,
            percent: usage.fiveHourPercent,
            resetAt: usage.fiveHourResetAt,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Sparkline(percent: usage.fiveHourPercent),
            ),
          ),
          if (hasWeekly) const SizedBox(height: 14),
        ],
        if (hasWeekly || !hasFiveHour)
          UsageBar(
            label: secondLabel,
            percent: usage.weeklyPercent,
            resetAt: usage.weeklyResetAt,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Sparkline(percent: usage.weeklyPercent),
            ),
          ),
      ],
    );
  }

  Future<void> _configureLimits(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final warning = TextEditingController(
      text:
          (account.warningThresholdPercent ?? settings.warningThresholdPercent)
              .toString(),
    );
    final critical = TextEditingController(
      text:
          (account.criticalThresholdPercent ??
                  settings.criticalThresholdPercent)
              .toString(),
    );
    var useDefaults =
        account.warningThresholdPercent == null ||
        account.criticalThresholdPercent == null;
    final result = await showDialog<(bool, int?, int?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final warningValue = int.tryParse(warning.text);
          final criticalValue = int.tryParse(critical.text);
          final valid =
              useDefaults ||
              (warningValue != null &&
                  criticalValue != null &&
                  warningValue >= 1 &&
                  warningValue < criticalValue &&
                  criticalValue <= 100);
          return AlertDialog(
            title: Text(l10n.customLimitsTitle(account.label)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.customLimitsUseDefaults),
                  value: useDefaults,
                  onChanged: (value) =>
                      setState(() => useDefaults = value ?? true),
                ),
                TextField(
                  controller: warning,
                  enabled: !useDefaults,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.thresholdWarning(0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: critical,
                  enabled: !useDefaults,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.thresholdCritical(0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (!valid)
                  Text(
                    l10n.thresholdsSection,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(dialogContext, (
                        useDefaults,
                        useDefaults ? null : warningValue,
                        useDefaults ? null : criticalValue,
                      ))
                    : null,
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
    warning.dispose();
    critical.dispose();
    if (result == null || !context.mounted) return;
    await context.read<AccountProvider>().setAccountThresholds(
      account.id,
      warning: result.$2,
      critical: result.$3,
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeAccountDialogTitle),
        content: Text(l10n.removeAccountDialogBody(account.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) onRemove();
  }

  Future<void> _rename(BuildContext context, AppLocalizations l10n) async {
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => _LabelDialog(
        initialValue: account.label,
        title: l10n.renameAccountDialogTitle,
        confirmLabel: l10n.save,
      ),
    );
    if (newLabel == null) return;
    final trimmed = newLabel.trim();
    if (trimmed.isEmpty || trimmed == account.label) return;
    onRename(trimmed);
  }

  Future<void> _reconnect(BuildContext context) async {
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountLoginPage(
          profile: account.id,
          providerType: account.providerType,
        ),
      ),
    );
    if (loggedIn == true && context.mounted) {
      onRefresh();
    }
  }
}

class _ConnectionErrorView extends StatefulWidget {
  const _ConnectionErrorView({
    required this.account,
    required this.errorText,
    required this.showTechnicalDetails,
    required this.onRetry,
  });

  final ClaudeAccount account;
  final String errorText;
  final bool showTechnicalDetails;
  final VoidCallback onRetry;

  @override
  State<_ConnectionErrorView> createState() => _ConnectionErrorViewState();
}

class _ConnectionErrorViewState extends State<_ConnectionErrorView> {
  bool _showReasons = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 20, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.apiConnectionErrorTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (widget.showTechnicalDetails) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText,
              style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _showReasons = !_showReasons),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _showReasons
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showReasons
                            ? l10n.hidePossibleReasons
                            : l10n.viewPossibleReasons,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(
                  l10n.retryConnection,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (_showReasons) ...[
            const Divider(height: 12),
            Text(
              l10n.apiConnectionErrorReasonsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (widget.account.providerType == AccountProviderType.codex) ...[
              _ReasonItem(icon: Icons.key_off, text: l10n.codexReasonSession),
              _ReasonItem(
                icon: Icons.security,
                text: l10n.codexReasonCloudflare,
              ),
              _ReasonItem(icon: Icons.wifi_off, text: l10n.codexReasonNetwork),
              _ReasonItem(icon: Icons.shield, text: l10n.codexReasonFirewall),
            ] else if (widget.account.providerType ==
                AccountProviderType.copilot) ...[
              _ReasonItem(icon: Icons.key_off, text: l10n.copilotReasonSession),
              _ReasonItem(icon: Icons.lock_clock, text: l10n.copilotReason2FA),
              _ReasonItem(
                icon: Icons.wifi_off,
                text: l10n.copilotReasonNetwork,
              ),
              _ReasonItem(icon: Icons.shield, text: l10n.copilotReasonFirewall),
            ] else if (widget.account.providerType ==
                AccountProviderType.antigravity) ...[
              const _ReasonItem(
                icon: Icons.power_settings_new,
                text:
                    'El CLI de Antigravity (`agy`) o la aplicación de escritorio está cerrada (si usas la cuenta local).',
              ),
              _ReasonItem(
                icon: Icons.wifi_off,
                text: l10n.apiConnectionReasonNetwork,
              ),
              _ReasonItem(
                icon: Icons.key_off,
                text: l10n.apiConnectionReasonSession,
              ),
              _ReasonItem(
                icon: Icons.shield,
                text: l10n.apiConnectionReasonFirewall,
              ),
            ] else ...[
              _ReasonItem(
                icon: Icons.key_off,
                text: l10n.apiConnectionReasonSession,
              ),
              _ReasonItem(
                icon: Icons.wifi_off,
                text: l10n.apiConnectionReasonNetwork,
              ),
              _ReasonItem(
                icon: Icons.shield,
                text: l10n.apiConnectionReasonFirewall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReasonItem extends StatelessWidget {
  const _ReasonItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
