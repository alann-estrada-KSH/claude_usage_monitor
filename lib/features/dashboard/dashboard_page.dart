import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../core/connectivity/connectivity_provider.dart';
import '../../core/models/claude_account.dart';
import '../../core/models/usage_snapshot.dart';
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

enum _DashboardMenuAction { addAccount, settings }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _chromeReady = true);
      _bootstrap();
    });
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
      const QuickActions quickActions = QuickActions();
      quickActions.initialize((type) {
        if (type == 'refresh_now' && mounted) {
          context.read<AccountProvider>().refreshAll();
        }
      });
      quickActions.setShortcutItems([
        ShortcutItem(
          type: 'refresh_now',
          localizedTitle: l10n.refreshNowTooltip,
        ),
      ]);
    }

    await provider.init();
    if (connectivity.hasConnection) await provider.refreshAll();
    if (!mounted) return;
    _poller = UsagePoller(
      // Skip the fetch entirely while offline instead of letting every
      // tick hit a SocketException -- the offline banner already tells the
      // user why nothing is updating, and onReconnected above catches up
      // immediately once the connection comes back rather than waiting for
      // the next tick.
      onTick: () => connectivity.hasConnection ? provider.refreshAll() : Future.value(),
      interval: Duration(seconds: settings.refreshIntervalSeconds),
    )..start();
    status.start(interval: Duration(seconds: settings.statusRefreshIntervalSeconds));
    await _tray.init(
      showHideLabel: l10n.trayShowHide,
      refreshLabel: l10n.trayRefreshNow,
      quitLabel: l10n.trayQuit,
      tooltip: l10n.appTitle,
    );
    _trayTooltipProvider = provider;
    provider.addListener(_updateTrayTooltip);
    _updateTrayTooltip();
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
    _trayTooltipProvider?.removeListener(_updateTrayTooltip);
    _tray.dispose();
    _poller?.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final label = await showDialog<String>(
      context: context,
      builder: (context) => _LabelDialog(
        title: l10n.nameAccountDialogTitle,
        confirmLabel: l10n.continueToLogin,
      ),
    );
    if (label == null || label.trim().isEmpty || !mounted) return;

    // Generated up front (not by addAccount, afterwards) so the login
    // webview can use it as its cookie profile *before* the account record
    // exists -- login and the later cookie-read both need the same id to
    // land in the same isolated WebKitWebContext.
    final accountId = DateTime.now().microsecondsSinceEpoch.toString();
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AccountLoginPage(profile: accountId)),
    );
    if (loggedIn != true || !mounted) return;

    final provider = context.read<AccountProvider>();
    final account = await provider.addAccount(label.trim(), id: accountId);
    await provider.refreshUsage(account.id);
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
    final statusInterval = context.watch<SettingsProvider>().statusRefreshIntervalSeconds;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ClaudeStatusProvider>().updateInterval(Duration(seconds: statusInterval)),
    );

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: _chromeReady ? 48 : 0,
        leading: _chromeReady
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: ClaudeMark(size: 22, color: colors.primary),
              )
            : null,
        title: _chromeReady ? Text(l10n.dashboardTitle, overflow: TextOverflow.ellipsis) : null,
        actions: !_chromeReady
            ? const []
            : [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: l10n.focusModeTooltip,
            onPressed: context.watch<AccountProvider>().accounts.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FocusModePage()),
                    ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<_DashboardMenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == _DashboardMenuAction.settings) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
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
                return RefreshIndicator(
                  onRefresh: provider.refreshAll,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final account = provider.accounts[index];
                      return _AccountCard(
                        account: account,
                        onRefresh: () => provider.refreshUsage(account.id),
                        onRemove: () => provider.removeAccount(account.id),
                        onRename: (label) => provider.renameAccount(account.id, label),
                      );
                    },
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
            Text(l10n.emptyStateTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.emptyStateBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({this.initialValue, required this.title, required this.confirmLabel});

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
    required this.onRefresh,
    required this.onRemove,
    required this.onRename,
  });

  final ClaudeAccount account;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;
  final ValueChanged<String> onRename;

  _Severity _severity(BuildContext context) {
    final usage = account.lastKnownUsage;
    if (usage == null || !usage.isAvailable) return _Severity.unknown;
    final worst = [usage.fiveHourPercent, usage.weeklyPercent]
        .whereType<double>()
        .fold<double>(0, (a, b) => a > b ? a : b);
    final settings = context.watch<SettingsProvider>();
    if (worst >= settings.criticalThresholdPercent) return _Severity.critical;
    if (worst >= settings.warningThresholdPercent) return _Severity.warning;
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
                        Expanded(
                          child: Text(
                            account.label,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: l10n.renameAccountTooltip,
                          onPressed: () => _rename(context, l10n),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: l10n.refreshNowTooltip,
                          onPressed: onRefresh,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: l10n.removeAccountTooltip,
                          onPressed: () => _confirmRemove(context, l10n),
                        ),
                      ],
                    ),
                    if (account.lastFetchSessionExpired) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.lock_clock, size: 16, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.sessionExpiredMessage,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _reconnect(context),
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(l10n.reconnectButton),
                      ),
                      if (usage != null) ...[
                        const SizedBox(height: 12),
                        _buildUsageBars(context, l10n, usage),
                      ],
                    ] else if (account.lastFetchError != null && usage == null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.usageDataUnavailable(account.lastFetchError ?? l10n.unknownReason),
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ] else if (account.lastFetchError != null && usage != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.cachedDataWarning,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildUsageBars(BuildContext context, AppLocalizations l10n, UsageSnapshot usage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UsageBar(
          label: l10n.fiveHourWindow,
          percent: usage.fiveHourPercent,
          resetAt: usage.fiveHourResetAt,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Sparkline(percent: usage.fiveHourPercent),
          ),
        ),
        const SizedBox(height: 14),
        UsageBar(
          label: l10n.weeklyWindow,
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

  Future<void> _confirmRemove(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeAccountDialogTitle),
        content: Text(l10n.removeAccountDialogBody(account.label)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.remove)),
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
      MaterialPageRoute(builder: (_) => AccountLoginPage(profile: account.id)),
    );
    if (loggedIn == true && context.mounted) {
      onRefresh();
    }
  }
}

