import 'package:flutter/foundation.dart';

import '../models/claude_status.dart';
import '../polling/usage_poller.dart';
import 'claude_status_service.dart';

class ClaudeStatusProvider extends ChangeNotifier {
  ClaudeStatusProvider({ClaudeStatusService? service}) : _service = service ?? const ClaudeStatusService();

  final ClaudeStatusService _service;
  UsagePoller? _poller;

  ClaudeStatus? _status;
  ClaudeStatus? get status => _status;

  void start({required Duration interval}) {
    refresh();
    _poller = UsagePoller(onTick: refresh, interval: interval)..start();
  }

  void updateInterval(Duration interval) => _poller?.updateInterval(interval);

  Future<void> refresh() async {
    _status = await _service.fetchStatus();
    notifyListeners();
  }

  @override
  void dispose() {
    _poller?.dispose();
    super.dispose();
  }
}
