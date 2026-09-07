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

  // --- Seuils de détection des gâchettes analogiques (Zwift Play) ---
  // Hystérésis presse/relâche : voir PlayNotification. Le seuil de relâche
  // doit toujours rester strictement inférieur au seuil d'appui, sinon
  // l'hystérésis s'inverse et provoque du chatter permanent.
  static const _keyPaddlePressThreshold = "paddlePressThreshold";
  static const _keyPaddleReleaseThreshold = "paddleReleaseThreshold";
  static const int defaultPaddlePressThreshold = 60;
  static const int defaultPaddleReleaseThreshold = 35;
  int paddlePressThreshold = defaultPaddlePressThreshold;
  int paddleReleaseThreshold = defaultPaddleReleaseThreshold;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      // Charger l’état vibration
      vibrationEnabled = _prefs.getBool(_keyVibrationEnabled) ?? true;

      paddlePressThreshold = _prefs.getInt(_keyPaddlePressThreshold) ?? defaultPaddlePressThreshold;
      paddleReleaseThreshold = _prefs.getInt(_keyPaddleReleaseThreshold) ?? defaultPaddleReleaseThreshold;

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

  // --- Setters seuils gâchette, avec persistance et contrainte release < press ---
  Future<void> setPaddlePressThreshold(int value) async {
    paddlePressThreshold = value.clamp(0, 100).toInt();
    if (paddleReleaseThreshold >= paddlePressThreshold) {
      paddleReleaseThreshold = (paddlePressThreshold - 5).clamp(0, paddlePressThreshold).toInt();
      await _prefs.setInt(_keyPaddleReleaseThreshold, paddleReleaseThreshold);
    }
    await _prefs.setInt(_keyPaddlePressThreshold, paddlePressThreshold);
  }

  Future<void> setPaddleReleaseThreshold(int value) async {
    final maxRelease = paddlePressThreshold > 0 ? paddlePressThreshold - 1 : 0;
    paddleReleaseThreshold = value.clamp(0, maxRelease).toInt();
    await _prefs.setInt(_keyPaddleReleaseThreshold, paddleReleaseThreshold);
  }
}
