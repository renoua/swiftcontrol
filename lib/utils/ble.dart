import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleUuid {
  static final ZWIFT_CUSTOM_SERVICE_UUID = Guid("00000001-19CA-4651-86E5-FA29DCDD09D1");
  static final ZWIFT_ASYNC_CHARACTERISTIC_UUID = Guid("00000002-19CA-4651-86E5-FA29DCDD09D1");
  static final ZWIFT_SYNC_RX_CHARACTERISTIC_UUID = Guid("00000003-19CA-4651-86E5-FA29DCDD09D1");
  static final ZWIFT_SYNC_TX_CHARACTERISTIC_UUID = Guid("00000004-19CA-4651-86E5-FA29DCDD09D1");
}

class Constants {
  static const ZWIFT_MANUFACTURER_ID = 2378; // Zwift, Inc

  // Zwift Play = RC1
  static const RC1_LEFT_SIDE = 0x03;
  static const RC1_RIGHT_SIDE = 0x02;

  // Zwift Click = BC1
  static const BC1 = 0x09;

  static final RIDE_ON = Uint8List.fromList([82, 105, 100, 101, 79, 110]);

  // these don't actually seem to matter, its just the header has to be 7 bytes RIDEON + 2
  static final REQUEST_START = Uint8List.fromList([0, 9]); //byteArrayOf(1, 2)
  static final RESPONSE_START = Uint8List.fromList([1, 3]); // from device

  // Message types received from device
  static const CONTROLLER_NOTIFICATION_MESSAGE_TYPE = 07;
  static const EMPTY_MESSAGE_TYPE = 21;
  static const BATTERY_LEVEL_TYPE = 25;

  // not figured out the protobuf type this really is, the content is just two varints.
  static const int CLICK_NOTIFICATION_MESSAGE_TYPE = 55;

  // see this if connected to Core then Zwift connects to it. just one byte
  static const DISCONNECT_MESSAGE_TYPE = 0xFE;
}

enum DeviceType {
  click,
  ride,
  playLeft,
  playRight;

  @override
  String toString() {
    return super.toString().split('.').last;
  }

  // add constructor
  static DeviceType? fromManufacturerData(int data) {
    switch (data) {
      case Constants.BC1:
        return DeviceType.click;
      case Constants.RC1_LEFT_SIDE:
        return DeviceType.playLeft;
      case Constants.RC1_RIGHT_SIDE:
        return DeviceType.playRight;
    }
    return null;
  }
}
