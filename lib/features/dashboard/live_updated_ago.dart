import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// "Updated Xm ago", ticking on its own timer -- not just when the account
/// data itself changes. Without this it froze on whatever it said right
/// after the last refresh (usually "just now") until the *next* refresh
/// came in, which could be minutes later and was actively misleading.
class LiveUpdatedAgo extends StatefulWidget {
  const LiveUpdatedAgo({super.key, required this.fetchedAt});

  final DateTime fetchedAt;

  @override
  State<LiveUpdatedAgo> createState() => _LiveUpdatedAgoState();
}

class _LiveUpdatedAgoState extends State<LiveUpdatedAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.updatedAgo(_relativeAgo(l10n, widget.fetchedAt)),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  String _relativeAgo(AppLocalizations l10n, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    return l10n.daysAgo(diff.inDays);
  }
}
