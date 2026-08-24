import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:jiandi/features/experience/data/local_tour_store.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
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
    await store.saveJson('offline_package_route-a', {
      'data': {'package_version': 'v1'}
    });
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
    expect(
      (await store.readJson('offline_package_route-a'))?['data'],
      {'package_version': 'v1'},
    );
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

  test(
      'prepared audio clearing removes files and rows but preserves private state',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('jiandi-cache-clear-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = SqliteTourStore(
      databasePath: paths.join(directory.path, 'tour.db'),
    );
    final firstFile = File(paths.join(directory.path, 'first.m4a'));
    final secondFile = File(paths.join(directory.path, 'second.m4a'));
    await firstFile.writeAsBytes([1]);
    await secondFile.writeAsBytes([2]);
    await store.saveJson('active_tour', {'journey_id': 'journey-1'});
    await store.enqueue(const OutboxEvent(
      id: 'evidence-1',
      type: 'evidence',
      payload: {'journey_id': 'journey-1'},
    ));
    await store.savePreparedAsset('audio-1', firstFile.path, 'v1', 1);
    await store.savePreparedAsset('audio-2', secondFile.path, 'v1', 1);
    final service = PreparedRouteService(Dio(), store);

    final result = await service.clearPreparedAudio();

    expect(result.removedCount, 2);
    expect(result.isComplete, isTrue);
    expect(await firstFile.exists(), isFalse);
    expect(await secondFile.exists(), isFalse);
    expect(await store.preparedAssets(), isEmpty);
    expect((await store.readJson('active_tour'))?['journey_id'], 'journey-1');
    expect((await store.pending()).single.id, 'evidence-1');
    expect((await service.clearPreparedAudio()).removedCount, 0);
  });

  test('partial file failure keeps only the failed cache index row', () async {
    final store = _PreparedStore([
      const PreparedAssetRecord(
        url: 'audio-ok',
        path: '/cache/ok.m4a',
        version: 'v1',
        sizeBytes: 1,
      ),
      const PreparedAssetRecord(
        url: 'audio-fail',
        path: '/cache/fail.m4a',
        version: 'v1',
        sizeBytes: 1,
      ),
    ]);
    final service = PreparedRouteService(
      Dio(),
      store,
      fileSystem: const _PartiallyFailingFiles(),
    );

    final result = await service.clearPreparedAudio();

    expect(result.removedCount, 1);
    expect(result.failedPaths, ['/cache/fail.m4a']);
    expect((await store.preparedAssets()).single.url, 'audio-fail');
  });
}

class _PartiallyFailingFiles implements PreparedFileSystem {
  const _PartiallyFailingFiles();

  @override
  Future<void> delete(String path) async {
    if (path.contains('fail')) throw FileSystemException('locked', path);
  }

  @override
  Future<bool> exists(String path) async => true;
}

class _PreparedStore implements TourStore {
  _PreparedStore(List<PreparedAssetRecord> values) : values = [...values];

  final List<PreparedAssetRecord> values;

  @override
  Future<List<PreparedAssetRecord>> preparedAssets() async => [...values];

  @override
  Future<void> removePreparedAsset(String url) async =>
      values.removeWhere((item) => item.url == url);

  @override
  Future<void> acknowledge(String id) async {}

  @override
  Future<void> clearPrivateData() async {}

  @override
  Future<void> enqueue(OutboxEvent event) async {}

  @override
  Future<List<OutboxEvent>> pending() async => const [];

  @override
  Future<String?> preparedAsset(
          String url, String version, int sizeBytes) async =>
      null;

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => null;

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {}

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}
