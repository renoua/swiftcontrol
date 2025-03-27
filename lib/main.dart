import 'package:flutter/material.dart';
import 'package:swift_play/pages/requirements.dart';
import 'package:swift_play/utils/connection.dart';

final connection = Connection();

void main() {
  runApp(const SwiftPlayApp());
}

class SwiftPlayApp extends StatelessWidget {
  const SwiftPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zwift Play',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const RequirementsPage(),
    );
  }
}
