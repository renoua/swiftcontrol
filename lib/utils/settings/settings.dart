import 'package:dartx/dartx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../main.dart';
import '../keymap/apps/custom_app.dart';

class Settings {
  late final SharedPreferences _prefs;

  // --- Ajout pour la vibration ---
  static const _keyVibrationEnabled = "vibrationEnabled";
  bool vibrationEnabled = true;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      // Charger l’état vibration
      vibrationEnabled = _prefs.getBool(_keyVibrationEnabled) ?? true;

      // Charger configuration d’app
      final appSetting = _prefs.getStringList("customapp");
      if (appSetting != null) {
        final customApp = CustomApp();
        customApp.decodeKeymap(appSetting);
      }

      final appName = _prefs.getString('app');
      if (appName == null) {
        return;
      }
      final app =
          SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);

      actionHandler.init(app);
    } catch (e) {
      // couldn't decode, reset
      await _prefs.clear();
      rethrow;
    }
  }

  void setApp(SupportedApp app) {
    if (app is CustomApp) {
      _prefs.setStringList("customapp", app.encodeKeymap());
    }
    _prefs.setString('app', app.name);
  }

  // --- Setter vibration avec persistance ---
  Future<void> setVibrationEnabled(bool enabled) async {
    vibrationEnabled = enabled;
    await _prefs.setBool(_keyVibrationEnabled, enabled);
  }
}
