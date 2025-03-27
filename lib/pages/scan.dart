import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/ble.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

class ScanWidget extends StatefulWidget {
  const ScanWidget({super.key});

  @override
  State<ScanWidget> createState() => _ScanWidgetState();
}

class _ScanWidgetState extends State<ScanWidget> {
  bool _isScanning = false;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    connection.startScanning();

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
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID],
        webOptionalServices: kIsWeb ? [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID] : [],
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
        children: [if (_isScanning) SmallProgressIndicator() else buildScanButton(context)],
      ),
    );
  }
}
