import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class DesktopActions extends BaseActions {
  @override

  final Map<ZwiftButton, Timer> _releaseTimers = {};
  final Set<ZwiftButton> _currentlyDown = {};
    Future<String> performAction(ZwiftButton action) async {
    if (supportedApp == null) return 'Supported app is not set';
  
    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null || keyPair.physicalKey == null) {
      return 'Keymap entry not found or no physical key for: $action';
    }
  
    final key = keyPair.physicalKey!;
  
    // Si le bouton n’était pas encore enfoncé → simulateKeyDown
    if (!_currentlyDown.contains(action)) {
      _currentlyDown.add(action);
      await keyPressSimulator.simulateKeyDown(key);
    }
  
    // (Re)déclenche le timer pour simulateKeyUp
    _releaseTimers[action]?.cancel(); // stop ancien timer
  
    _releaseTimers[action] = Timer(const Duration(milliseconds: 300), () async {
      await keyPressSimulator.simulateKeyUp(key);
      _currentlyDown.remove(action);
      _releaseTimers.remove(action);
    });
  
    return 'Handled action: ${key.debugName}';
}


  // Méthode pour le relâchement de touche (keyup)
  Future<String> releaseAction(ZwiftButton action) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: $action');
    }

    if (keyPair.physicalKey != null) {
      await keyPressSimulator.simulateKeyUp(keyPair.physicalKey); // debug, remettre await keyPressSimulator.simulateKeyUp(keyPair.physicalKey); ensuite
      return 'Key up: ${keyPair.logicalKey?.keyLabel}';
    } else {
      return 'No physical key to release';
    }
  }
}
