import 'package:flutter/services.dart';
class PlatformService {
  static const _channel = MethodChannel('glassfiles/platform');
  Future<T?> call<T>(String method, [Map<String, dynamic>? arguments]) => _channel.invokeMethod<T>(method, arguments);
}
