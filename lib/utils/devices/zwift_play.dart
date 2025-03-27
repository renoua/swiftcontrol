import 'dart:typed_data';

import 'package:swift_play/utils/devices/zwift_click.dart';
import 'package:swift_play/utils/messages/controller_notification.dart';

class ZwiftPlay extends ZwiftClick {
  ZwiftPlay(super.scanResult);

  ControllerNotification? _lastControllerNotification;

  @override
  void processClickNotification(Uint8List message) {
    final ControllerNotification clickNotification = ControllerNotification(message);
    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      actionStreamInternal.add(clickNotification.toString());
    }
    _lastControllerNotification = clickNotification;
  }
}
