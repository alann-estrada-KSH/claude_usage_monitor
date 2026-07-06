import 'dart:async';

/// Runs [onTick] on a fixed interval. Enforces a 30s floor so the app never
/// hammers claude.ai regardless of what a user types into settings.
class UsagePoller {
  UsagePoller({
    required this.onTick,
    Duration interval = const Duration(seconds: 90),
  }) : _interval = _clamp(interval);

  final FutureOr<void> Function() onTick;
  Duration _interval;
  Timer? _timer;

  static const minInterval = Duration(seconds: 30);

  static Duration _clamp(Duration d) => d < minInterval ? minInterval : d;

  Duration get interval => _interval;

  void start() {
    stop();
    _timer = Timer.periodic(_interval, (_) => onTick());
  }

  void updateInterval(Duration interval) {
    _interval = _clamp(interval);
    if (_timer != null) start();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
