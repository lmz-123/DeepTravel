import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/auth/domain/auth_models.dart';
import 'package:jiandi/features/auth/presentation/auth_provider.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/data/location_mode_preferences.dart';
import 'package:jiandi/features/experience/data/narration_voice_preference_repository.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/data/route_offline_package_service.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/journey_page.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/route_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('location mode defaults to real and survives store recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = SharedPreferencesLocationModeStore();
    expect(await first.read(), TourLocationMode.real);

    await first.write(TourLocationMode.simulated);

    final restored = SharedPreferencesLocationModeStore();
    expect(await restored.read(), TourLocationMode.simulated);
  });

  testWidgets('route setup shows read-only mode and keeps editing in settings',
      (tester) async {
    final modeStore = _MemoryLocationModeStore(TourLocationMode.real);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        experienceRepositoryProvider.overrideWithValue(_FragmentRepository()),
        locationModeStoreProvider.overrideWithValue(modeStore),
      ],
      child: const MaterialApp(home: RouteDetailPage(slug: 'test-route')),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('当前使用设置中的真实定位模式'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(modeStore.mode, TourLocationMode.real);
  });

  testWidgets(
      'real journey shows selected node copy before audio without a mandatory next action',
      (tester) async {
    final store = _MemoryTourStore();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(_FragmentRepository()),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider
          .overrideWithValue(_MemoryLocationModeStore(TourLocationMode.real)),
    ]);
    addTearDown(container.dispose);
    container.read(journeyControllerProvider.notifier).resume(_route, _session);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('附近故事点'), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('selected-node-detail-fragment-1')),
      find.byType(ListView),
      const Offset(0, -180),
    );
    expect(find.byKey(const ValueKey('selected-node-detail-fragment-1')),
        findsOneWidget);
    expect(find.text('第一条线索'), findsOneWidget);
    expect(find.text('潮汐里的旧城'), findsOneWidget);
    expect(find.text('约 3 分钟'), findsOneWidget);
    expect(find.text('等待定位'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^\d+ 米$').hasMatch(widget.data!)),
        findsNothing);
    expect(find.text('下一条线索（测试）'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  test('selecting an untriggered node changes selection only', () async {
    final store = _MemoryTourStore();
    final repository = _ProgressingFragmentRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_DeniedLocationTracker()),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider
          .overrideWithValue(_MemoryLocationModeStore(TourLocationMode.real)),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final controller = container.read(activeTourControllerProvider.notifier);
    await controller.start(_twoFragmentRoute, _session);
    final before = container.read(activeTourControllerProvider);

    expect(await controller.selectNode('fragment-2'), isTrue);
    final after = container.read(activeTourControllerProvider);
    expect(after.selectedFragmentId, 'fragment-2');
    expect(after.ledger?.collectedCount, before.ledger?.collectedCount);
    expect(after.current, before.current);
    expect(repository.stateOf('fragment-2'), 'undiscovered');
    expect(repository.selectionTriggerCalls, 0);
    expect(repository.selectionAcknowledgeCalls, 0);
  });

  test('verified package starts offline, restores text, and syncs once',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = _MemoryTourStore();
    final repository = _ProgressingFragmentRepository();
    final session = _sessionFor('offline:account-a:route-1', 'route-1');
    await store.enqueue(OutboxEvent(
      id: 'start_journey:${session.id}',
      type: 'start_journey',
      payload: {
        'local_journey_id': session.id,
        'route_id': session.routeId,
      },
    ));
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_AuthenticatedRepository()),
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_DeniedLocationTracker()),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      routeOfflinePackageServiceProvider.overrideWithValue(
        _OfflinePackageService(store),
      ),
      connectivityChangesProvider.overrideWithValue(const Stream.empty()),
      locationModeStoreProvider.overrideWithValue(
        _MemoryLocationModeStore(TourLocationMode.simulated),
      ),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_offlineRoute, session);
    expect(container.read(activeTourControllerProvider).status, 'simulated');
    expect(
        container.read(activeTourControllerProvider).ledger!.entries.single,
        isNot(isA<StoryFragment>().having(
          (fragment) => fragment.isRevealed,
          'revealed',
          true,
        )));

    await controller.triggerNextDemo();
    final triggered =
        container.read(activeTourControllerProvider).ledger!.entries.single;
    expect(triggered.state, 'triggered');
    expect(triggered.transcript, '离线完整文字稿');
    expect(store.outbox.map((event) => event.type),
        containsAllInOrder(['start_journey', 'trigger']));

    await controller.reconcileOutbox();
    expect(repository.selectionTriggerCalls, 1);
    expect(store.outbox, isEmpty);
    expect(
      (await store
          .readJson('journey_alias_${session.id}'))?['remote_journey_id'],
      'journey-1',
    );
    await controller.reconcileOutbox();
    expect(repository.selectionTriggerCalls, 1);

    final restored = await store.readJson('ledger_${session.id}');
    expect((restored!['fragments'] as List).single['state'], 'triggered');
  });

  test('denied location keeps nearby points ordered without fake distances',
      () async {
    final store = _MemoryTourStore();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider
          .overrideWithValue(_ProgressingFragmentRepository()),
      locationTrackerProvider.overrideWithValue(_DeniedLocationTracker()),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider
          .overrideWithValue(_MemoryLocationModeStore(TourLocationMode.real)),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(activeTourControllerProvider.notifier)
        .start(_twoFragmentRoute, _session);
    final state = container.read(activeTourControllerProvider);

    expect(state.status, 'permission_limited');
    expect(state.nearbyStoryPoints.map((point) => point.fragment.id),
        ['fragment-1', 'fragment-2']);
    expect(
        state.nearbyStoryPoints.every((point) => point.distanceMeters == null),
        isTrue);
  });

  test('simulated startup skips GPS and runtime switch restores real GPS',
      () async {
    final location = _RecordingLocationTracker();
    final store = _MemoryTourStore();
    final modeStore = _MemoryLocationModeStore(TourLocationMode.simulated);
    final repository = _FragmentRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(location),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(modeStore),
    ]);
    addTearDown(container.dispose);

    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_route, _session);

    expect(container.read(activeTourControllerProvider).status, 'simulated');
    expect(location.permissionRequests, 0);
    expect(location.sampleSubscriptions, 0);

    await container
        .read(locationModeControllerProvider.notifier)
        .setMode(TourLocationMode.real);
    await _waitUntil(() =>
        container.read(activeTourControllerProvider).status == 'monitoring');

    expect(container.read(activeTourControllerProvider).status, 'monitoring');
    expect(location.permissionRequests, 1);
    expect(location.sampleSubscriptions, 1);

    await container
        .read(locationModeControllerProvider.notifier)
        .setMode(TourLocationMode.simulated);
    await _waitUntil(() =>
        container.read(activeTourControllerProvider).status == 'simulated');

    final simulated = container.read(activeTourControllerProvider);
    expect(simulated.status, 'simulated');
    expect(simulated.locationMode, TourLocationMode.simulated);
    expect(location.stopCalls, greaterThanOrEqualTo(2));
    expect(modeStore.mode, TourLocationMode.simulated);
  });

  test(
      'completed narration resets playing state and the next simulated clue starts immediately',
      () async {
    final store = _MemoryTourStore();
    final player = _ControllableNarrationPlayer();
    final repository = _ProgressingFragmentRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });

    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_twoFragmentRoute, _session);
    await controller.triggerNextDemo();

    expect(player.playedFragmentIds, ['fragment-1']);
    expect(container.read(activeTourControllerProvider).isPlaying, isTrue);

    player.completeNaturally();
    await _waitUntil(() => repository.isCollected('fragment-1'));

    expect(container.read(activeTourControllerProvider).isPlaying, isFalse);

    await controller.triggerNextDemo();

    final state = container.read(activeTourControllerProvider);
    expect(player.playedFragmentIds, ['fragment-1', 'fragment-2']);
    expect(state.current?.id, 'fragment-2');
    expect(state.queue, isEmpty);
  });

  test('saved account voice drives preparation, playback, switch and replay',
      () async {
    SharedPreferences.setMockInitialValues({
      'narration_voice:account-a:voice-route': 'voice-warm',
    });
    final store = _MemoryTourStore();
    final prepared = _RecordingPreparedRouteService(store);
    final player = _RecordingNarrationPlayer();
    final repository = _VoiceFragmentRepository();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_AuthenticatedRepository()),
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider.overrideWithValue(prepared),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_voiceRoute, _session);
    expect(container.read(activeTourControllerProvider).narrationProfileId,
        'voice-warm');
    expect(prepared.profileIds, ['voice-warm']);

    await controller.togglePlayback();
    await _waitUntil(() => player.urls.isNotEmpty);
    expect(player.urls.last, 'https://example.test/warm.mp3');

    await controller.selectNarrationProfile('voice-default');
    expect(prepared.profileIds, ['voice-warm', 'voice-default']);
    expect(container.read(activeTourControllerProvider).narrationProfileMessage,
        contains('进度保持不变'));
    expect(player.urls.last, 'https://example.test/default.mp3');

    await controller.replay();
    expect(player.urls.last, 'https://example.test/default.mp3');
    expect(
      await NarrationVoicePreferenceRepository().read(
          const NarrationVoicePreferenceKey(
              userId: 'account-a', routeId: 'voice-route')),
      'voice-default',
    );
  });

  test(
      'failed same-fragment voice replacement restores playable source and preference',
      () async {
    SharedPreferences.setMockInitialValues({
      'narration_voice:account-a:voice-route': 'voice-warm',
    });
    final store = _MemoryTourStore();
    final player = _RecordingNarrationPlayer()
      ..failUrl = 'https://example.test/default.mp3';
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_AuthenticatedRepository()),
      experienceRepositoryProvider
          .overrideWithValue(_VoiceFragmentRepository()),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_RecordingPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);
    await controller.start(_voiceRoute, _session);
    await controller.togglePlayback();
    await _waitUntil(() => player.urls.isNotEmpty);

    await controller.selectNarrationProfile('voice-default');

    final state = container.read(activeTourControllerProvider);
    expect(state.narrationProfileId, 'voice-warm');
    expect(state.errorMessage, contains('已恢复原来的声音'));
    expect(player.urls, [
      'https://example.test/warm.mp3',
      'https://example.test/default.mp3',
      'https://example.test/warm.mp3',
    ]);
    expect(
      await NarrationVoicePreferenceRepository().read(
          const NarrationVoicePreferenceKey(
              userId: 'account-a', routeId: 'voice-route')),
      'voice-warm',
    );
  });

  testWidgets(
      'restored triggered clue shows audio and transcript then advances to the next clue',
      (tester) async {
    final store = _MemoryTourStore();
    final player = _ControllableNarrationPlayer();
    final repository = _ProgressingFragmentRepository(initialStates: const {
      'fragment-1': 'collected',
      'fragment-2': 'triggered',
      'fragment-3': 'undiscovered',
    });
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });

    await container
        .read(journeyControllerProvider.notifier)
        .start(_threeFragmentRoute);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('设置模式：模拟定位'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byTooltip('暂停自动导览'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('暂停自动导览'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('暂停自动导览'));
    await tester.pump();
    expect(find.byTooltip('继续自动导览'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('继续自动导览'));
    await tester.tap(find.byTooltip('继续自动导览'));
    await tester.pump();
    expect(find.byTooltip('暂停自动导览'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('第二条线索'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('阅读等价文字稿'),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    await tester.tap(find.text('阅读等价文字稿'));
    await tester.pumpAndSettle();
    expect(find.text('第二条线索的正文'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('继续'));
    await tester.tap(find.byTooltip('继续'));
    await tester.pump();
    expect(player.playedFragmentIds, ['fragment-2']);
    expect(find.byTooltip('暂停'), findsOneWidget);

    player.emitDuration(const Duration(minutes: 2));
    player.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();
    expect(find.byTooltip('继续'), findsOneWidget);
    await tester.tap(find.byTooltip('继续'));
    await tester.pump();
    expect(find.byTooltip('暂停'), findsOneWidget);

    player.completeNaturally();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('下一条线索（测试）'));
    await container
        .read(activeTourControllerProvider.notifier)
        .triggerNextDemo();
    await tester.pump();

    expect(repository.isCollected('fragment-2'), isTrue);
    expect(player.playedFragmentIds, ['fragment-2', 'fragment-3']);
    expect(find.text('第三条线索'), findsWidgets);
  });

  testWidgets(
      'reconstruction uses server items and shows mismatch above the bottom sheet',
      (tester) async {
    final store = _MemoryTourStore();
    final repository = _ReconstructionRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(container.dispose);

    await container
        .read(journeyControllerProvider.notifier)
        .start(_twoFragmentRoute);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-1')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('故事线索簿'));
    await tester.pumpAndSettle();
    expect(find.text('把线索拼成完整故事'), findsOneWidget);
    await tester.tap(find.text('把线索拼成完整故事'));
    await tester.pumpAndSettle();
    expect(find.text('服务器给出的第二项'), findsOneWidget);
    expect(find.text('服务器给出的第一项'), findsOneWidget);

    await tester.tap(find.text('提交这条历史因果链'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.submittedIds, ['cause-2', 'cause-1']);
    final feedback =
        find.byKey(const ValueKey('reconstruction-feedback-overlay'));
    expect(feedback, findsOneWidget);
    expect(find.textContaining('红色线索的位置需要调整'), findsOneWidget);
    final mismatchedCard = tester.widget<Card>(find.ancestor(
        of: find.byKey(const ValueKey('reconstruction-cause-2')),
        matching: find.byType(Card)));
    expect(mismatchedCard.color, isNotNull);
    expect(tester.getTopLeft(feedback).dy,
        lessThan(tester.getTopLeft(find.text('拼回完整故事')).dy));

    await tester.tap(find.text('提交这条历史因果链'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reconstruction-feedback-overlay')),
        findsNothing);
    expect(find.text('测试完整故事正文'), findsOneWidget);
  });

  test(
      'completed revisit switches collected nodes without location or progress writes',
      () async {
    final store = _MemoryTourStore();
    final player = _GenerationNarrationPlayer();
    final location = _RecordingLocationTracker();
    final repository = _CountingProgressRepository();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_AuthenticatedRepository()),
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(location),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider
          .overrideWithValue(_MemoryLocationModeStore(TourLocationMode.real)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.startRevisit(_completedContext);
    var state = container.read(activeTourControllerProvider);
    expect(state.status, 'revisit');
    expect(state.playbackMode, TourPlaybackMode.revisit);
    expect(state.current?.id, 'fragment-2');
    expect(location.permissionRequests, 0);
    expect(location.sampleSubscriptions, 0);
    expect(repository.startActiveCalls, 0);

    expect(await controller.selectCollectedFragment('fragment-1'), isTrue);
    state = container.read(activeTourControllerProvider);
    expect(state.selectedFragmentId, 'fragment-1');
    expect(state.liveFragmentId, isNull);
    expect(state.playbackOwner?.fragmentId, 'fragment-1');
    expect(state.queue, isEmpty);
    player.emitCurrentPosition(const Duration(seconds: 17));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeTourControllerProvider).position,
        const Duration(seconds: 17));

    await controller.setSpeed(1.5);
    await controller.togglePlayback();
    await controller.togglePlayback();
    expect(player.lastSpeed, 1.5);
    expect(player.pauseCalls, 1);
    expect(player.resumeCalls, 1);
    await controller.seek(const Duration(seconds: 9));
    await controller.replay();
    expect(player.lastSeek, const Duration(seconds: 9));
    expect(player.replayCalls, 1);

    player.emitCurrentCompletion();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(repository.acknowledgeCalls, 0);
    expect(container.read(activeTourControllerProvider).selectedFragmentId,
        'fragment-1');

    await controller.clearForAccountExit();
    expect(container.read(activeTourControllerProvider).status, 'idle');
    expect(container.read(activeTourControllerProvider).playbackOwner, isNull);
    expect(location.stopCalls, greaterThanOrEqualTo(1));
  });

  test(
      'active replay keeps real location running and hands a new trigger back to live playback',
      () async {
    final store = _MemoryTourStore();
    final player = _ControllableNarrationPlayer();
    final location = _StreamingLocationTracker();
    final repository = _ReplayProgressRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(location),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider
          .overrideWithValue(_MemoryLocationModeStore(TourLocationMode.real)),
    ]);
    addTearDown(() async {
      container.dispose();
      await location.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_twoFragmentRoute, _session);
    expect(await controller.selectRevealedFragment('fragment-1'), isTrue);
    expect(location.sampleSubscriptions, 1);
    expect(container.read(activeTourControllerProvider).playbackMode,
        TourPlaybackMode.liveReplay);

    final time = DateTime.now().toUtc();
    location.emit(LocationSample(
      latitude: _region.latitude,
      longitude: _region.longitude,
      accuracyM: 10,
      recordedAt: time,
    ));
    await Future<void>.delayed(Duration.zero);
    location.emit(LocationSample(
      latitude: _region.latitude,
      longitude: _region.longitude,
      accuracyM: 10,
      recordedAt: time.add(const Duration(seconds: 5)),
    ));
    await _waitUntil(() => repository.isTriggered('fragment-2'));

    var state = container.read(activeTourControllerProvider);
    expect(location.sampleSubscriptions, 1);
    expect(state.queue.map((fragment) => fragment.id), ['fragment-2']);
    expect(repository.acknowledgeCalls, 0);

    player.completeNaturally();
    await _waitUntil(() => player.playedFragmentIds.length == 2);
    state = container.read(activeTourControllerProvider);
    expect(state.playbackMode, TourPlaybackMode.live);
    expect(player.playedFragmentIds, ['fragment-1', 'fragment-2']);
    expect(repository.acknowledgeCalls, 0);

    await controller.stopTour();
    expect(container.read(activeTourControllerProvider).nearbyStoryPoints,
        isEmpty);
  });

  test(
      'cross-attraction replacement rejects old callbacks and keeps one audio owner',
      () async {
    final store = _MemoryTourStore();
    final player = _GenerationNarrationPlayer();
    final repository = _CrossRouteRepository();
    final location = _RecordingLocationTracker();
    final routeA = _routeFor('route-a', 'fragment-a', '景点 A', 'a.jpg');
    final routeB = _routeFor('route-b', 'fragment-b', '景点 B', 'b.jpg');
    final routeC = _routeFor('route-c', 'fragment-c', '景点 C', 'c.jpg');
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_AuthenticatedRepository()),
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(location),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(routeA, _sessionFor('journey-a', 'route-a'));
    await controller.togglePlayback();
    await _waitUntil(() => player.playedFragmentIds.length == 1);
    final generationA =
        container.read(activeTourControllerProvider).playbackOwner!.generation;

    await controller.start(routeB, _sessionFor('journey-b', 'route-b'));
    await controller.togglePlayback();
    await _waitUntil(() => player.playedFragmentIds.length == 2);
    var state = container.read(activeTourControllerProvider);
    expect(state.playbackOwner?.routeId, 'route-b');
    expect(state.playbackOwner?.journeyId, 'journey-b');
    expect(state.playbackOwner?.generation, greaterThan(generationA));
    expect(state.route?.heroImage, 'b.jpg');
    expect(player.overlapDetected, isFalse);

    player.emitPosition(0, const Duration(minutes: 4));
    player.emitCompletion(0);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    state = container.read(activeTourControllerProvider);
    expect(state.route?.id, 'route-b');
    expect(state.position, Duration.zero);
    expect(repository.acknowledgedJourneyIds, isEmpty);

    await controller.pauseTour();
    expect(container.read(activeTourControllerProvider).status, 'paused');
    player.failFragmentId = 'fragment-c';
    await controller.start(routeC, _sessionFor('journey-c', 'route-c'));
    await controller.togglePlayback();
    await _waitUntil(() =>
        container.read(activeTourControllerProvider).errorMessage != null);
    state = container.read(activeTourControllerProvider);
    expect(state.playbackOwner?.routeId, 'route-c');
    expect(state.route?.heroImage, 'c.jpg');
    expect(state.isPlaying, isFalse);
    expect(player.overlapDetected, isFalse);
    expect(
        repository.stoppedJourneyIds, containsAll(['journey-a', 'journey-b']));
  });

  test('simulated next clue stops early audio and advances without a photo',
      () async {
    final store = _MemoryTourStore();
    final player = _GenerationNarrationPlayer();
    final repository = _EarlyAdvanceRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_twoFragmentRoute, _session);
    await controller.togglePlayback();
    await _waitUntil(() => player.playedFragmentIds.length == 1);
    await controller.triggerNextDemo();

    expect(repository.acknowledgeCalls, 1);
    expect(repository.isCollected('fragment-1'), isTrue);
    expect(player.stopCalls, greaterThanOrEqualTo(3));
    expect(player.playedFragmentIds, ['fragment-1', 'fragment-2']);
    expect(
        container.read(activeTourControllerProvider).current?.id, 'fragment-2');
  });

  test('simulated trigger failure is retryable and final clue is idempotent',
      () async {
    final store = _MemoryTourStore();
    final player = _GenerationNarrationPlayer();
    final repository = _FailOnceTriggerRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_twoFragmentRoute, _session);
    await controller.triggerNextDemo();
    expect(container.read(activeTourControllerProvider).locationMessage,
        contains('再次点击重试'));
    expect(player.playedFragmentIds, isEmpty);

    await controller.triggerNextDemo();
    expect(player.playedFragmentIds, ['fragment-2']);
    player.emitCurrentCompletion();
    await _waitUntil(() => repository.isCollected('fragment-2'));

    await controller.triggerNextDemo();
    expect(container.read(activeTourControllerProvider).locationMessage,
        contains('所有线索已经收集完成'));
    expect(repository.acknowledgeCalls, 1);
  });

  test('camera cancel postpones and offline capture stays tappable in outbox',
      () async {
    final store = _MemoryTourStore();
    final camera = _SequenceCameraCapture([null, '/tmp/private-clue.jpg']);
    final repository = _OfflineEvidenceRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      cameraCaptureProvider.overrideWithValue(camera),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_route, _session);
    await controller.captureEvidence(_fragment);
    expect(container.read(activeTourControllerProvider).locationMessage,
        contains('安全方便时'));
    expect(
        container.read(activeTourControllerProvider).evidenceUploads, isEmpty);

    await controller.captureEvidence(_fragment);
    final upload = container
        .read(activeTourControllerProvider)
        .evidenceUploadFor('fragment-1');
    expect(upload?.filePath, '/tmp/private-clue.jpg');
    expect(upload?.phase, EvidenceUploadPhase.queued);
    expect(store.outbox.single.type, 'evidence');
    expect(container.read(activeTourControllerProvider).errorMessage,
        contains('不会阻止继续'));
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 30; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not reached');
}

