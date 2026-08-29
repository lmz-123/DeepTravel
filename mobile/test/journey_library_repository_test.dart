import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;

  setUp(() {
    requests = [];
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
  });

  test('parses library, owner context, evidence metadata and policy', () async {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final data = switch (options.path) {
        '/journeys' => {
            'data': [
              {
                'journey': _journey,
                'route': _route,
                'journey_kind': 'fragmented',
                'collected_count': 4,
                'total_count': 5,
                'evidence_count': 1,
              }
            ]
          },
        '/journeys/journey-1/context' => {
            'data': {
              'journey': _journey,
              'route': _route,
              'journey_kind': 'legacy',
              'progress': {'collected_count': 5, 'total_count': 5},
              'ledger': null,
            }
          },
        '/journeys/journey-1/evidence' => {
            'data': [_evidence]
          },
        '/policies/evidence' => {
            'data': {
              'upload_enabled': true,
              'retention_days': 30,
              'max_bytes': 8388608,
              'max_edge_pixels': 2048,
              'allowed_mime_types': ['image/jpeg', 'image/png'],
              'private_access': true,
              'exif_removed': true,
              'normalized_on_upload': true,
            }
          },
        _ => throw StateError('unexpected ${options.path}'),
      };
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ));
    }));
    final repository = ApiExperienceRepository(dio, _TokenAuthRepository(dio));

    final library = await repository.journeys(status: 'completed');
    final context = await repository.journeyContext('journey-1');
    final evidence = await repository.evidence('journey-1');
    final policy = await repository.evidencePolicy();

    expect(library.single.collectedCount, 4);
    expect(library.single.route.stops, isEmpty);
    expect(context.journey.isCompleted, isTrue);
    expect(context.ledger, isNull);
    expect(evidence.single.fragmentId, 'fragment-1');
    expect(evidence.single.capturedAt, isNotNull);
    expect(policy.retentionDays, 30);
    expect(requests.first.queryParameters, {'status': 'completed'});
    expect(
      requests.every((request) =>
          request.headers['Authorization'] == 'Bearer private-token'),
      isTrue,
    );
  });

  test('loads relative evidence bytes with bearer authorization', () async {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response<List<int>>(
        requestOptions: options,
        statusCode: 200,
        data: [1, 2, 3, 4],
      ));
    }));
    final repository = ApiExperienceRepository(dio, _TokenAuthRepository(dio));

    final bytes = await repository.evidenceBytes(
      'journey-1',
      dynamicEvidenceRecord,
    );

    expect(bytes, Uint8List.fromList([1, 2, 3, 4]));
    expect(requests.single.path, '/journeys/journey-1/evidence/evidence-1');
    expect(requests.single.responseType, ResponseType.bytes);
    expect(requests.single.headers['Authorization'], 'Bearer private-token');
  });

  test('clears canonical exploration progress with bearer authorization',
      () async {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'data': {'journey_count': 2, 'fragment_count': 10}
        },
      ));
    }));
    final repository = ApiExperienceRepository(dio, _TokenAuthRepository(dio));

    final result = await repository.clearExplorationProgress();

    expect(result.journeyCount, 2);
    expect(result.fragmentCount, 10);
    expect(requests.single.method, 'DELETE');
    expect(requests.single.path, '/journeys/progress');
    expect(requests.single.headers['Authorization'], 'Bearer private-token');
  });

  test('maps auth expiry and private evidence 404/410 distinctly', () async {
    var status = 401;
    var expiredCalls = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: {
            'error': {
              'code': status == 404 ? 'evidence_not_found' : 'evidence_expired',
              'message': status == 404 ? '照片不存在' : '照片已清理',
            }
          },
        ),
      ));
    }));
    final repository = ApiExperienceRepository(
      dio,
      _TokenAuthRepository(dio),
      onUnauthorized: () async => expiredCalls += 1,
    );

    await expectLater(
      repository.journeys(),
      throwsA(isA<ExperienceFailure>().having(
        (error) => error.statusCode,
        'statusCode',
        401,
      )),
    );
    expect(expiredCalls, 1);

    for (status in [404, 410]) {
      await expectLater(
        repository.evidenceBytes(
          'journey-1',
          dynamicEvidenceRecord,
        ),
        throwsA(isA<ExperienceFailure>().having(
          (error) => error.statusCode,
          'statusCode',
          status,
        )),
      );
    }
  });
}

class _TokenAuthRepository extends AuthRepository {
  _TokenAuthRepository(super.dio);

  @override
  String? get token => 'private-token';
}

const dynamicEvidenceRecord =
    // Kept as a constant so the byte tests cannot accidentally depend on parsing.
    EvidenceRecord(
  id: 'evidence-1',
  url: '/journeys/journey-1/evidence/evidence-1',
);

const _journey = {
  'id': 'journey-1',
  'route_id': 'route-1',
  'status': 'completed',
  'current_stop_position': 5,
  'arrived_stop_id': null,
  'answered_stop_ids': <String>[],
  'progress': 1.0,
};

const _route = {
  'id': 'route-1',
  'slug': 'route-one',
  'title': '路线一',
  'subtitle': '副标题',
  'description': '描述',
  'duration_minutes': 60,
  'distance_km': 2.1,
  'difficulty': '轻松',
  'theme': '历史',
  'hero_image': 'https://cdn.example.test/cover.jpg',
  'content_status': 'archived',
  'is_featured': false,
  'stop_count': 5,
};

const _evidence = {
  'id': 'evidence-1',
  'journey_id': 'journey-1',
  'fragment_id': 'fragment-1',
  'mission_id': 'mission-1',
  'mime_type': 'image/jpeg',
  'size_bytes': 1024,
  'width': 1200,
  'height': 900,
  'captured_at': '2026-08-23T00:00:00Z',
  'uploaded_at': '2026-08-23T00:01:00Z',
  'expires_at': '2026-09-22T00:01:00Z',
  'is_expired': false,
  'url': '/journeys/journey-1/evidence/evidence-1',
};
