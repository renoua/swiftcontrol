import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_play/utils/ble.dart';

class BleDevice {
  final ScanResult scanResult;

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

    if (Platform.isAndroid) {
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
      _processCharacteristic('async', onData);
    });
    device.cancelWhenDisconnected(asyncSubscription);

    if (!syncTxCharacteristic.isNotifying) {
      await syncTxCharacteristic.setNotifyValue(true, forceIndications: Platform.isAndroid);
    }
    final syncSubscription = syncTxCharacteristic.lastValueStream.listen((onData) {
      _processCharacteristic('sync', onData);
    });
    device.cancelWhenDisconnected(syncSubscription);

    await _setupHandshake(syncRxCharacteristic);
  }

  Future<void> _setupHandshake(BluetoothCharacteristic syncRxCharacteristic) async {
    await syncRxCharacteristic.write(Constants.RIDE_ON, withoutResponse: true);
  }

  void _processCharacteristic(String tag, List<int> onData) {
    if (kDebugMode) {
      print('Received $tag: ${onData.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }
  }
}
