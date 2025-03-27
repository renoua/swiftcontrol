import 'dart:typed_data';

import '../../protocol/zwift.pb.dart';

class ControllerNotification {
  static const int BTN_PRESSED = 0;

  late bool rightPad, buttonY, buttonZ, buttonA, buttonB, buttonOn, buttonShift;
  late int analogLR, analogUD;

  ControllerNotification(Uint8List message) {
    final status = PlayKeyPadStatus.fromBuffer(message);

    rightPad = status.rightPad.value == BTN_PRESSED;
    buttonY = status.buttonYUp.value == BTN_PRESSED;
    buttonZ = status.buttonZLeft.value == BTN_PRESSED;
    buttonA = status.buttonARight.value == BTN_PRESSED;
    buttonB = status.buttonBDown.value == BTN_PRESSED;
    buttonOn = status.buttonOn.value == BTN_PRESSED;
    buttonShift = status.buttonShift.value == BTN_PRESSED;
    analogLR = status.analogLR;
    analogUD = status.analogUD;
  }

  @override
  String toString() {
    return 'ControllerNotification{rightPad: $rightPad, buttonY: $buttonY, buttonZ: $buttonZ, buttonA: $buttonA, buttonB: $buttonB, buttonOn: $buttonOn, buttonShift: $buttonShift, analogLR: $analogLR, analogUD: $analogUD}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerNotification &&
          runtimeType == other.runtimeType &&
          rightPad == other.rightPad &&
          buttonY == other.buttonY &&
          buttonZ == other.buttonZ &&
          buttonA == other.buttonA &&
          buttonB == other.buttonB &&
          buttonOn == other.buttonOn &&
          buttonShift == other.buttonShift &&
          analogLR == other.analogLR &&
          analogUD == other.analogUD;

  @override
  int get hashCode =>
      rightPad.hashCode ^
      buttonY.hashCode ^
      buttonZ.hashCode ^
      buttonA.hashCode ^
      buttonB.hashCode ^
      buttonOn.hashCode ^
      buttonShift.hashCode ^
      analogLR.hashCode ^
      analogUD.hashCode;
}
