import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_play/main.dart';
import 'package:swift_play/utils/devices/ble_device.dart';

import '../utils/messages/notification.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  List<String> _actions = [];

  late StreamSubscription<BleDevice> _connectionStateSubscription;

  late StreamSubscription<BaseNotification> _actionSubscription;

  @override
  void initState() {
    super.initState();

    _actionSubscription = connection.actionStream.listen((data) {
      if (mounted) {
        setState(() {
          _actions.add('${DateTime.now().toString().split(" ").last}: $data');
          _actions = _actions.takeLast(30).toList();
        });
      }
    });
    _connectionStateSubscription = connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _actionSubscription.cancel();
    super.dispose();
  }

  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _snackBarMessengerKey,
      child: PopScope(
        onPopInvokedWithResult: (hello, _) {
          connection.reset();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('Swift Play'),
            actions: [
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
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Devices:\n${connection.devices.joinToString(separator: '\n', transform: (it) {
                    return "${it.device.platformName}: ${it.device.isConnected ? 'Connected' : 'Not connected'}";
                  })}',
                ),
                Expanded(child: ListView(children: _actions.map((action) => Text(action)).toList())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
