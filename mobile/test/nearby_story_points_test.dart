import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/application/nearby_story_points.dart';
import 'package:jiandi/features/experience/application/trigger_engine.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';

void main() {
  test('sorts story points by current distance without dependency gating', () {
    final points = projectNearbyStoryPoints(
      manifestFragments: [
        _fragment('authored-first', 1, latitude: 22.5390),
        _fragment('nearest-later', 4, latitude: 22.5381),
      ],
      ledgerEntries: const [],
      presenceOf: (_) => RegionPresence.outside,
      sample: LocationSample(
        latitude: 22.5381,
        longitude: 113.9227,
        accuracyM: 35,
        recordedAt: DateTime.utc(2026, 8, 23),
      ),
    );

    expect(points.map((point) => point.fragment.id),
        ['nearest-later', 'authored-first']);
    expect(points.first.distanceMeters, closeTo(0, .01));
  });

  test('keeps backend order and omits distance when location is unavailable',
      () {
    final points = projectNearbyStoryPoints(
      manifestFragments: [
        _fragment('backend-first', 1, latitude: 22.5390),
        _fragment('backend-second', 2, latitude: 22.5381),
      ],
      ledgerEntries: const [],
      presenceOf: (_) => RegionPresence.outside,
    );

    expect(points.map((point) => point.fragment.id),
        ['backend-first', 'backend-second']);
    expect(points.every((point) => point.distanceMeters == null), isTrue);
    expect(
        points.every((point) =>
            point.status == NearbyStoryPointStatus.locationUnavailable),
        isTrue);
  });

  test('uses revealed ledger status and preserves arbitrary backend metadata',
      () {
    final manifest = _fragment('story', 1);
    final revealed = StoryFragment(
      id: manifest.id,
      position: manifest.position,
      safePreview: manifest.safePreview,
      interactionType: manifest.interactionType,
      reviewState: manifest.reviewState,
      triggerRegion: manifest.triggerRegion,
      audio: manifest.audio,
      title: '潮水退去之后',
      transcript: '正文',
      state: 'triggered',
      displayTheme: '潮汐里的旧城',
      expectedDurationSeconds: 181,
    );

    final point = projectNearbyStoryPoints(
      manifestFragments: [manifest],
      ledgerEntries: [revealed],
      presenceOf: (_) => RegionPresence.acknowledged,
    ).single;

    expect(point.canReplay, isTrue);
    expect(point.status, NearbyStoryPointStatus.triggered);
    expect(point.fragment.displayTheme, '潮汐里的旧城');
    expect(point.fragment.expectedDurationSeconds, 181);
  });
}

StoryFragment _fragment(
  String id,
  int position, {
  double latitude = 22.5381,
}) =>
    StoryFragment(
      id: id,
      position: position,
      safePreview: '安全预览',
      interactionType: 'passive',
      reviewState: 'reviewed',
      dependencyIds: const ['unrelated-previous-story'],
      triggerRegion: TriggerRegion(
        latitude: latitude,
        longitude: 113.9227,
        entryRadiusM: 60,
        exitRadiusM: 90,
        maxAccuracyM: 50,
        qualifyingSamples: 2,
        sampleWindowSeconds: 15,
        cooldownSeconds: 120,
        auditState: 'approved',
      ),
      audio: const NarrationAsset(
        url: 'https://example.test/story.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: 10,
        scriptVersion: 'v1',
      ),
    );
