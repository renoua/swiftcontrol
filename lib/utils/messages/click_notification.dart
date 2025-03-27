import 'dart:typed_data';

import '../../protocol/zwift.pb.dart';

class ClickNotification {
  static const int BTN_PRESSED = 0;

  bool buttonUpPressed = false;
  bool buttonDownPressed = false;

  ClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    buttonUpPressed = status.buttonPlus.value == BTN_PRESSED;
    buttonDownPressed = status.buttonMinus.value == BTN_PRESSED;
  }

  @override
  String toString() {
    var text = "ClickNotification(";
    text += buttonUpPressed ? 'Plus' : "";
    text += buttonDownPressed ? 'Minus' : "";
    text += ")";
    return text;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClickNotification &&
          runtimeType == other.runtimeType &&
          buttonUpPressed == other.buttonUpPressed &&
          buttonDownPressed == other.buttonDownPressed;

  @override
  int get hashCode => buttonUpPressed.hashCode ^ buttonDownPressed.hashCode;
}
