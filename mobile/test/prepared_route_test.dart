import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/platform_tour_adapters.dart';

void main() {
  test('prepared audio requires an existing file with matching version size',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('jiandi-audio-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fragment.m4a');
    await file.writeAsBytes([1, 2, 3, 4]);
    expect(preparedFileExists(file.path, 4), isTrue);
    expect(preparedFileExists(file.path, 5), isFalse);
    expect(preparedFileExists('${directory.path}/missing.m4a', 4), isFalse);
  });
}
