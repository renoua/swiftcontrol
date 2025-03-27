import 'package:accessibility/accessibility.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/utils/connection.dart';

import 'utils/actions/base_actions.dart';

final connection = Connection();
final actionHandler = ActionHandler();
final accessibilityHandler = Accessibility();

void main() {
  runApp(const SwiftPlayApp());
}

class SwiftPlayApp extends StatelessWidget {
  const SwiftPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftControl',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const RequirementsPage(),
    );
  }
}
