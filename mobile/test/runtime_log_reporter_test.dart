import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/logging/runtime_log_reporter.dart';

void main() {
  test('runtime log queue keeps the newest bounded events', () {
    final queue = List.generate(
        5, (index) => <String, dynamic>{'message': 'event-$index'});
    final bounded = boundRuntimeLogQueue(queue, 3);
    expect(bounded.map((item) => item['message']),
        ['event-2', 'event-3', 'event-4']);
    expect(queue, hasLength(5));
  });
}
