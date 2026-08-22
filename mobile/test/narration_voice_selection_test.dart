import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/narration_voice_preference_repository.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/presentation/widgets/narration_voice_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voice preference survives repository recreation and is account scoped',
      () async {
    SharedPreferences.setMockInitialValues({});
    const accountA =
        NarrationVoicePreferenceKey(userId: 'account-a', routeId: 'route-1');
    const accountB =
        NarrationVoicePreferenceKey(userId: 'account-b', routeId: 'route-1');

    await NarrationVoicePreferenceRepository().write(accountA, 'voice-warm');

    final restored = NarrationVoicePreferenceRepository();
    expect(await restored.read(accountA), 'voice-warm');
    expect(await restored.read(accountB), isNull);
    await restored.write(accountB, 'voice-calm');
    expect(await restored.read(accountA), 'voice-warm');
    expect(await restored.read(accountB), 'voice-calm');
  });

  test('manifest fallback and fragment audio resolution are deterministic', () {
    const manifest = AudioTourManifest(
      title: '测试',
      centralQuestion: '为什么？',
      scriptVersion: 'v2',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: null,
      contentMethod: '来源审核',
      downloadSizeBytes: 20,
      defaultNarrationProfileId: 'voice-default',
      narrationProfiles: [_defaultProfile, _warmProfile],
      fragments: [_voicedFragment],
    );

    expect(manifest.effectiveProfileId('voice-warm'), 'voice-warm');
    expect(manifest.effectiveProfileId('withdrawn-profile'), 'voice-default');
    expect(manifest.fragments.single.narrationFor('voice-warm').url,
        'https://cdn.example.test/warm-v2.mp3');
    expect(manifest.fragments.single.narrationFor('withdrawn-profile').url,
        'https://cdn.example.test/default-v2.mp3');
    expect(manifest.fragments.single.transcript, '完全相同的文字稿');
    expect(
        narrationCacheVersion(
            'voice-warm', manifest.fragments.single.narrationFor('voice-warm')),
        'voice-warm:v2');
    expect(
        narrationCacheVersion('voice-default',
            manifest.fragments.single.narrationFor('voice-default')),
        'voice-default:v2');
  });

  testWidgets('single published voice is identified without a false chooser',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NarrationVoiceSelector(
          profiles: const [_defaultProfile],
          selectedProfileId: 'voice-default',
          onSelected: (_) {},
        ),
      ),
    ));

    expect(find.text('讲述音色 · 原声纪实'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('multiple backend voices open an accessible selector',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NarrationVoiceSelector(
          profiles: const [_defaultProfile, _warmProfile],
          selectedProfileId: 'voice-default',
          onSelected: (value) => selected = value,
        ),
      ),
    ));

    await tester.tap(find.text('讲述音色 · 原声纪实'));
    await tester.pumpAndSettle();
    expect(find.text('选择一路陪伴你的声音'), findsOneWidget);
    expect(find.text('文字内容完全相同，只改变讲述气质。'), findsOneWidget);

    await tester.tap(find.text('温柔讲述者'));
    await tester.pumpAndSettle();
    expect(selected, 'voice-warm');
  });
}

const _defaultProfile = NarrationVoiceProfile(
  id: 'voice-default',
  slug: 'default',
  name: '原声纪实',
  description: '克制、清晰的历史讲述',
  isDefault: true,
);

const _warmProfile = NarrationVoiceProfile(
  id: 'voice-warm',
  slug: 'warm',
  name: '温柔讲述者',
  description: '温暖、舒缓，适合边走边听',
  isDefault: false,
);

const _region = TriggerRegion(
  latitude: 22.5,
  longitude: 114,
  entryRadiusM: 50,
  exitRadiusM: 80,
  maxAccuracyM: 30,
  qualifyingSamples: 2,
  sampleWindowSeconds: 15,
  cooldownSeconds: 120,
  auditState: 'reviewed',
);

const _voicedFragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '向前走',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _region,
  transcript: '完全相同的文字稿',
  audio: NarrationAsset(
    url: 'https://cdn.example.test/default-v2.mp3',
    mimeType: 'audio/mpeg',
    sizeBytes: 10,
    scriptVersion: 'v2',
  ),
  narrationTracks: {
    'voice-default': NarrationTrack(
      transcriptHash: 'default-hash',
      audio: NarrationAsset(
        url: 'https://cdn.example.test/default-v2.mp3',
        mimeType: 'audio/mpeg',
        sizeBytes: 10,
        scriptVersion: 'v2',
      ),
    ),
    'voice-warm': NarrationTrack(
      transcriptHash: 'same-transcript-hash',
      audio: NarrationAsset(
        url: 'https://cdn.example.test/warm-v2.mp3',
        mimeType: 'audio/mpeg',
        sizeBytes: 10,
        scriptVersion: 'v2',
      ),
    ),
  },
);
