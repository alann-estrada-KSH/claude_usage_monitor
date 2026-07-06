import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/status/claude_status_provider.dart';
import '../../l10n/app_localizations.dart';
import 'status_detail_page.dart';

/// Claude's own operational status (statuspage.io indicator values), one
/// color per severity so "all fine" is visually distinct from "degraded"
/// distinct from "down" -- not just one accent color throughout.
Color statusColorFor(BuildContext context, String indicator) {
  final colors = Theme.of(context).colorScheme;
  return switch (indicator) {
    'none' => const Color(0xFF3DBE5F),
    'minor' => const Color(0xFFCC9900),
    'major' => const Color(0xFFE07A00),
    'critical' => colors.error,
    _ => colors.outline,
  };
}

/// A thin strip showing Claude's own platform status (status.claude.com).
/// Always visible: green while operational, the matching severity color
/// (with a highlighted background) when it isn't, and a neutral "checking"
/// state before the very first fetch completes -- that first state must
/// stay neutral rather than reusing the error/unknown styling, otherwise
/// the app looks broken for the second before its first status request
/// even lands. Tapping it opens [StatusDetailPage] (incidents + logs).
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = context.watch<ClaudeStatusProvider>().status;
    final colorScheme = Theme.of(context).colorScheme;

    final isLoading = status == null;
    final isNetworkError = status?.error != null;
    final color = isLoading || isNetworkError
        ? colorScheme.onSurfaceVariant
        : statusColorFor(context, status.indicator);
    final label = isLoading
        ? l10n.statusChecking
        : (isNetworkError ? l10n.statusUnknown : status.description);
    // Only the real severity states get a highlighted background --
    // loading and "couldn't reach the status API" are informational, not
    // alarming, so they stay flat.
    final highlighted = !isLoading && !isNetworkError && status.indicator != 'none';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StatusDetailPage()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 8, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
