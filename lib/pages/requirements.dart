import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/platform.dart';

import 'device.dart';

class RequirementsPage extends StatefulWidget {
  const RequirementsPage({super.key});

  @override
  State<RequirementsPage> createState() => _RequirementsPageState();
}

class _RequirementsPageState extends State<RequirementsPage> {
  int _currentStep = 0;

  List<PlatformRequirement> _requirements = [];

  @override
  void initState() {
    super.initState();

    // call after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadRequirements();
    });

    connection.hasDevices.addListener(() {
      if (connection.hasDevices.value) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => DevicePage()));
      }
    });
  }

  @override
  dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SwiftControl'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body:
          _requirements.isEmpty
              ? Center(child: CircularProgressIndicator())
              : Stepper(
                currentStep: _currentStep,
                onStepContinue:
                    _currentStep < _requirements.length
                        ? () {
                          setState(() {
                            _currentStep += 1;
                          });
                        }
                        : null,
                onStepTapped: (step) {
                  setState(() {
                    _currentStep = step;
                  });
                },
                steps:
                    _requirements
                        .mapIndexed(
                          (index, req) => Step(
                            title: Text(req.name),
                            content:
                                (index == _currentStep ? req.build(context) : null) ??
                                ElevatedButton(onPressed: () => _callRequirement(req), child: Text(req.name)),
                            state: req.status ? StepState.complete : StepState.indexed,
                          ),
                        )
                        .toList(),
              ),
    );
  }

  void _callRequirement(PlatformRequirement req) {
    req.call().then((_) {
      _reloadRequirements();
    });
  }

  void _reloadRequirements() {
    getRequirements().then((req) {
      _requirements = req;
      _currentStep = req.indexWhere((req) => !req.status);
      if (mounted) {
        setState(() {});
      }
    });
  }
}
