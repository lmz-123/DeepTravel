import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/application/trigger_engine.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';

StoryFragment _fragment({
  String id = 'f1',
  int position = 1,
  double latitude = 22.5381,
  double longitude = 113.9227,
  List<String> dependencies = const [],
}) =>
    StoryFragment(
      id: id,
      position: position,
      safePreview: '安全预览',
      interactionType: 'passive',
      reviewState: 'in_review',
      dependencyIds: dependencies,
      triggerRegion: TriggerRegion(
        latitude: latitude,
        longitude: longitude,
        entryRadiusM: 60,
        exitRadiusM: 90,
        maxAccuracyM: 50,
        qualifyingSamples: 2,
        sampleWindowSeconds: 15,
        cooldownSeconds: 120,
        auditState: 'in_review',
      ),
      audio: const NarrationAsset(
        url: 'https://example.test/f1.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: 10,
        scriptVersion: 'v1',
      ),
    );

void main() {
  test('requires two accurate samples and acknowledges only once', () {
    final time = DateTime.utc(2026, 8, 22, 10);
    final engine = StableTriggerEngine(
      now: () => time.add(const Duration(seconds: 10)),
    );
    final fragment = _fragment();
    final inaccurate = LocationSample(
      latitude: 22.5381,
      longitude: 113.9227,
      accuracyM: 80,
      recordedAt: time,
    );
    expect(engine.process(inaccurate, [fragment], {}), isNull);

    final first = LocationSample(
      latitude: 22.5381,
      longitude: 113.9227,
      accuracyM: 10,
      recordedAt: time.add(const Duration(seconds: 2)),
    );
    final second = LocationSample(
      latitude: 22.53811,
      longitude: 113.92271,
      accuracyM: 12,
      recordedAt: time.add(const Duration(seconds: 8)),
    );
    expect(engine.process(first, [fragment], {}), isNull);
    expect(engine.process(second, [fragment], {})?.fragment.id, 'f1');
    engine.acknowledge('f1');
    expect(engine.process(second, [fragment], {}), isNull);
  });

  test('real location can reveal a later fragment before dependencies', () {
    final time = DateTime.utc(2026, 8, 22, 10);
    final engine = StableTriggerEngine(
      now: () => time.add(const Duration(seconds: 10)),
    );
    final fragment = _fragment(position: 4, dependencies: ['previous']);
    for (var index = 0; index < 2; index++) {
      final sample = LocationSample(
        latitude: 22.5381,
        longitude: 113.9227,
        accuracyM: 10,
        recordedAt: time.add(Duration(seconds: index * 5)),
      );
      final candidate = engine.process(sample, [fragment], {});
      if (index == 0) {
        expect(candidate, isNull);
      } else {
        expect(candidate?.fragment.id, 'f1');
      }
    }
  });

  test('chooses the nearest qualified region, then the authored position', () {
    final time = DateTime.utc(2026, 8, 22, 10);
    final engine = StableTriggerEngine(
      now: () => time.add(const Duration(seconds: 10)),
    );
    final farther = _fragment(
      id: 'farther',
      position: 1,
      latitude: 22.5380,
    );
    final nearer = _fragment(
      id: 'nearer',
      position: 4,
      latitude: 22.53818,
      dependencies: ['farther'],
    );
    for (var index = 0; index < 2; index++) {
      final result = engine.process(
        LocationSample(
          latitude: 22.53818,
          longitude: 113.9227,
          accuracyM: 10,
          recordedAt: time.add(Duration(seconds: index * 5)),
        ),
        [farther, nearer],
        {},
      );
      if (index == 0) {
        expect(result, isNull);
      } else {
        expect(result?.fragment.id, 'nearer');
      }
    }
  });

  test('stale and future samples cannot advance a trigger', () {
    final now = DateTime.utc(2026, 8, 24, 12);
    final engine = StableTriggerEngine(now: () => now);
    final fragment = _fragment();

    for (final recordedAt in [
      now.subtract(const Duration(seconds: 16)),
      now.add(const Duration(seconds: 6)),
    ]) {
      final sample = LocationSample(
        latitude: 22.5381,
        longitude: 113.9227,
        accuracyM: 10,
        recordedAt: recordedAt,
      );
      expect(engine.process(sample, [fragment], {}), isNull);
      expect(engine.stateOf(fragment.id), RegionPresence.outside);
    }
  });
}
