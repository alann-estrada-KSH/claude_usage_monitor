import 'package:flutter/services.dart';

class AndroidSurfaceBridge {
  AndroidSurfaceBridge._();

  static const _channel = MethodChannel('claude_usage_monitor/surfaces');

  static Future<void> requestUpdate() => _channel.invokeMethod('requestUpdate');
}
