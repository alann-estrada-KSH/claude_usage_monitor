import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_provider.dart';

/// A labeled percentage + reset-time line. Shared between the dashboard's
/// account cards and the full-screen focus view (which just renders it
/// [large]). No bar/gauge here on purpose -- warning/critical color lives
/// in the sparkline underneath instead (see severityColor/Sparkline).
class UsageBar extends StatelessWidget {
  const UsageBar({
    super.key,
    required this.label,
    this.percent,
    this.resetAt,
    this.large = false,
    this.child,
  });

  final String label;
  final double? percent;
  final DateTime? resetAt;
  final bool large;

  /// Rendered between the label/percent row and the reset line -- this is
  /// where the history sparkline goes, so the reading order is always
  /// title -> graph -> reset time, never graph-after-reset.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    // headlineSmall, not displaySmall -- focus mode's percentages (the only
    // `large` caller) read as oversized/cartoonish at display scale on a
    // phone screen; still clearly the focal number, just not screen-filling.
    final percentStyle = (large
            ? Theme.of(context).textTheme.headlineSmall
            : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
            Text(percent != null ? '${percent!.toStringAsFixed(0)}%' : '--', style: percentStyle),
          ],
        ),
        ?child,
        if (resetAt != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.resetsApprox(_relativeTime(context, l10n, resetAt!)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _relativeTime(BuildContext context, AppLocalizations l10n, DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return l10n.resetNow;

    final relative = diff.inDays >= 1
        ? l10n.resetInDays(diff.inDays)
        : diff.inHours >= 1
            ? l10n.resetInHoursMinutes(diff.inHours, diff.inMinutes % 60)
            : l10n.resetInMinutes(diff.inMinutes);

    // Beyond a couple of hours, "in 6d" alone is hard to place on a
    // calendar -- pair it with the actual date/time it resolves to.
    if (diff.inHours < 2) return relative;
    final absolute = formatAbsoluteDateTime(context, l10n, target);
    return '$relative ($absolute)';
  }
}

/// Color for a percent value against the user's configured warning/critical
/// thresholds (Settings > usage thresholds). Shared by dashboard cards,
/// usage bars, and focus mode so they never disagree on what counts as
/// "warning" vs "critical".
Color severityColor(BuildContext context, double percent) {
  final settings = context.watch<SettingsProvider>();
  final colors = Theme.of(context).colorScheme;
  if (percent >= settings.criticalThresholdPercent) return colors.error;
  if (percent >= settings.warningThresholdPercent) return const Color(0xFFCC9900);
  return colors.primary;
}

/// "Today, 4:38pm" / "Tomorrow, 4:38pm" / "11 Jul, 4:38pm" -- and, for a
/// date in a different year, "11 Jul 2027, 4:38pm". Honors the 12h/24h
/// choice from Settings.
String formatAbsoluteDateTime(BuildContext context, AppLocalizations l10n, DateTime target) {
  final now = DateTime.now();
  final isToday = target.year == now.year && target.month == now.month && target.day == now.day;
  final tomorrow = now.add(const Duration(days: 1));
  final isTomorrow =
      target.year == tomorrow.year && target.month == tomorrow.month && target.day == tomorrow.day;

  final locale = Localizations.localeOf(context).toString();
  final use24h = context.watch<SettingsProvider>().use24HourFormat;
  final time = DateFormat(use24h ? 'HH:mm' : 'h:mm a', locale).format(target);

  if (isToday) return '${l10n.today}, $time';
  if (isTomorrow) return '${l10n.tomorrow}, $time';

  final datePattern = target.year == now.year ? 'd MMM' : 'd MMM yyyy';
  final date = DateFormat(datePattern, locale).format(target);
  return '$date, $time';
}
