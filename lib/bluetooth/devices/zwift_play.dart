import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/play_notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../ble.dart';

class ZwiftPlay extends BaseDevice {
  ZwiftPlay(super.scanResult);

  PlayNotification? _lastControllerNotification;

  // État de la gâchette analogique, conservé d'une trame à l'autre pour
  // calculer l'hystérésis presse/relâche (voir PlayNotification).
  bool _paddleActive = false;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  Future<List<ZwiftButton>?> processClickNotification(Uint8List message) async {
    final PlayNotification clickNotification = PlayNotification(
      message,
      previousPaddleActive: _paddleActive,
      pressThreshold: settings.paddlePressThreshold,
      releaseThreshold: settings.paddleReleaseThreshold,
    );
    _paddleActive = clickNotification.paddleActive;

    if (kDebugMode) {
      // Instrumentation (étape 0 du plan) : valeur brute + état calculé pour
      // calibrer les seuils sans deviner. Volontairement émis même quand la
      // notification est ensuite dédoublonnée ci-dessous.
      print(
        '[Play] analogLR=${clickNotification.analogLR} paddleActive=$_paddleActive '
        'buttons=${clickNotification.buttonsClicked.map((e) => e.name).toList()}',
      );
    }

    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;

      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }

      return clickNotification.buttonsClicked;
    } else {
      return null;
    }
  }

  @override
  void resetNotificationState() {
    _lastControllerNotification = null;
    _paddleActive = false;
  }
}
