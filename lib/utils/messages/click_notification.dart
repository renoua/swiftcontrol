import 'dart:typed_data';

import '../../protocol/zwift.pb.dart';

class ClickNotification {
  static const int BTN_PRESSED = 0;

  static const String UP_NAME = "Plus";
  static const String DOWN_NAME = "Minus";

  bool buttonUpPressed = false;
  bool buttonDownPressed = false;

  ClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    buttonUpPressed = status.buttonPlus.value == BTN_PRESSED;
    buttonDownPressed = status.buttonMinus.value == BTN_PRESSED;
  }

  String diff(ClickNotification previousNotification) {
    var diff = "";
    diff += _diff(UP_NAME, buttonUpPressed, previousNotification.buttonUpPressed);
    diff += _diff(DOWN_NAME, buttonDownPressed, previousNotification.buttonDownPressed);
    return diff;
  }

  String _diff(String title, bool pressedValue, bool oldPressedValue) {
    if (pressedValue != oldPressedValue) {
      return "$title=${pressedValue ? "Pressed" : "Released"} ";
    }
    return "";
  }

  @override
  String toString() {
    var text = "ClickNotification(";
    text += buttonUpPressed ? UP_NAME : "";
    text += buttonDownPressed ? DOWN_NAME : "";
    text += ")";
    return text;
  }
}
