import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has any network connectivity at all (not
/// whether claude.ai specifically is reachable -- just enough to skip
/// automatic refreshes and show a banner instead of letting every poll
/// tick hit a SocketException while offline).
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  /// Fired when connectivity goes from none -> some, so callers can trigger
  /// an immediate refresh instead of waiting for the next poll interval.
  VoidCallback? onReconnected;

  Future<void> init() async {
    _hasConnection = _isConnected(await _connectivity.checkConnectivity());
    notifyListeners();

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasConnected = _hasConnection;
      _hasConnection = _isConnected(results);
      if (!wasConnected && _hasConnection) {
        onReconnected?.call();
      }
      notifyListeners();
    });
  }

  bool _isConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
