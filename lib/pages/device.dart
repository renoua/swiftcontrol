import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_play/utils/ble_device.dart';
import 'package:swift_play/widgets/small_progress_indicator.dart';

class DevicePage extends StatefulWidget {
  final BleDevice bleDevice;
  const DevicePage({super.key, required this.bleDevice});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  int? _rssi;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  BluetoothDevice get device => widget.bleDevice.scanResult.device;

  @override
  void initState() {
    super.initState();

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

  Future onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      _services = await device.discoverServices();
    } catch (e, backtrace) {
      ScaffoldMessenger.of(
        _snackBarMessengerKey.currentContext!,
      ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(8.0), child: Text('${device.remoteId}'));
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return SizedBox(
      width: 100,
      child: IndexedStack(
        index: (_isDiscoveringServices) ? 1 : 0,
        children: <Widget>[
          TextButton(onPressed: onDiscoverServicesPressed, child: const Text("Get Services")),
          const IconButton(icon: SmallProgressIndicator(), onPressed: null),
        ],
      ),
    );
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
          actions: [buildConnectButton(context)],
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: ListView(
          children: <Widget>[
            buildRemoteId(context),
            ListTile(
              leading: buildRssiTile(context),
              title: Text('Device is ${_connectionState.toString().split('.')[1]}.'),
              trailing: buildGetServices(context),
            ),
            ListTile(title: Text('Device type: ${widget.bleDevice.type}')),
          ],
        ),
      ),
    );
  }
}