const _region = TriggerRegion(
  latitude: 22.5381,
  longitude: 113.9227,
  entryRadiusM: 60,
  exitRadiusM: 90,
  maxAccuracyM: 50,
  qualifyingSamples: 2,
  sampleWindowSeconds: 15,
  cooldownSeconds: 120,
  auditState: 'in_review',
);

const _audio = NarrationAsset(
  url: 'https://example.test/fragment.m4a',
  mimeType: 'audio/mp4',
  sizeBytes: 0,
  scriptVersion: 'v1',
);

const _fragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '第一条线索',
  interactionType: 'passive',
  reviewState: 'in_review',
  triggerRegion: _region,
  audio: _audio,
  displayTheme: '潮汐里的旧城',
  expectedDurationSeconds: 121,
);

const _secondFragment = StoryFragment(
  id: 'fragment-2',
  position: 2,
  safePreview: '第二条线索',
  interactionType: 'passive',
  reviewState: 'in_review',
  triggerRegion: _region,
  audio: _audio,
  dependencyIds: ['fragment-1'],
);

const _thirdFragment = StoryFragment(
  id: 'fragment-3',
  position: 3,
  safePreview: '第三条线索',
  interactionType: 'passive',
  reviewState: 'in_review',
  triggerRegion: _region,
  audio: _audio,
  dependencyIds: ['fragment-2'],
);

