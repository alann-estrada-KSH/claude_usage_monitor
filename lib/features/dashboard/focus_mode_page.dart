import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/claude_account.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_provider.dart';
import 'claude_mark.dart';
import 'live_updated_ago.dart';
import 'sparkline.dart';
import 'usage_bar.dart';

/// A distraction-free, full-screen view of every account's usage -- no app
/// bar, no controls, just the numbers. Meant to be glanced at (a second
/// monitor, a kiosk-style always-on window) rather than interacted with.
/// Tap anywhere or press Escape/back to leave.
class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accounts =
        context.watch<AccountProvider>().accounts.where((a) => a.showInFocusMode).toList();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _exit,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.escape): _ExitIntent(),
            },
            child: Actions(
              actions: {_ExitIntent: CallbackAction(onInvoke: (_) => _exit())},
              child: Focus(
                autofocus: true,
                child: SafeArea(
                  child: _FocusModeBody(accounts: accounts, colors: colors),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitIntent extends Intent {
  const _ExitIntent();
}

/// One or two accounts should always fit on screen with no scrolling at
/// all -- scaling the whole block down to fit (FittedBox) reads better on
/// a kiosk-style display than an unnecessary scrollbar for content that's
/// only slightly too tall. Three or more starts scrolling instead of
/// shrinking text past readability.
class _FocusModeBody extends StatelessWidget {
  const _FocusModeBody({required this.accounts, required this.colors});

  final List<ClaudeAccount> accounts;
  final ColorScheme colors;

  static const _fitWithoutScrollThreshold = 2;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClaudeMark(size: 40, color: colors.primary),
        const SizedBox(height: 32),
        for (final account in accounts) ...[
          _FocusAccountBlock(account: account),
          const SizedBox(height: 40),
        ],
      ],
    );

    if (accounts.length <= _fitWithoutScrollThreshold) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: FittedBox(fit: BoxFit.scaleDown, child: content),
        ),
      );
    }

    // The platform-default desktop scrollbar (a stark, always-visible gray
    // slab) reads jarring against this otherwise chrome-free view --
    // thinner, rounded, and only appears while actually scrolling.
    return Center(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          thickness: 5,
          radius: const Radius.circular(8),
          thumbVisibility: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _FocusAccountBlock extends StatelessWidget {
  const _FocusAccountBlock({required this.account});

  final ClaudeAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final usage = account.lastKnownUsage;

    final sessionBar = UsageBar(
      label: l10n.fiveHourWindow,
      percent: usage?.fiveHourPercent,
      resetAt: usage?.fiveHourResetAt,
      large: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Sparkline(percent: usage?.fiveHourPercent, height: 14),
      ),
    );
    final weeklyBar = UsageBar(
      label: l10n.weeklyWindow,
      percent: usage?.weeklyPercent,
      resetAt: usage?.weeklyResetAt,
      large: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Sparkline(percent: usage?.weeklyPercent, height: 14),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // Each window (session, weekly) always gets its own row -- a
          // side-by-side landscape layout used to live here, but two
          // meters sharing a row read worse than one on its own even with
          // width to spare.
          sessionBar,
          const SizedBox(height: 28),
          weeklyBar,
          if (account.lastFetchedAt != null) ...[
            const SizedBox(height: 12),
            Center(child: LiveUpdatedAgo(fetchedAt: account.lastFetchedAt!)),
          ],
        ],
      ),
    );
  }
}
