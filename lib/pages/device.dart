import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_play/utils/devices/ble_device.dart';

class DevicePage extends StatefulWidget {
  final BleDevice bleDevice;
  const DevicePage({super.key, required this.bleDevice});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  int? _rssi;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<String> _actions = [];

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  late StreamSubscription<String> _actionSubscription;
  BluetoothDevice get device => widget.bleDevice.scanResult.device;

  @override
  void initState() {
    super.initState();

    _actionSubscription = widget.bleDevice.actionStream.listen((data) {
      if (mounted) {
        setState(() {
          _actions.add('${DateTime.now().toString().split(" ").last}: $data');
          _actions = _actions.takeLast(30).toList();
        });
      }
    });
    _connectionStateSubscription = device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        //widget.bleDevice.setupServices();
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _actionSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();

  Future onConnectPressed() async {
    try {
      await widget.bleDevice.connect();
      ScaffoldMessenger.of(
        _snackBarMessengerKey.currentContext!,
      ).showSnackBar(SnackBar(content: Text('Connected'), duration: const Duration(seconds: 5)));
    } catch (e, backtrace) {
      if (e is FlutterBluePlusException && e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        ScaffoldMessenger.of(
          _snackBarMessengerKey.currentContext!,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
        print(e);
        print("backtrace: $backtrace");
      }
    }
  }

  Future onDisconnectPressed() async {
    try {
      await device.disconnect();
      ScaffoldMessenger.of(
        _snackBarMessengerKey.currentContext!,
      ).showSnackBar(SnackBar(content: Text('Disconnected'), duration: const Duration(seconds: 5)));
    } catch (e, backtrace) {
      ScaffoldMessenger.of(
        _snackBarMessengerKey.currentContext!,
      ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
      print("$e backtrace: $backtrace");
    }
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(
            (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _snackBarMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(device.platformName),
          actions: [
            buildConnectButton(context),
            IconButton(
              onPressed: () {
                _actions.clear();
                setState(() {});
              },
              icon: Icon(Icons.clear),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Device is ${_connectionState.toString().split('.')[1]}.'),
            ),
            Padding(padding: const EdgeInsets.all(8.0), child: Text('Device type: ${widget.bleDevice.toString()}')),
            Expanded(
              child: ListView(padding: EdgeInsets.all(8), children: _actions.map((action) => Text(action)).toList()),
            ),
          ],
        ),
      ),
    );
  }
}
