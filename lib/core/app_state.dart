import 'package:flutter/foundation.dart';
import '../models/settings.dart';
import '../services/platform_service.dart';
class AppState extends ChangeNotifier {
  AppState(this.platform);
  final PlatformService platform;
  AppSettings settings = AppSettings();
  Future<void> load() async {
    final data = await platform.call<String>('load');
    if (data != null) { try { settings = AppSettings.decode(data); } catch (_) { /* Keep defaults if old data is invalid. */ } }
    notifyListeners();
  }
  void update(void Function(AppSettings) change) { change(settings); notifyListeners(); platform.call<void>('save', {'data': settings.encode()}); }
}