const _manifest = AudioTourManifest(
  title: '测试导览',
  centralQuestion: '中心为什么迁移？',
  scriptVersion: 'v1',
  reviewState: 'in_review',
  fieldAuditState: 'in_review',
  productionReady: false,
  demoLabel: '研究预览',
  contentMethod: '测试内容',
  downloadSizeBytes: 0,
  fragments: [_fragment],
);

const _route = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'in_review',
  stops: [],
  audioTour: _manifest,
);

const _offlineFragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '第一条线索',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _region,
  audio: _audio,
  title: '离线第一条线索',
  transcript: '离线完整文字稿',
  state: 'undiscovered',
);

const _offlineRoute = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'published',
  stops: [],
  audioTour: AudioTourManifest(
    title: '测试导览',
    centralQuestion: '中心为什么迁移？',
    scriptVersion: 'v1',
    reviewState: 'reviewed',
    fieldAuditState: 'reviewed',
    productionReady: true,
    demoLabel: null,
    contentMethod: '测试内容',
    downloadSizeBytes: 0,
    fragments: [_offlineFragment],
  ),
);

const _twoFragmentManifest = AudioTourManifest(
  title: '测试导览',
  centralQuestion: '中心为什么迁移？',
  scriptVersion: 'v1',
  reviewState: 'in_review',
  fieldAuditState: 'in_review',
  productionReady: false,
  demoLabel: '研究预览',
  contentMethod: '测试内容',
  downloadSizeBytes: 0,
  fragments: [_fragment, _secondFragment],
);

