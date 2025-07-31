import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class DesktopActions extends BaseActions {
  @override
  Future<String> performAction(ZwiftButton action) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: $action');
    }

    if (keyPair.physicalKey != null) {
      // On appuie sur la touche physique : simulateKeyDown UNIQUEMENT
      await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
      await keyPressSimulator.simulateKeyUp(keyPair.physicalKey); // debug
      // NE PAS appeler simulateKeyUp ici.
      // simulateKeyUp doit être appelé au relâchement de la touche physique,
      // donc dans le code qui gère l'événement keyup/notification de relâchement.
      return 'Key down: ${keyPair.logicalKey?.keyLabel}';
    } else {
      final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
      await keyPressSimulator.simulateMouseClick(point);
      return 'Mouse clicked at: $point';
    }
  }

  // Ajoute une méthode pour le relâchement de touche (keyup)
  Future<String> releaseAction(ZwiftButton action) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: $action');
    }

    if (keyPair.physicalKey != null) {
      await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
      return 'Key up: ${keyPair.logicalKey?.keyLabel}';
    } else {
      return 'No physical key to release';
    }
  }
}
