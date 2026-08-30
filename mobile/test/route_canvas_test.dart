import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/widgets/route_canvas.dart';

void main() {
  test('canvas points use backend trigger regions instead of legacy stops', () {
    final route = RouteExperience.fromJson(_routePayload);

    final points = routeCanvasPointsFor(route);

    expect(points, hasLength(2));
    expect(points.first.id, 'fragment-west');
    expect(points.first.label, '西侧剧场');
    expect(points.first.latitude, 22.545311);
    expect(points.first.longitude, 113.949939);
    expect(points.first.triggerRadiusM, 50);
    expect(points.first.latitude, isNot(route.stops.single.latitude));
  });

  test('projection preserves the physical latitude-longitude relationship', () {
    const points = [
      RouteCanvasPoint(
        id: 'origin',
        label: '原点',
        latitude: 22.54,
        longitude: 114,
        triggerRadiusM: 50,
      ),
      RouteCanvasPoint(
        id: 'north',
        label: '北',
        latitude: 22.541,
        longitude: 114,
        triggerRadiusM: 50,
      ),
      RouteCanvasPoint(
        id: 'east',
        label: '东',
        latitude: 22.54,
        longitude: 114.001,
        triggerRadiusM: 50,
      ),
    ];
    final projection =
        RouteCanvasProjection.fromPoints(points, const Size(360, 260));
    final origin = projection.project(22.54, 114);
    final north = projection.project(22.541, 114);
    final east = projection.project(22.54, 114.001);

    expect(north.dy, lessThan(origin.dy));
    expect(east.dx, greaterThan(origin.dx));
    expect(
      (east.dx - origin.dx) / (origin.dy - north.dy),
      closeTo(.93, .03),
    );
  });

  testWidgets('nodes switch selection without rendering a selected-node footer',
      (tester) async {
    RouteCanvasPoint? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteCanvas(
            points: _points,
            onPointSelected: (point) => selected = point,
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('route-canvas-node-west')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester
        .tap(find.byKey(const ValueKey('route-canvas-node-water-square')));
    await tester.pumpAndSettle();

    expect(selected?.id, 'water-square');
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('route-canvas-node-water-square')),
          )
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      find.byKey(const ValueKey('route-canvas-selection-detail')),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('user location has an accuracy halo and smooth movement',
      (tester) async {
    final location = LocationSample(
      latitude: 22.5448,
      longitude: 113.9506,
      accuracyM: 18,
      recordedAt: DateTime.utc(2026, 8, 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteCanvas(points: _points, userLocation: location),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('route-canvas-user-location')),
      findsOneWidget,
    );
    expect(find.text('你'), findsOneWidget);
    final motion = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('route-canvas-user-motion')),
    );
    expect(motion.duration, const Duration(milliseconds: 1400));
  });
}

const _points = [
  RouteCanvasPoint(
    id: 'west',
    label: '西侧剧场',
    latitude: 22.545311,
    longitude: 113.949939,
    triggerRadiusM: 50,
  ),
  RouteCanvasPoint(
    id: 'water-square',
    label: '水广场',
    latitude: 22.544587,
    longitude: 113.952303,
    triggerRadiusM: 50,
  ),
];

final _routePayload = <String, dynamic>{
  'id': 'mixc-world',
  'slug': 'mixc-world',
  'title': '华润万象天地（深圳店）',
  'subtitle': '测试',
  'description': '测试',
  'duration_minutes': 50,
  'distance_km': 1.2,
  'difficulty': '轻松',
  'theme': '城市故事',
  'hero_image': 'https://example.test/cover.jpg',
  'content_status': 'published',
  'stops': [
    {
      'id': 'legacy-stop',
      'position': 1,
      'title': '旧站点',
      'kicker': '',
      'address': '',
      'latitude': 1,
      'longitude': 2,
      'story_title': '',
      'story_body': '',
      'image': '',
      'insight': '',
      'challenge': null,
    },
  ],
  'audio_tour': {
    'title': '万象天地',
    'central_question': '这里如何变化？',
    'script_version': 'v1',
    'review_state': 'reviewed',
    'field_audit_state': 'complete',
    'production_ready': true,
    'demo_label': null,
    'content_method': 'field',
    'download_size_bytes': 0,
    'fragments': [
      _fragment(
        id: 'fragment-west',
        title: '西侧剧场',
        latitude: 22.545311,
        longitude: 113.949939,
      ),
      _fragment(
        id: 'fragment-water',
        title: '水广场',
        latitude: 22.544587,
        longitude: 113.952303,
      ),
    ],
  },
};

Map<String, dynamic> _fragment({
  required String id,
  required String title,
  required double latitude,
  required double longitude,
}) =>
    {
      'id': id,
      'position': 1,
      'safe_preview': title,
      'interaction_type': 'listen',
      'review_state': 'reviewed',
      'title': title,
      'trigger_region': {
        'latitude': latitude,
        'longitude': longitude,
        'entry_radius_m': 50,
        'exit_radius_m': 75,
        'max_accuracy_m': 50,
        'qualifying_samples': 1,
        'sample_window_seconds': 10,
        'cooldown_seconds': 0,
        'audit_state': 'complete',
      },
      'audio': {
        'url': 'https://example.test/audio.mp3',
        'mime_type': 'audio/mpeg',
        'size_bytes': 0,
        'script_version': 'v1',
      },
    };