const _twoFragmentRoute = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'in_review',
  stops: [],
  audioTour: _twoFragmentManifest,
);

const _threeFragmentManifest = AudioTourManifest(
  title: '测试导览',
  centralQuestion: '中心为什么迁移？',
  scriptVersion: 'v1',
  reviewState: 'in_review',
  fieldAuditState: 'in_review',
  productionReady: false,
  demoLabel: '研究预览',
  contentMethod: '测试内容',
  downloadSizeBytes: 0,
  fragments: [_fragment, _secondFragment, _thirdFragment],
);

const _threeFragmentRoute = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'in_review',
  stops: [],
  audioTour: _threeFragmentManifest,
);

const _session = JourneySession(
  id: 'journey-1',
  routeId: 'route-1',
  status: 'active',
  currentStopPosition: 1,
  arrivedStopId: null,
  answeredStopIds: {},
  progress: 0,
);

JourneySession _sessionFor(String id, String routeId) => JourneySession(
      id: id,
      routeId: routeId,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
    );

RouteExperience _routeFor(
  String routeId,
  String fragmentId,
  String title,
  String artwork,
) {
  final fragment = StoryFragment(
    id: fragmentId,
    position: 1,
    safePreview: '$title 的线索',
    interactionType: 'passive',
    reviewState: 'reviewed',
    triggerRegion: _region,
    audio: NarrationAsset(
      url: 'https://example.test/$fragmentId.m4a',
      mimeType: 'audio/mp4',
      sizeBytes: 1,
      scriptVersion: 'v1',
    ),
  );
  return RouteExperience(
    id: routeId,
    slug: routeId,
    title: title,
    subtitle: '测试',
    description: '跨景点切换测试',
    durationMinutes: 10,
    distanceKm: 1,
    difficulty: '轻松',
    theme: '历史',
    heroImage: artwork,
    contentStatus: 'published',
    stops: const [],
    audioTour: AudioTourManifest(
      title: title,
      centralQuestion: '为什么？',
      scriptVersion: 'v1',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: null,
      contentMethod: '测试',
      downloadSizeBytes: 1,
      fragments: [fragment],
    ),
  );
}

