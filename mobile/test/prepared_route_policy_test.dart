import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/data/user_preferences_repository.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';

void main() {
  test('manual and wifi-only policies skip only route pre-download', () async {
    final mobile = _Connectivity([ConnectivityResult.mobile]);
    final manual = PreparedRouteService(
      Dio(),
      _MemoryStore(),
      connectivity: mobile,
      downloadPolicy: () async => DownloadPolicy.manual,
    );
    await expectLater(
      manual.prepare(_emptyManifest, null),
      throwsA(isA<RoutePreparationSkipped>().having(
        (error) => error.message,
        'message',
        contains('在线播放'),
      )),
    );
    expect(mobile.calls, 0);

    final wifiOnly = PreparedRouteService(
      Dio(),
      _MemoryStore(),
      connectivity: mobile,
      downloadPolicy: () async => DownloadPolicy.wifiOnly,
    );
    await expectLater(
      wifiOnly.prepare(_emptyManifest, null),
      throwsA(isA<RoutePreparationSkipped>().having(
        (error) => error.message,
        'message',
        contains('按需联网'),
      )),
    );
    expect(mobile.calls, 1);
  });

  test('any-network bypasses transport gating and wifi permits preparation',
      () async {
    final noNetwork = _Connectivity([ConnectivityResult.none]);
    final anyNetwork = PreparedRouteService(
      Dio(),
      _MemoryStore(),
      connectivity: noNetwork,
      downloadPolicy: () async => DownloadPolicy.anyNetwork,
    );
    expect(await anyNetwork.prepare(_emptyManifest, null), isEmpty);
    expect(noNetwork.calls, 0);

    final wifi = _Connectivity([ConnectivityResult.wifi]);
    final wifiOnly = PreparedRouteService(
      Dio(),
      _MemoryStore(),
      connectivity: wifi,
      downloadPolicy: () async => DownloadPolicy.wifiOnly,
    );
    expect(await wifiOnly.prepare(_emptyManifest, null), isEmpty);
    expect(wifi.calls, 1);
  });

  test('explicit package lookup reuses only checksum-verified player files',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('jiandi-prepared-checksum-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fragment.m4a');
    final bytes = [1, 2, 3, 4];
    await file.writeAsBytes(bytes);
    final checksum = sha256.convert(bytes).toString();
    final service = PreparedRouteService(
      Dio(),
      _ExistingStore(file.path),
    );

    expect(
      await service.preparedPaths(
        _manifestWithChecksum(checksum),
        null,
        requireChecksum: true,
      ),
      {'fragment-a': file.path},
    );
    expect(
      await service.preparedPaths(
        _manifestWithChecksum(List.filled(64, '0').join()),
        null,
        requireChecksum: true,
      ),
      isNull,
    );
  });
}

AudioTourManifest _manifestWithChecksum(String checksum) => AudioTourManifest(
      title: '测试路线',
      centralQuestion: '为什么？',
      scriptVersion: 'v1',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: null,
      contentMethod: '测试',
      downloadSizeBytes: 4,
      fragments: [
        StoryFragment(
          id: 'fragment-a',
          position: 1,
          safePreview: '线索',
          interactionType: 'passive',
          reviewState: 'reviewed',
          triggerRegion: const TriggerRegion(
            latitude: 22.5,
            longitude: 114,
            entryRadiusM: 50,
            exitRadiusM: 80,
            maxAccuracyM: 35,
            qualifyingSamples: 2,
            sampleWindowSeconds: 15,
            cooldownSeconds: 120,
            auditState: 'reviewed',
          ),
          audio: NarrationAsset(
            url: 'https://cdn.example.test/fragment.m4a',
            mimeType: 'audio/mp4',
            sizeBytes: 4,
            scriptVersion: 'v1',
            checksumSha256: checksum,
          ),
        ),
      ],
    );

class _Connectivity implements ConnectivityReader {
  _Connectivity(this.result);

  final List<ConnectivityResult> result;
  int calls = 0;

  @override
  Future<List<ConnectivityResult>> current() async {
    calls += 1;
    return result;
  }
}

class _MemoryStore implements TourStore {
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
  Future<List<PreparedAssetRecord>> preparedAssets() async => const [];

  @override
  Future<void> removePreparedAsset(String url) async {}

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => null;

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {}

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}

class _ExistingStore extends _MemoryStore {
  _ExistingStore(this.path);

  final String path;

  @override
  Future<String?> preparedAsset(
          String url, String version, int sizeBytes) async =>
      path;
}

const _emptyManifest = AudioTourManifest(
  title: '空路线',
  centralQuestion: '测试？',
  scriptVersion: 'v1',
  reviewState: 'reviewed',
  fieldAuditState: 'reviewed',
  productionReady: true,
  demoLabel: null,
  contentMethod: '测试',
  downloadSizeBytes: 0,
  fragments: [],
);
