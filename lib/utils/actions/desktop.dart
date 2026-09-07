import 'package:flutter/services.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class DesktopActions extends BaseActions {
  // Compte combien de ZwiftButton "tiennent" une même touche physique enfoncée
  // (ex. paddleLeft et sideButtonLeft partagent le même KeyPair). On n'envoie
  // le keyDown qu'au premier appui et le keyUp qu'au dernier relâchement, pour
  // qu'un des deux boutons relâché en premier n'interrompe pas l'autre.
  final Map<PhysicalKeyboardKey, int> _heldKeys = {};

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
      final key = keyPair.physicalKey!;
      final count = (_heldKeys[key] ?? 0) + 1;
      _heldKeys[key] = count;
      if (count == 1) {
        await keyPressSimulator.simulateKeyDown(key);
      }
      return 'Key down: ${keyPair.logicalKey?.keyLabel}';
    } else {
      final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
      await keyPressSimulator.simulateMouseClick(point);
      return 'Mouse clicked at: $point';
    }
  }

  @override
  Future<String> releaseAction(ZwiftButton action) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: $action');
    }

    if (keyPair.physicalKey != null) {
      final key = keyPair.physicalKey!;
      final count = (_heldKeys[key] ?? 0) - 1;
      if (count <= 0) {
        _heldKeys.remove(key);
        await keyPressSimulator.simulateKeyUp(key);
      } else {
        _heldKeys[key] = count;
      }
      return 'Key up: ${keyPair.logicalKey?.keyLabel}';
    } else {
      return 'No physical key to release';
    }
  }
}