final _completedContext = JourneyContext(
  journey: const JourneySession(
    id: 'journey-completed',
    routeId: 'route-1',
    status: 'completed',
    currentStopPosition: 1,
    arrivedStopId: null,
    answeredStopIds: {},
    progress: 1,
  ),
  route: _twoFragmentRoute,
  journeyKind: 'fragmented',
  collectedCount: 2,
  totalCount: 2,
  ledger: StoryLedger(
    centralQuestion: '中心为什么迁移？',
    collectedCount: 2,
    totalCount: 2,
    reconstructionUnlocked: true,
    entries: const [
      StoryFragment(
        id: 'fragment-1',
        position: 1,
        safePreview: '第一条线索',
        interactionType: 'passive',
        reviewState: 'reviewed',
        triggerRegion: _region,
        audio: _audio,
        title: '第一条线索',
        transcript: '第一条正文',
        state: 'collected',
      ),
      StoryFragment(
        id: 'fragment-2',
        position: 2,
        safePreview: '第二条线索',
        interactionType: 'passive',
        reviewState: 'reviewed',
        triggerRegion: _region,
        audio: _audio,
        title: '第二条线索',
        transcript: '第二条正文',
        state: 'collected',
        dependencyIds: ['fragment-1'],
      ),
    ],
  ),
);

const _voiceProfiles = [
  NarrationVoiceProfile(
      id: 'voice-default',
      slug: 'default',
      name: '原声',
      description: '默认声音',
      isDefault: true),
  NarrationVoiceProfile(
      id: 'voice-warm',
      slug: 'warm',
      name: '温柔',
      description: '温柔声音',
      isDefault: false),
];

const _voiceFragment = StoryFragment(
  id: 'voice-fragment',
  position: 1,
  safePreview: '声音线索',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _region,
  audio: NarrationAsset(
      url: 'https://example.test/default.mp3',
      mimeType: 'audio/mpeg',
      sizeBytes: 0,
      scriptVersion: 'v1'),
  title: '声音线索',
  transcript: '不因音色改变的文字稿',
  state: 'triggered',
  narrationTracks: {
    'voice-default': NarrationTrack(
        transcriptHash: 'same',
        audio: NarrationAsset(
            url: 'https://example.test/default.mp3',
            mimeType: 'audio/mpeg',
            sizeBytes: 0,
            scriptVersion: 'v1')),
    'voice-warm': NarrationTrack(
        transcriptHash: 'same',
        audio: NarrationAsset(
            url: 'https://example.test/warm.mp3',
            mimeType: 'audio/mpeg',
            sizeBytes: 0,
            scriptVersion: 'v1')),
  },
);

