import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/claude_account.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/account_provider.dart';
import 'claude_mark.dart';
import 'live_updated_ago.dart';
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
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClaudeMark(size: 40, color: colors.primary),
                          const SizedBox(height: 32),
                          for (final account in accounts) ...[
                            _FocusAccountBlock(account: account),
                            const SizedBox(height: 40),
                          ],
                        ],
                      ),
                    ),
                  ),
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

class _FocusAccountBlock extends StatelessWidget {
  const _FocusAccountBlock({required this.account});

  final ClaudeAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final usage = account.lastKnownUsage;
    // Landscape has width to spare and not much height (especially on
    // phones) -- stacking both windows vertically there wastes the wide
    // aspect and forces scrolling. Side by side reads just as well and
    // fits without scrolling.
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final sessionBar = UsageBar(
      label: l10n.fiveHourWindow,
      percent: usage?.fiveHourPercent,
      resetAt: usage?.fiveHourResetAt,
      large: true,
    );
    final weeklyBar = UsageBar(
      label: l10n.weeklyWindow,
      percent: usage?.weeklyPercent,
      resetAt: usage?.weeklyResetAt,
      large: true,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isLandscape ? 900 : 480),
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
          if (isLandscape)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sessionBar),
                const SizedBox(width: 32),
                Expanded(child: weeklyBar),
              ],
            )
          else ...[
            sessionBar,
            const SizedBox(height: 28),
            weeklyBar,
          ],
          if (account.lastFetchedAt != null) ...[
            const SizedBox(height: 12),
            Center(child: LiveUpdatedAgo(fetchedAt: account.lastFetchedAt!)),
          ],
        ],
      ),
    );
  }
}
