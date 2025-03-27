import 'dart:io';

import 'package:flutter/foundation.dart';

import 'android.dart';
import 'desktop.dart';

abstract class BaseActions {
  void init() {}
  void increaseGear();
  void decreaseGear();
}

class StubActions extends BaseActions {
  @override
  void decreaseGear() {
    print('Decrease gear');
  }

  @override
  void increaseGear() {
    print('Increase gear');
  }
}

class ActionHandler {
  late BaseActions actions;

  ActionHandler() {
    if (kIsWeb) {
      actions = StubActions();
    } else if (Platform.isAndroid) {
      actions = AndroidActions();
    } else {
      actions = DesktopActions();
    }
  }

  void init() {
    actions.init();
  }

  void increaseGear() {
    actions.increaseGear();
  }

  void decreaseGear() {
    actions.decreaseGear();
  }
}
