import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_play/utils/ble.dart';
import 'package:swift_play/utils/ble_device.dart';
import 'package:swift_play/widgets/small_progress_indicator.dart';

class ScanWidget extends StatefulWidget {
  final void Function(BleDevice) onDeviceSelected;

  const ScanWidget({super.key, required this.onDeviceSelected});

  @override
  State<ScanWidget> createState() => _ScanWidgetState();
}

class _ScanWidgetState extends State<ScanWidget> {
  List<BleDevice> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        _scanResults = results.map(BleDevice.new).toList();
        if (mounted) {
          setState(() {});
        }
      },
      onError: (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
      },
    );

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });

    // after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onScanPressed();
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID],
      );
    } catch (e, backtrace) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e, backtrace) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(Duration(milliseconds: 500));
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return ElevatedButton(onPressed: onStopPressed, child: const Icon(Icons.stop));
    } else {
      return ElevatedButton(onPressed: onScanPressed, child: const Text("SCAN"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 200),
      child: ListView(
        padding: EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          if (_isScanning) SmallProgressIndicator() else buildScanButton(context),
          ..._scanResults.map(
            (r) => ListTile(
              title: Text(r.scanResult.device.platformName),
              subtitle: Text(r.type?.toString() ?? 'Unknown'),
              onTap: () {
                widget.onDeviceSelected(r);
              },
            ),
          ),
        ],
      ),
    );
  }
}
