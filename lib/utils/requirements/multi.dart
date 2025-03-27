import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/pages/scan.dart';
import 'package:swift_control/utils/requirements/platform.dart';

class KeyboardRequirement extends PlatformRequirement {
  KeyboardRequirement() : super('Keyboard access');

  @override
  Future<void> call() async {
    return keyPressSimulator.requestAccess(onlyOpenPrefPane: Platform.isMacOS);
  }

  @override
  Future<void> getStatus() async {
    status = await keyPressSimulator.isAccessAllowed();
  }
}

class BluetoothTurnedOn extends PlatformRequirement {
  BluetoothTurnedOn() : super('Bluetooth turned on');

  @override
  Future<void> call() async {
    return FlutterBluePlus.turnOn();
  }

  @override
  Future<void> getStatus() async {
    status = FlutterBluePlus.adapterStateNow != BluetoothAdapterState.off;
  }
}

class UnsupportedPlatform extends PlatformRequirement {
  UnsupportedPlatform() : super('Unsupported platform :(') {
    status = false;
  }

  @override
  Future<void> call() async {}

  @override
  Future<void> getStatus() async {}
}

class BluetoothScanning extends PlatformRequirement {
  BluetoothScanning() : super('Bluetooth Scanning') {
    status = false;
  }

  @override
  Future<void> call() async {}

  @override
  Future<void> getStatus() async {}

  @override
  Widget? build(BuildContext context) {
    return ScanWidget();
  }
}
