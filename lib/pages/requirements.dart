import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_play/pages/device.dart';
import 'package:swift_play/pages/scan.dart';

class RequirementsPage extends StatefulWidget {
  const RequirementsPage({super.key});

  @override
  State<RequirementsPage> createState() => _RequirementsPageState();
}

class _RequirementsPageState extends State<RequirementsPage> {
  late final StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  StepState _bluetoothStepState = StepState.indexed;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();

    _adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _bluetoothStepState = state != BluetoothAdapterState.off ? StepState.complete : StepState.indexed;
      if (_bluetoothStepState == StepState.complete) {
        _currentStep = 1;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  dispose() {
    super.dispose();
    _adapterStateStateSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Swift Play'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep <= 2) {
            setState(() {
              _currentStep += 1;
            });
          }
        },
        onStepTapped: (step) {
          setState(() {
            _currentStep = step;
          });
        },
        steps: [
          Step(
            title: Text('Bluetooth turned on'),
            content: ElevatedButton(
              onPressed: () {
                FlutterBluePlus.turnOn();
              },
              child: Text('Turn bluetooth on'),
            ),
            state: _bluetoothStepState,
          ),
          Step(
            title: Text('Accessibility service activated'),
            content: ElevatedButton(onPressed: () {}, child: Text('Turn Accessibility service on')),
          ),
          Step(
            title: Text('Scan for devices'),
            content:
                _currentStep != 2
                    ? CircularProgressIndicator()
                    : ScanWidget(
                      onDeviceSelected: (device) {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => DevicePage(bleDevice: device)));
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
