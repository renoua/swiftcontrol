import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/platform.dart';

class AccessibilityRequirement extends PlatformRequirement {
  AccessibilityRequirement() : super('Allow Accessibility Service');

  @override
  Future<void> call() async {
    return accessibilityHandler.openPermissions();
  }

  @override
  Future<void> getStatus() async {
    status = await accessibilityHandler.hasPermission();
  }
}