const _voiceRoute = RouteExperience(
  id: 'voice-route',
  slug: 'voice-route',
  title: '声音路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'published',
  stops: [],
  audioTour: AudioTourManifest(
      title: '声音导览',
      centralQuestion: '为什么？',
      scriptVersion: 'v1',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: null,
      contentMethod: '测试',
      downloadSizeBytes: 0,
      defaultNarrationProfileId: 'voice-default',
      narrationProfiles: _voiceProfiles,
      fragments: [_voiceFragment]),
);

class _FragmentRepository extends DemoExperienceRepository {
  _FragmentRepository() : super(latency: Duration.zero);

  @override
  Future<void> startActiveTour(String journeyId) async {}

  @override
  Future<void> stopActiveTour(String journeyId) async {}

  @override
  Future<RouteExperience> routeBySlug(String slug) async => _route;

  @override
  Future<JourneySession> startOrResume(String routeId) async => _session;

  @override
  Future<StoryLedger> ledger(String journeyId) async => const StoryLedger(
        centralQuestion: '中心为什么迁移？',
        collectedCount: 0,
        totalCount: 1,
        reconstructionUnlocked: false,
        entries: [_fragment],
      );
}

class _ProgressingFragmentRepository extends _FragmentRepository {
  _ProgressingFragmentRepository({Map<String, String>? initialStates})
      : _states = Map<String, String>.from(initialStates ??
            const {
              'fragment-1': 'undiscovered',
              'fragment-2': 'undiscovered',
            });

  final Map<String, String> _states;
  int selectionTriggerCalls = 0;
  int selectionAcknowledgeCalls = 0;

  bool isCollected(String fragmentId) => _states[fragmentId] == 'collected';
  String? stateOf(String fragmentId) => _states[fragmentId];

  @override
  Future<StoryFragment> triggerFragment(String journeyId, String fragmentId,
      {required String method,
      required String idempotencyKey,
      double? latitude,
      double? longitude,
      double? accuracyM}) async {
    selectionTriggerCalls += 1;
    _states[fragmentId] = 'triggered';
    return _fragmentWithState(fragmentId, 'triggered', revealed: true);
  }

  @override
  Future<StoryFragment> acknowledgePlayback(String journeyId, String fragmentId,
      double progress, String idempotencyKey) async {
    selectionAcknowledgeCalls += 1;
    _states[fragmentId] = 'collected';
    return _fragmentWithState(fragmentId, 'collected', revealed: true);
  }

  @override
  Future<StoryLedger> ledger(String journeyId) async {
    final entries = _states.entries
        .map((entry) => _fragmentWithState(entry.key, entry.value,
            revealed: entry.value != 'undiscovered'))
        .toList();
    final collected = entries.where((entry) => entry.isCollected).length;
    return StoryLedger(
      centralQuestion: '中心为什么迁移？',
      collectedCount: collected,
      totalCount: entries.length,
      reconstructionUnlocked: collected == entries.length,
      entries: entries,
    );
  }

  StoryFragment _fragmentWithState(String id, String state,
      {required bool revealed}) {
    final source = [_fragment, _secondFragment, _thirdFragment]
        .firstWhere((fragment) => fragment.id == id);
    return StoryFragment(
      id: source.id,
      position: source.position,
      safePreview: source.safePreview,
      interactionType: source.interactionType,
      reviewState: source.reviewState,
      triggerRegion: source.triggerRegion,
      audio: source.audio,
      title: revealed ? source.safePreview : null,
      transcript: revealed ? '${source.safePreview}的正文' : null,
      state: state,
      dependencyIds: source.dependencyIds,
    );
  }
}

class _CountingProgressRepository extends _ProgressingFragmentRepository {
  _CountingProgressRepository()
      : super(initialStates: const {
          'fragment-1': 'collected',
          'fragment-2': 'collected',
        });

  int startActiveCalls = 0;
  int acknowledgeCalls = 0;

  @override
  Future<void> startActiveTour(String journeyId) async {
    startActiveCalls += 1;
  }

  @override
  Future<StoryFragment> acknowledgePlayback(
    String journeyId,
    String fragmentId,
    double progress,
    String idempotencyKey,
  ) async {
    acknowledgeCalls += 1;
    return super.acknowledgePlayback(
      journeyId,
      fragmentId,
      progress,
      idempotencyKey,
    );
  }
}

class _ReplayProgressRepository extends _ProgressingFragmentRepository {
  _ReplayProgressRepository()
      : super(initialStates: const {
          'fragment-1': 'triggered',
          'fragment-2': 'undiscovered',
        });

  int acknowledgeCalls = 0;

  bool isTriggered(String fragmentId) => _states[fragmentId] == 'triggered';

  @override
  Future<StoryFragment> acknowledgePlayback(
    String journeyId,
    String fragmentId,
    double progress,
    String idempotencyKey,
  ) async {
    acknowledgeCalls += 1;
    return super.acknowledgePlayback(
      journeyId,
      fragmentId,
      progress,
      idempotencyKey,
    );
  }
}

class _EarlyAdvanceRepository extends _ProgressingFragmentRepository {
  _EarlyAdvanceRepository()
      : super(initialStates: const {
          'fragment-1': 'triggered',
          'fragment-2': 'undiscovered',
        });

  int acknowledgeCalls = 0;

  @override
  Future<StoryFragment> acknowledgePlayback(
    String journeyId,
    String fragmentId,
    double progress,
    String idempotencyKey,
  ) async {
    acknowledgeCalls += 1;
    return super.acknowledgePlayback(
      journeyId,
      fragmentId,
      progress,
      idempotencyKey,
    );
  }
}

class _FailOnceTriggerRepository extends _ProgressingFragmentRepository {
  _FailOnceTriggerRepository()
      : super(initialStates: const {
          'fragment-1': 'collected',
          'fragment-2': 'undiscovered',
        });

  bool shouldFail = true;
  int acknowledgeCalls = 0;

