import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery location remains one-shot and isolated from journey tracking',
      () {
    final source = File(
      'lib/features/experience/data/platform_discovery_location.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/features/experience/presentation/discovery_controller.dart',
    ).readAsStringSync();

    expect(source, contains('getCurrentPosition'));
    expect(source, isNot(contains('getPositionStream')));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('runtimeLog')));
    expect(source, isNot(contains('Dio')));
    expect(controller, isNot(contains('locationModeControllerProvider')));
    expect(controller, isNot(contains('triggerLocationSourceProvider')));
  });

  test('iOS purpose string explains discovery without claiming persistence',
      () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('识别首次展示的城市'));
    expect(plist, contains('排列附近景点'));
    expect(plist, contains('不会保存连续位置轨迹'));
  });
}
