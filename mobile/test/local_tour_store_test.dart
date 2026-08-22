import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/local_tour_store.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('snapshot and outbox survive store recreation', () async {
    final directory =
        await Directory.systemTemp.createTemp('jiandi-store-test-');
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = paths.join(directory.path, 'tour.db');
    final first = SqliteTourStore(databasePath: databasePath);
    await first.saveJson('active_tour', {'journey_id': 'journey-1'});
    await first.enqueue(
      const OutboxEvent(
        id: 'event-1',
        type: 'playback',
        payload: {'progress': 1.0},
      ),
    );

    final restored = SqliteTourStore(databasePath: databasePath);
    expect(
        (await restored.readJson('active_tour'))?['journey_id'], 'journey-1');
    expect((await restored.pending()).single.id, 'event-1');
    await restored.acknowledge('event-1');
    expect(await restored.pending(), isEmpty);
  });

  test('account change clears private state but keeps reusable public audio',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('jiandi-account-switch-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = SqliteTourStore(
      databasePath: paths.join(directory.path, 'tour.db'),
    );
    await store.saveJson('active_tour', {'journey_id': 'tester-a-journey'});
    await store.enqueue(
      const OutboxEvent(
        id: 'tester-a-photo',
        type: 'evidence',
        payload: {'journey_id': 'tester-a-journey'},
      ),
    );
    await store.savePreparedAsset(
      'https://cdn.example.test/public/audio.m4a',
      '/tmp/public-audio.m4a',
      'v1',
      128,
    );

    await store.clearPrivateData();

    expect(await store.readJson('active_tour'), isNull);
    expect(await store.pending(), isEmpty);
    expect(
      await store.preparedAsset(
        'https://cdn.example.test/public/audio.m4a',
        'v1',
        128,
      ),
      '/tmp/public-audio.m4a',
    );
  });
}