  @override
  Future<StoryFragment> triggerFragment(
    String journeyId,
    String fragmentId, {
    required String method,
    required String idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracyM,
  }) async {
    if (shouldFail) {
      shouldFail = false;
      throw StateError('temporary trigger failure');
    }
    return super.triggerFragment(
      journeyId,
      fragmentId,
      method: method,
      idempotencyKey: idempotencyKey,
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
    );
  }

  @override
  Future<StoryFragment> acknowledgePlayback(
    String journeyId,
    String fragmentId,
    double progress,
    String idempotencyKey,
  ) async {
    acknowledgeCalls += 1;
    return super.acknowledgePlayback(
      journeyId,
      fragmentId,
      progress,
      idempotencyKey,
    );
  }
}

class _CrossRouteRepository extends _FragmentRepository {
  final stoppedJourneyIds = <String>[];
  final acknowledgedJourneyIds = <String>[];

  @override
  Future<void> stopActiveTour(String journeyId) async {
    stoppedJourneyIds.add(journeyId);
  }

  @override
  Future<StoryLedger> ledger(String journeyId) async {
    final suffix = journeyId.split('-').last;
    final fragmentId = 'fragment-$suffix';
    final source = _routeFor(
      'route-$suffix',
      fragmentId,
      '景点 ${suffix.toUpperCase()}',
      '$suffix.jpg',
    ).audioTour!.fragments.single;
    final revealed = StoryFragment(
      id: source.id,
      position: source.position,
      safePreview: source.safePreview,
      interactionType: source.interactionType,
      reviewState: source.reviewState,
      triggerRegion: source.triggerRegion,
      audio: source.audio,
      title: source.safePreview,
      transcript: '${source.safePreview}正文',
      state: 'triggered',
    );
    return StoryLedger(
      centralQuestion: '为什么？',
      collectedCount: 0,
      totalCount: 1,
      reconstructionUnlocked: false,
      entries: [revealed],
    );
  }

  @override
  Future<StoryFragment> acknowledgePlayback(
    String journeyId,
    String fragmentId,
    double progress,
    String idempotencyKey,
  ) async {
    acknowledgedJourneyIds.add(journeyId);
    return (await ledger(journeyId)).entries.single;
  }
}

class _OfflineEvidenceRepository extends _FragmentRepository {
  @override
  Future<EvidenceRecord> uploadEvidence(
    String journeyId,
    String fragmentId,
    String filePath,
    String idempotencyKey,
  ) async {
    throw StateError('offline');
  }
}

class _ReconstructionRepository extends _ProgressingFragmentRepository {
  _ReconstructionRepository()
      : super(initialStates: const {
          'fragment-1': 'collected',
          'fragment-2': 'collected',
        });

  List<String> submittedIds = [];
  int reconstructionAttempts = 0;

  @override
  Future<StoryLedger> ledger(String journeyId) async {
    final current = await super.ledger(journeyId);
    return StoryLedger(
      centralQuestion: current.centralQuestion,
      collectedCount: current.collectedCount,
      totalCount: current.totalCount,
      reconstructionUnlocked: true,
      entries: current.entries,
      reconstructionItems: const [
        ReconstructionItem(id: 'cause-2', text: '服务器给出的第二项'),
        ReconstructionItem(id: 'cause-1', text: '服务器给出的第一项'),
      ],
    );
  }

  @override
  Future<ReconstructionResult> reconstruct(
      String journeyId, List<String> relationships) async {
    submittedIds = List<String>.from(relationships);
    reconstructionAttempts += 1;
    if (reconstructionAttempts > 1) {
      return const ReconstructionResult(
          correct: true, feedback: [], completeStoryUnlocked: true);
    }
    return const ReconstructionResult(
        correct: false,
        feedback: [
          {'position': 1, 'submitted': 'cause-2'}
        ],
        completeStoryUnlocked: false);
  }

  @override
  Future<FragmentRecap> fragmentRecap(String journeyId) async =>
      const FragmentRecap(
          title: '测试故事',
          centralQuestion: '中心为什么迁移？',
          completeStory: '测试完整故事正文',
          causalModel: ['第一项', '第二项'],
          fragments: [_fragment, _secondFragment]);
}

class _VoiceFragmentRepository extends _FragmentRepository {
  @override
  Future<StoryLedger> ledger(String journeyId) async => const StoryLedger(
        centralQuestion: '为什么？',
        collectedCount: 0,
        totalCount: 1,
        reconstructionUnlocked: false,
        defaultNarrationProfileId: 'voice-default',
        narrationProfiles: _voiceProfiles,
        entries: [_voiceFragment],
      );
}

class _AuthenticatedRepository extends AuthRepository {
  _AuthenticatedRepository() : super(Dio());

  @override
  AuthSession? get session => const AuthSession(
        user: AuthUser(
            id: 'account-a', username: 'traveler', accountKind: 'registered'),
        token: 'test-token',
      );
}

class _RecordingLocationTracker implements LocationTracker {
  int permissionRequests = 0;
  int sampleSubscriptions = 0;
  int stopCalls = 0;

  @override
  Future<TourLocationPermission> requestPermission() async {
    permissionRequests += 1;
    return TourLocationPermission.granted;
  }

