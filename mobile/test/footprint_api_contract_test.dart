import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';
import 'package:jiandi/features/experience/data/footprint_share_service.dart';
import 'package:jiandi/features/experience/domain/footprint_models.dart';

void main() {
  test('footprint API stays private, filterable and voice independent',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (options.responseType == ResponseType.bytes) {
        return handler.resolve(Response<List<int>>(
            requestOptions: options, statusCode: 200, data: [1, 2, 3]));
      }
      final data = switch (options.path) {
        '/footprints' => {
            'data': {
              'items': [_footprint],
              'next_cursor': null,
              'total': 1,
              'facets': {
                'cities': [
                  {'slug': 'shenzhen', 'name': '深圳', 'count': 1}
                ],
                'themes': [
                  {'name': '未来主题', 'count': 1}
                ],
              },
            }
          },
        '/footprints/footprint-1' => {'data': _footprint},
        '/footprints/footprint-1/photo' => {
            'data': _footprint['what_i_saw']['photo']
          },
        _ => throw StateError('${options.method} ${options.path}'),
      };
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data));
    }));
    final repository = ApiExperienceRepository(dio, _Auth(dio));
    final directory = await Directory.systemTemp.createTemp('footprint-api-');
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/private.jpg')..writeAsBytesSync([1]);

    final listing = await repository.footprints(const FootprintFilter(
      citySlug: 'shenzhen',
      theme: '未来主题',
      journeyState: 'partial',
    ));
    final detail = await repository.footprint('footprint-1');
    final updated = await repository.updateFootprint(
        'footprint-1', const FootprintDraft(sentence: '我记住了这处街角'));
    await repository.uploadFootprintPhoto('footprint-1', photo.path);
    final bytes =
        await repository.footprintPhotoBytes('footprint-1', detail.photo!);

    expect(listing.items.single.themes, ['未来主题']);
    expect(listing.cities.single.name, '深圳');
    expect(detail.editorialSummary, '新旧砖缝留下了城市变化的证据。');
    expect(updated.storyTitle, '旧城墙的一处细节');
    expect(bytes, [1, 2, 3]);
    expect(requests.first.queryParameters, containsPair('theme', '未来主题'));
    expect(requests.first.queryParameters,
        containsPair('journey_state', 'partial'));
    expect(
        requests.every((item) =>
            item.headers['Authorization'] == 'Bearer footprint-token'),
        isTrue);
    expect(requests.where((item) => item.method == 'POST').single.data,
        isA<FormData>());
    expect(_footprint.toString(), isNot(contains('audio')));
    expect(_footprint.toString(), isNot(contains('playback')));
    expect(_footprint.toString(), isNot(contains('voice')));
  });

  test('share renderer excludes private photo unless bytes are explicit',
      () async {
    // A malformed photo payload would throw if the default path attempted to decode it.
    final entry = FootprintEntry.fromJson(_footprint);
    final renderer = const _RendererFacade();
    final bytes = await renderer.renderWithoutPhoto(entry);
    expect(bytes, isNotEmpty);
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1080);
    expect(frame.image.height, 1440);

    final privatePhoto = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final withConfirmedPhoto = await const FootprintShareCardRenderer().render(
      entry,
      explicitlyIncludedPhoto: privatePhoto,
    );
    expect(withConfirmedPhoto, isNotEmpty);
  });

  test('share service cleans stale and current exports on success or failure',
      () async {
    final directory = await Directory.systemTemp.createTemp('footprint-share-');
    addTearDown(() => directory.delete(recursive: true));
    File('${directory.path}/jiandi-footprint-stale.png').writeAsBytesSync([1]);
    final renderer = _RecordingRenderer();
    final gateway = _RecordingGateway();
    final service = FootprintShareService(
      renderer,
      gateway,
      temporaryDirectory: () async => directory,
    );
    final photo = Uint8List.fromList([4, 5, 6]);

    await service.share(
      FootprintEntry.fromJson(_footprint),
      explicitlyIncludedPhoto: photo,
    );

    expect(renderer.photo, same(photo));
    expect(gateway.existedWhileSharing, isTrue);
    expect(directory.listSync().whereType<File>(), isEmpty);

    gateway.fail = true;
    await expectLater(
      service.share(FootprintEntry.fromJson(_footprint)),
      throwsStateError,
    );
    expect(directory.listSync().whereType<File>(), isEmpty);
  });

  test('footprint presentation has no active tour, audio or community imports',
      () {
    final detail =
        File('lib/features/experience/presentation/footprint_detail_page.dart')
            .readAsStringSync();
    final list =
        File('lib/features/experience/presentation/footprints_page.dart')
            .readAsStringSync();
    expect(detail, isNot(contains('active_tour_controller')));
    expect(detail, isNot(contains('NodeCommunity')));
    expect(detail, isNot(contains('AudioPlayer')));
    expect(list, isNot(contains('JourneyLibraryItem')));
    expect(detail, isNot(contains('Animated')));
    expect(list, isNot(contains('Animated')));
    final share =
        File('lib/features/experience/data/footprint_share_service.dart')
            .readAsStringSync();
    expect(share, isNot(contains('/community')));
    expect(share, isNot(contains('journeyId')));
    expect(share, isNot(contains('latitude')));
    expect(share, isNot(contains('object_key')));
  });
}

