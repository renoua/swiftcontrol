import 'package:flutter/services.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';

class DesktopActions extends BaseActions {
  @override
  void decreaseGear() {
    keyPressSimulator.simulateKeyDown(PhysicalKeyboardKey.keyI);
  }

  @override
  void increaseGear() {
    keyPressSimulator.simulateKeyDown(PhysicalKeyboardKey.keyK);
  }
}
