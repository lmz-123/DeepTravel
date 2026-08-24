import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/data/route_offline_package_service.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';

void main() {
  test('installs canonical manifest through the shared prepared cache',
      () async {
    final store = _MemoryStore();
    final raw = _package();
    final dio = _dio(raw);
    final prepared = _PreparedRoutes(store);
    final service = RouteOfflinePackageService(dio, store, prepared);
    final progress = <String>[];

    final installed = await service.install(
      'route-a',
      onProgress: (complete, total) => progress.add('$complete/$total'),
    );

    expect(prepared.explicitCalls, 1);
    expect(progress, ['1/1']);
    expect(installed.version, 'v1');
    expect(installed.route.audioTour!.fragments.single.transcript, '完整文字稿');
    expect((await service.load('route-a'))?.preparedPaths, {
      'fragment-a': '/cache/fragment-a.m4a',
    });
    expect(
        (await service.status('route-a')).phase, OfflinePackagePhase.complete);
    final stale = await service.status('route-a', currentVersion: 'v2');
    expect(stale.phase, OfflinePackagePhase.stale);
    expect(stale.message, contains('新版本'));
  });

  test('rejects a changed manifest before preparing audio', () async {
    final store = _MemoryStore();
    final raw = _package()..['package_version'] = 'tampered';
    final prepared = _PreparedRoutes(store);
    final service = RouteOfflinePackageService(_dio(raw), store, prepared);

    await expectLater(
      service.install('route-a'),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('完整性校验失败'),
      )),
    );
    expect(prepared.explicitCalls, 0);
    expect(await service.load('route-a'), isNull);
  });

  test('removes one package and its selected prepared audio', () async {
    final store = _MemoryStore();
    final prepared = _PreparedRoutes(store);
    final service = RouteOfflinePackageService(
      _dio(_package()),
      store,
      prepared,
    );
    await service.install('route-a');

    final result = await service.remove('route-a');

    expect(result.isComplete, isTrue);
    expect(prepared.removedUrls, {'https://cdn.example.test/fragment-a.m4a'});
    expect(await service.installedPackages(), isEmpty);
    expect(await service.load('route-a'), isNull);
  });

  test('keeps prepared audio shared by another installed package', () async {
    final store = _MemoryStore();
    final prepared = _PreparedRoutes(store);
    final packages = {
      'route-a': _package('route-a'),
      'route-b': _package('route-b'),
    };
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final slug = options.path.split('/')[2];
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'data': packages[slug]},
        ));
      },
    ));
    final service = RouteOfflinePackageService(dio, store, prepared);
    await service.install('route-a');
    await service.install('route-b');

    await service.remove('route-a');

    expect(prepared.removedUrls, isEmpty);
    expect(
      (await service.installedPackages()).map((item) => item.route.slug),
      ['route-b'],
    );
  });
}

Dio _dio(Map<String, dynamic> raw) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {'data': raw},
    )),
  ));
  return dio;
}

Map<String, dynamic> _package([String slug = 'route-a']) {
  final raw = <String, dynamic>{
    'package_version': 'v1',
    'city': {
      'id': 'city-a',
      'slug': 'city-a',
      'name': '测试城',
      'subtitle': '测试',
      'hero_image': '',
    },
    'route': {
      'id': slug,
      'slug': slug,
      'title': '测试路线',
      'subtitle': '测试',
      'description': '测试路线',
      'duration_minutes': 20,
      'distance_km': 1.2,
      'difficulty': '轻松',
      'theme': '历史',
      'hero_image': '',
      'content_status': 'published',
      'stops': <dynamic>[],
      'audio_tour': {
        'title': '测试路线',
        'central_question': '为什么？',
        'script_version': 'v1',
        'review_state': 'reviewed',
        'field_audit_state': 'reviewed',
        'production_ready': true,
        'demo_label': null,
        'content_method': '测试',
        'download_size_bytes': 4,
        'fragments': [
          {
            'id': 'fragment-a',
            'position': 1,
            'safe_preview': '第一条线索',
            'interaction_type': 'passive',
            'review_state': 'reviewed',
            'trigger_region': {
              'latitude': 22.5,
              'longitude': 114.0,
              'entry_radius_m': 50,
              'exit_radius_m': 80,
              'max_accuracy_m': 35,
              'qualifying_samples': 2,
              'sample_window_seconds': 15,
              'cooldown_seconds': 120,
              'audit_state': 'reviewed',
            },
            'audio': {
              'url': 'https://cdn.example.test/fragment-a.m4a',
              'mime_type': 'audio/mp4',
              'size_bytes': 4,
              'script_version': 'v1',
              'checksum_sha256': sha256.convert([1, 2, 3, 4]).toString(),
            },
            'title': '第一条线索',
            'transcript': '完整文字稿',
            'state': 'undiscovered',
          },
        ],
      },
    },
  };
  raw['package_checksum_sha256'] =
      sha256.convert(utf8.encode(jsonEncode(_canonical(raw)))).toString();
  return raw;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonical(value[key]),
    };
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

class _PreparedRoutes extends PreparedRouteService {
  _PreparedRoutes(TourStore store) : super(Dio(), store);

  int explicitCalls = 0;
  Set<String>? removedUrls;

  @override
  Future<Map<String, String>> prepareExplicit(
    AudioTourManifest manifest,
    String? profileId, {
    void Function(int complete, int total)? onProgress,
  }) async {
    explicitCalls += 1;
    onProgress?.call(1, 1);
    return {'fragment-a': '/cache/fragment-a.m4a'};
  }

  @override
  Future<Map<String, String>?> preparedPaths(
    AudioTourManifest manifest,
    String? profileId, {
    bool requireChecksum = false,
  }) async =>
      {'fragment-a': '/cache/fragment-a.m4a'};

  @override
  Future<PreparedAudioClearResult> clearPreparedAudioUrls(
    Set<String> urls,
  ) async {
    removedUrls = urls;
    return PreparedAudioClearResult(
      removedCount: urls.length,
      failedPaths: const [],
    );
  }
}

class _MemoryStore implements TourStore {
  final snapshots = <String, Map<String, dynamic>>{};

  @override
  Future<void> acknowledge(String id) async {}

  @override
  Future<void> clearPrivateData() async => snapshots.clear();

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
  Future<Map<String, dynamic>?> readJson(String key) async => snapshots[key];

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async =>
      snapshots[key] = value;

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}