  @override
  Stream<LocationSample> samples() {
    sampleSubscriptions += 1;
    return const Stream<LocationSample>.empty();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class _DeniedLocationTracker implements LocationTracker {
  @override
  Future<TourLocationPermission> requestPermission() async =>
      TourLocationPermission.denied;

  @override
  Stream<LocationSample> samples() => const Stream.empty();

  @override
  Future<void> stop() async {}
}

class _StreamingLocationTracker implements LocationTracker {
  final _samples = StreamController<LocationSample>.broadcast(sync: true);
  int sampleSubscriptions = 0;

  void emit(LocationSample sample) => _samples.add(sample);

  @override
  Future<TourLocationPermission> requestPermission() async =>
      TourLocationPermission.granted;

  @override
  Stream<LocationSample> samples() {
    sampleSubscriptions += 1;
    return _samples.stream;
  }

  @override
  Future<void> stop() async {}

  Future<void> dispose() => _samples.close();
}

class _MemoryLocationModeStore implements LocationModeStore {
  _MemoryLocationModeStore(this.mode);
  TourLocationMode mode;

  @override
  Future<TourLocationMode> read() async => mode;

  @override
  Future<void> write(TourLocationMode mode) async => this.mode = mode;
}

class _NoopPreparedRouteService extends PreparedRouteService {
  _NoopPreparedRouteService(TourStore store) : super(Dio(), store);

  @override
  Future<Map<String, String>> prepare(
          AudioTourManifest manifest, String? profileId) async =>
      {};
}

class _OfflinePackageService extends RouteOfflinePackageService {
  _OfflinePackageService(TourStore store)
      : super(Dio(), store, _NoopPreparedRouteService(store));

  @override
  Future<InstalledRoutePackage?> load(String slug) async =>
      const InstalledRoutePackage(
        city: CityExperience(
          id: 'city-a',
          slug: 'city-a',
          name: '测试城',
          subtitle: '测试',
          heroImage: '',
        ),
        route: _offlineRoute,
        version: 'v1',
        checksumSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        narrationProfileId: null,
        preparedPaths: {'fragment-1': '/cache/fragment-1.m4a'},
        raw: {},
      );
}

class _RecordingPreparedRouteService extends PreparedRouteService {
  _RecordingPreparedRouteService(TourStore store) : super(Dio(), store);
  final profileIds = <String?>[];

  @override
  Future<Map<String, String>> prepare(
      AudioTourManifest manifest, String? profileId) async {
    profileIds.add(profileId);
    return {};
  }
}

class _MemoryTourStore implements TourStore {
  final snapshots = <String, Map<String, dynamic>>{};
  final outbox = <OutboxEvent>[];

  @override
  Future<void> clearPrivateData() async {
    snapshots.clear();
    outbox.clear();
  }

  @override
  Future<void> acknowledge(String id) async =>
      outbox.removeWhere((event) => event.id == id);

  @override
  Future<void> enqueue(OutboxEvent event) async => outbox.add(event);

  @override
  Future<List<OutboxEvent>> pending() async => List.unmodifiable(outbox);

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
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    snapshots[key] = value;
  }

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}

class _SequenceCameraCapture implements CameraCapture {
  _SequenceCameraCapture(this.results);

  final List<String?> results;
  int _index = 0;

  @override
  Future<String?> capture() async => results[_index++];
}

class _SilentNarrationPlayer implements NarrationPlayer {
  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}

class _RecordingNarrationPlayer extends _SilentNarrationPlayer {
  final urls = <String>[];
  final _playing = StreamController<bool>.broadcast(sync: true);
  String? failUrl;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {
    urls.add(fragment.audio.url);
    if (fragment.audio.url == failUrl) throw StateError('replacement failed');
    _playing.add(true);
  }

  @override
  Future<void> dispose() => _playing.close();
}

class _ControllableNarrationPlayer implements NarrationPlayer {
  final _completed = StreamController<bool>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration?>.broadcast(sync: true);
  final playedFragmentIds = <String>[];

  void completeNaturally() => _completed.add(true);
  void emitPosition(Duration value) => _position.add(value);
  void emitDuration(Duration value) => _duration.add(value);

  @override
  Stream<bool> get completedStream => _completed.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Future<void> dispose() async {
    await _completed.close();
    await _playing.close();
    await _position.close();
    await _duration.close();
  }

  @override
  Future<void> pause() async => _playing.add(false);

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {
    playedFragmentIds.add(fragment.id);
    _playing.add(true);
  }

  @override
  Future<void> replay() async => _playing.add(true);

  @override
  Future<void> resume() async => _playing.add(true);

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async => _playing.add(false);
}

class _GenerationNarrationPlayer implements NarrationPlayer {
  final _completedControllers = <StreamController<bool>>[];
  final _positionControllers = <StreamController<Duration>>[];
  final _playingControllers = <StreamController<bool>>[];
  final _durationControllers = <StreamController<Duration?>>[];
  final playedFragmentIds = <String>[];
  String? failFragmentId;
  String? activeFragmentId;
  bool overlapDetected = false;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int replayCalls = 0;
  int stopCalls = 0;
  double lastSpeed = 1;
  Duration? lastSeek;

  @override
  Stream<bool> get completedStream {
    final controller = StreamController<bool>.broadcast(sync: true);
    _completedControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<Duration?> get durationStream {
    final controller = StreamController<Duration?>.broadcast(sync: true);
    _durationControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<bool> get playingStream {
    final controller = StreamController<bool>.broadcast(sync: true);
    _playingControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<Duration> get positionStream {
    final controller = StreamController<Duration>.broadcast(sync: true);
    _positionControllers.add(controller);
    return controller.stream;
  }

  void emitCurrentCompletion() => _completedControllers.last.add(true);

  void emitCurrentPosition(Duration value) =>
      _positionControllers.last.add(value);

  void emitCompletion(int generationIndex) =>
      _completedControllers[generationIndex].add(true);

  void emitPosition(int generationIndex, Duration value) =>
      _positionControllers[generationIndex].add(value);

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {
    if (activeFragmentId != null) overlapDetected = true;
    activeFragmentId = fragment.id;
    playedFragmentIds.add(fragment.id);
    if (fragment.id == failFragmentId) {
      activeFragmentId = null;
      throw StateError('load failed');
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    if (_playingControllers.isNotEmpty) {
      _playingControllers.last.add(false);
    }
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    if (_playingControllers.isNotEmpty) {
      _playingControllers.last.add(true);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    if (_positionControllers.isNotEmpty) {
      _positionControllers.last.add(position);
    }
  }

  @override
  Future<void> replay() async {
    replayCalls += 1;
    await resume();
  }

  @override
  Future<void> setSpeed(double speed) async {
    lastSpeed = speed;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    activeFragmentId = null;
    if (_playingControllers.isNotEmpty) {
      _playingControllers.last.add(false);
    }
  }

  @override
  Future<void> dispose() async {
    for (final controller in _completedControllers) {
      await controller.close();
    }
    for (final controller in _positionControllers) {
      await controller.close();
    }
    for (final controller in _playingControllers) {
      await controller.close();
    }
    for (final controller in _durationControllers) {
      await controller.close();
    }
  }
}