class _RendererFacade {
  const _RendererFacade();
  Future<List<int>> renderWithoutPhoto(FootprintEntry entry) async {
    final service = await importRenderer();
    return service(entry);
  }
}

class _RecordingRenderer extends FootprintShareCardRenderer {
  Uint8List? photo;

  @override
  Future<Uint8List> render(
    FootprintEntry entry, {
    Uint8List? explicitlyIncludedPhoto,
  }) async {
    photo = explicitlyIncludedPhoto;
    return Uint8List.fromList([137, 80, 78, 71]);
  }
}

class _RecordingGateway implements FootprintShareGateway {
  bool fail = false;
  bool existedWhileSharing = false;

  @override
  Future<void> share(String filePath, String text) async {
    existedWhileSharing = File(filePath).existsSync();
    if (fail) throw StateError('share cancelled');
  }
}

Future<Future<List<int>> Function(FootprintEntry)> importRenderer() async {
  // Kept behind a tiny function so this test documents the privacy default explicitly.
  final renderer = const FootprintShareCardRenderer();
  return (entry) => renderer.render(entry);
}

class _Auth extends AuthRepository {
  _Auth(super.dio);
  @override
  String? get token => 'footprint-token';
}

const _footprint = <String, dynamic>{
  'id': 'footprint-1',
  'journey_id': 'journey-1',
  'source': {'kind': 'story_fragment', 'id': 'fragment-1'},
  'city': {'id': 'city-1', 'slug': 'shenzhen', 'name': '深圳'},
  'scene': {'id': 'scene-1', 'title': '南门城墙'},
  'story_title': '旧城墙的一处细节',
  'jian_di_narrative': {
    'editorial_summary': '新旧砖缝留下了城市变化的证据。',
    'summary_options': [
      {'id': 'brick', 'text': '我看见时间藏在砖缝里'}
    ],
  },
  'what_i_saw': {
    'observation': null,
    'photo': {
      'id': 'photo-1',
      'url': '/api/v1/footprints/footprint-1/photo',
      'mime_type': 'image/jpeg',
      'width': 80,
      'height': 60,
      'created_at': '2026-08-23T12:00:00+00:00',
      'private': true,
    },
  },
  'what_i_left': {
    'selected_summary_id': null,
    'selected_summary_text': null,
    'sentence': null,
  },
  'themes': ['未来主题'],
  'organization_state': 'draft',
  'journey_state': 'partial',
  'created_at': '2026-08-23T12:00:00+00:00',
  'updated_at': '2026-08-23T12:00:00+00:00',
};
