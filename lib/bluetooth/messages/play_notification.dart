import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/protocol/zwift.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class PlayNotification extends BaseNotification {
  late final List<ZwiftButton> buttonsClicked;

  /// Valeur brute du champ analogique de la gâchette (protobuf `Analog_LR`),
  /// exposée pour le diagnostic (LogViewer / instrumentation) et pour piloter
  /// l'hystérésis d'un appel à l'autre.
  late final int analogLR;

  /// État de la gâchette (pressée/relâchée) après application de l'hystérésis
  /// presse/relâche. À réinjecter comme `previousPaddleActive` à la prochaine
  /// trame pour que le calcul reste cohérent d'un appel à l'autre.
  late final bool paddleActive;

  PlayNotification(
    Uint8List message, {
    required bool previousPaddleActive,
    required int pressThreshold,
    required int releaseThreshold,
  }) {
    final status = PlayKeyPadStatus.fromBuffer(message);
    analogLR = status.analogLR;

    final magnitude = analogLR.abs();
    // Hystérésis : une fois la gâchette engagée, elle reste "pressée" tant que
    // la valeur ne redescend pas sous le seuil de relâche (plus bas que le
    // seuil d'appui). Ça évite le chatter d'un relâchement progressif qui
    // traverserait un seuil unique en oscillant, et permet de détecter une
    // gâchette tirée à mi-course une fois qu'elle a franchi le seuil d'appui.
    paddleActive = previousPaddleActive ? magnitude >= releaseThreshold : magnitude >= pressThreshold;

    buttonsClicked = [
      if (status.rightPad == PlayButtonStatus.ON) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButton.y,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButton.z,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButton.a,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButton.b,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButton.onOffRight,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButton.sideButtonRight,
        if (paddleActive) ZwiftButton.paddleRight,
      ],
      if (status.rightPad == PlayButtonStatus.OFF) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButton.navigationUp,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButton.navigationLeft,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButton.navigationRight,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButton.navigationDown,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButton.onOffLeft,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButton.sideButtonLeft,
        if (paddleActive) ZwiftButton.paddleLeft,
      ],
    ];
  }

  @override
  String toString() {
    return 'Buttons: ${buttonsClicked.joinToString(transform: (e) => e.name)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayNotification &&
          runtimeType == other.runtimeType &&
          buttonsClicked.contentEquals(other.buttonsClicked);

  @override
  int get hashCode => Object.hashAll(buttonsClicked);
}
