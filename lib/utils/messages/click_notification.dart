import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

class ClickNotification {
  static const int BTN_PRESSED = 0;

  static const String UP_NAME = "Plus";
  static const String DOWN_NAME = "Minus";

  bool buttonUpPressed = false;
  bool buttonDownPressed = false;

  ClickNotification(Uint8List message) {
    final input = CodedBufferReader(message);
    while (true) {
      final tag = input.readTag();
      final type = getTagWireType(tag);
      if (tag == 0 || type == WIRETYPE_END_GROUP) break;
      final number = getTagFieldNumber(tag);
      switch (type) {
        case WIRETYPE_VARINT:
          final value = input.readInt64().toInt();
          switch (number) {
            case 1:
              buttonUpPressed = value == BTN_PRESSED;
              break;
            case 2:
              buttonDownPressed = value == BTN_PRESSED;
              break;
            default:
              throw InvalidProtocolBufferException.invalidEndTag();
          }
          break;
        default:
          throw InvalidProtocolBufferException.invalidWireType();
      }
    }
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
