import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/status/claude_status_provider.dart';
import '../../l10n/app_localizations.dart';
import 'status_banner.dart' show statusColorFor;
import 'usage_bar.dart' show formatAbsoluteDateTime;

/// What StatusBanner links to -- the full status description, any listed
/// incidents, when it was last fetched, and a manual refresh action.
class StatusDetailPage extends StatelessWidget {
  const StatusDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<ClaudeStatusProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.statusPageTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.refreshNowTooltip,
                onPressed: provider.refresh,
              ),
            ],
          ),
          body: Builder(builder: (context) {
            final status = provider.status;
            return RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (status == null)
                    Text(l10n.statusChecking)
                  else ...[
                    Row(
                      children: [
                        Container(width: 10, height: 10, color: statusColorFor(context, status.indicator)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status.error != null ? l10n.statusUnknown : status.description,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.statusLastChecked(formatAbsoluteDateTime(context, l10n, status.fetchedAt)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (status.error != null) ...[
                      const SizedBox(height: 8),
                      Text(status.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    Text(l10n.statusIncidentsTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (status.incidentNames.isEmpty)
                      Text(l10n.statusNoIncidents)
                    else
                      for (final name in status.incidentNames)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('- $name'),
                        ),
                  ],
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
