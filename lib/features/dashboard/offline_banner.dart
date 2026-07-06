import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/connectivity/connectivity_provider.dart';
import '../../l10n/app_localizations.dart';

/// Shown instead of (above) [StatusBanner] when the device itself has no
/// network connectivity -- distinct from Claude's own status, and from any
/// individual account's scrape failing.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final hasConnection = context.watch<ConnectivityProvider>().hasConnection;
    if (hasConnection) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.error.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.offlineMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
