import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/application/trigger_engine.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';

StoryFragment _fragment({List<String> dependencies = const []}) =>
    StoryFragment(
      id: 'f1',
      position: 1,
      safePreview: '安全预览',
      interactionType: 'passive',
      reviewState: 'in_review',
      dependencyIds: dependencies,
      triggerRegion: const TriggerRegion(
        latitude: 22.5381,
        longitude: 113.9227,
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
    final engine = StableTriggerEngine();
    final fragment = _fragment();
    final time = DateTime.utc(2026, 8, 22, 10);
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

  test('does not reveal a fragment before dependencies are collected', () {
    final engine = StableTriggerEngine();
    final fragment = _fragment(dependencies: ['previous']);
    final time = DateTime.utc(2026, 8, 22, 10);
    for (var index = 0; index < 2; index++) {
      final sample = LocationSample(
        latitude: 22.5381,
        longitude: 113.9227,
        accuracyM: 10,
        recordedAt: time.add(Duration(seconds: index * 5)),
      );
      expect(engine.process(sample, [fragment], {}), isNull);
    }
  });
}
