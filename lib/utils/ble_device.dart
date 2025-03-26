import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_play/utils/ble.dart';
import 'package:swift_play/utils/crypto/local_key_provider.dart';

import 'crypto/encryption_utils.dart';
import 'crypto/zap_crypto.dart';
import 'messages/click_notification.dart';

class BleDevice {
  final ScanResult scanResult;
  final zapEncryption = ZapCrypto(LocalKeyProvider());

  bool supportsEncryption = true;

  BleDevice(this.scanResult);

  DeviceType? get type {
    final manufacturerData = scanResult.advertisementData.manufacturerData;
    final data = manufacturerData[Constants.ZWIFT_MANUFACTURER_ID];
    if (data == null || data.isEmpty) {
      return null;
    }
    return DeviceType.fromManufacturerData(data.first);
  }

  BluetoothDevice get device => scanResult.device;
  final StreamController<String> _actionStream = StreamController<String>.broadcast();
  Stream<String> get actionStream => _actionStream.stream;

  Future<void> connect() async {
    await device.connect(autoConnect: false).timeout(const Duration(seconds: 3));

    var filteredStateStream = device.connectionState.where((s) => s == BluetoothConnectionState.connected);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothConnectionState> futureState = filteredStateStream.first;

    // wait for connection
    await futureState.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Failed to connect in time.');
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      await device.requestMtu(256);
    }

    await _handleServices();
  }

  Future<void> _handleServices() async {
    final services = await device.discoverServices();

    final customService = services.firstOrNullWhere((service) => service.uuid == BleUuid.ZWIFT_CUSTOM_SERVICE_UUID);

    if (customService == null) {
      throw Exception('Custom service not found');
    }

    final asyncCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
    );
    final syncTxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
    );
    final syncRxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    if (!asyncCharacteristic.isNotifying) {
      await asyncCharacteristic.setNotifyValue(true);
    }
    final asyncSubscription = asyncCharacteristic.lastValueStream.listen((onData) {
      _processCharacteristic('async', Uint8List.fromList(onData));
    });
    device.cancelWhenDisconnected(asyncSubscription);

    if (!syncTxCharacteristic.isNotifying) {
      await syncTxCharacteristic.setNotifyValue(true, forceIndications: !kIsWeb && Platform.isAndroid);
    }
    final syncSubscription = syncTxCharacteristic.lastValueStream.listen((onData) {
      _processCharacteristic('sync', Uint8List.fromList(onData));
    });
    device.cancelWhenDisconnected(syncSubscription);

    await _setupHandshake(syncRxCharacteristic);
  }

  Future<void> _setupHandshake(BluetoothCharacteristic syncRxCharacteristic) async {
    if (supportsEncryption) {
      await syncRxCharacteristic.write([
        ...Constants.RIDE_ON,
        ...Constants.REQUEST_START,
        ...zapEncryption.localKeyProvider.getPublicKeyBytes(),
      ], withoutResponse: true);
    } else {
      await syncRxCharacteristic.write(Constants.RIDE_ON, withoutResponse: true);
    }
  }

  void _processCharacteristic(String tag, Uint8List bytes) {
    if (kDebugMode) {
      print('Received $tag: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Received $tag: ${String.fromCharCodes(bytes)}');
    }

    if (bytes.isEmpty) {
      return;
    }

    if (bytes.startsWith(Uint8List.fromList([...Constants.RIDE_ON, ...Constants.RESPONSE_START]))) {
      processDevicePublicKeyResponse(bytes);
    } else if (bytes.startsWith(Constants.RIDE_ON)) {
      print("Empty RideOn response - unencrypted mode");
    } else if (!supportsEncryption || (bytes.length > Int32List.bytesPerElement + EncryptionUtils.MAC_LENGTH)) {
      processData(bytes);
    } else if (bytes[0] == Constants.DISCONNECT_MESSAGE_TYPE) {
      print("Disconnect message");
    } else {
      print("Unprocessed - Data Type: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }

  void processData(Uint8List bytes) {
    int type;
    Uint8List message;

    if (supportsEncryption) {
      final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
      final payload = bytes.sublist(4);

      final data = zapEncryption.decrypt(counter, payload);
      type = data[0];
      message = data.sublist(1);
    } else {
      type = bytes[0];
      message = bytes.sublist(1);
    }

    switch (type) {
      case Constants.EMPTY_MESSAGE_TYPE:
        print("Empty Message"); // expected when nothing happening
        break;
      case Constants.BATTERY_LEVEL_TYPE:
        print("Battery level update: $message");
        break;
      case Constants.CLICK_NOTIFICATION_MESSAGE_TYPE:
        final ClickNotification clickNotification = ClickNotification(message);
        if (clickNotification.buttonDownPressed || clickNotification.buttonUpPressed) {
          print("Click Notification: $clickNotification");
          _actionStream.add(clickNotification.toString());
        }
        break;
    }
  }

  void processDevicePublicKeyResponse(Uint8List bytes) {
    final devicePublicKeyBytes = bytes.sublist(Constants.RIDE_ON.length + Constants.RESPONSE_START.length);
    zapEncryption.initialise(devicePublicKeyBytes);
    if (true) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }
}
