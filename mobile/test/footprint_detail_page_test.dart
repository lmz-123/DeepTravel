import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/footprint_detail_page.dart';
import 'package:jiandi/features/experience/presentation/widgets/evidence_photo_widgets.dart';

void main() {
  testWidgets(
      'archived fragmented footprint recovers unlocked clues without photos',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        journeyContextProvider.overrideWith(
          (ref, key) async => _fragmentedContext,
        ),
        journeyEvidenceProvider.overrideWith((ref, key) async => const []),
      ],
      child: const MaterialApp(
        home: FootprintDetailPage(journeyId: 'fragmented-journey'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('已归档'), findsOneWidget);
    expect(find.text('旧城线索'), findsWidgets);
    expect(find.text('这条线索没有上传照片，完整足迹仍然保留。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy footprint renders recap even when route artwork is stale',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        journeyContextProvider.overrideWith((ref, key) async => _legacyContext),
        journeyEvidenceProvider.overrideWith((ref, key) async => const []),
      ],
      child: const MaterialApp(
        home: FootprintDetailPage(journeyId: 'legacy-journey'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('旅程回顾'), findsOneWidget);
    expect(find.text('老站点'), findsOneWidget);
    expect(find.text('留下一条见识'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('footprint gallery loads private bytes and opens zoom viewer',
      (tester) async {
    final evidence = EvidenceRecord(
      id: 'evidence-1',
      url: '/api/v1/journeys/fragmented-journey/evidence/evidence-1',
      journeyId: 'fragmented-journey',
      fragmentId: 'fragment-1',
      capturedAt: DateTime(2026, 8, 23, 14, 30),
    );
    const expiredEvidence = EvidenceRecord(
      id: 'evidence-expired',
      url: '/api/v1/journeys/fragmented-journey/evidence/evidence-expired',
      journeyId: 'fragmented-journey',
      fragmentId: 'fragment-1',
      isExpired: true,
    );
    final onePixelPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        journeyContextProvider.overrideWith(
          (ref, key) async => _fragmentedContext,
        ),
        journeyEvidenceProvider.overrideWith(
          (ref, key) async => [evidence, expiredEvidence],
        ),
        evidenceBytesProvider.overrideWith(
          (ref, key) async {
            if (key.evidence.isExpired) {
              throw StateError('expired');
            }
            return onePixelPng;
          },
        ),
      ],
      child: const MaterialApp(
        home: FootprintDetailPage(journeyId: 'fragmented-journey'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EvidenceThumbnail), findsNWidgets(2));
    await tester.ensureVisible(find.byType(EvidenceThumbnail).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('照片已过保存期'), findsOneWidget);
    expect(find.text('2026.08.23 14:30'), findsOneWidget);
    final thumbnail = find.bySemanticsLabel('查看照片：旧城线索');
    await tester.ensureVisible(thumbnail.first);
    await tester.pumpAndSettle();
    await tester.tap(thumbnail.first);
    await tester.pumpAndSettle();

    expect(find.text('双指缩放'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('关闭照片'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭照片'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}

const _fragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '旧城入口',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: TriggerRegion(
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
    url: 'https://cdn.example.test/audio.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1',
  ),
  title: '旧城线索',
  transcript: '这是已经解锁的讲解。',
  state: 'collected',
);

final _fragmentedContext = JourneyContext(
  journey: _journey('fragmented-journey', 'fragmented-route'),
  route: _route(
    id: 'fragmented-route',
    title: '归档路线',
    status: 'archived',
    audioTour: const AudioTourManifest(
      title: '归档路线',
      centralQuestion: '发生了什么？',
      scriptVersion: 'v1',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: null,
      contentMethod: '来源支持',
      downloadSizeBytes: 1,
      fragments: [_fragment],
    ),
  ),
  journeyKind: 'fragmented',
  collectedCount: 1,
  totalCount: 1,
  ledger: const StoryLedger(
    centralQuestion: '发生了什么？',
    collectedCount: 1,
    totalCount: 1,
    reconstructionUnlocked: true,
    entries: [_fragment],
  ),
);

final _legacyContext = JourneyContext(
  journey: _journey('legacy-journey', 'legacy-route'),
  route: _route(
    id: 'legacy-route',
    title: '旧式路线',
    status: 'published',
    heroImage: 'https://invalid.example.test/missing.jpg',
    stops: const [
      ExperienceStop(
        id: 'stop-1',
        position: 1,
        title: '老站点',
        kicker: '回顾',
        address: '公共区域',
        latitude: 22.5,
        longitude: 114,
        storyTitle: '老故事',
        storyBody: '正文',
        image: '',
        insight: '留下一条见识',
        challenge: Challenge(id: '', prompt: '', hint: '', options: []),
      ),
    ],
  ),
  journeyKind: 'legacy',
  collectedCount: 1,
  totalCount: 1,
);

JourneySession _journey(String id, String routeId) => JourneySession(
      id: id,
      routeId: routeId,
      status: 'completed',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 1,
    );

RouteExperience _route({
  required String id,
  required String title,
  required String status,
  String heroImage = '',
  List<ExperienceStop> stops = const [],
  AudioTourManifest? audioTour,
}) =>
    RouteExperience(
      id: id,
      slug: id,
      title: title,
      subtitle: '足迹',
      description: '完成的路线',
      durationMinutes: 30,
      distanceKm: 1,
      difficulty: '轻松',
      theme: '城市',
      heroImage: heroImage,
      contentStatus: status,
      stops: stops,
      audioTour: audioTour,
    );
