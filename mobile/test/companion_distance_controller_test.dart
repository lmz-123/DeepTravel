import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/application/nearby_story_points.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/companion_distance_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/offline_package_controller.dart';

void main() {
  test('nearest unexplored place takes priority over current or heard audio',
      () {
    final fixture = _Fixture();
    final current = fixture.route.audioTour!.fragments.first;
    fixture.tour.emit(fixture.live(
      ledger: [_revealed(current, heard: true)],
    ).copyWith(current: current, selectedFragmentId: current.id));

    final value = fixture.value;
    expect(value.target?.fragment.id, 'middle');
    expect(value.target?.distanceMeters, closeTo(111.2, .5));
    expect(value.points.first.fragment.id, 'near');
    expect(value.points.first.status, NearbyStoryPointStatus.heard);
    expect(value.allExplored, isFalse);
  });

  test('revealed but unfinished stories are excluded from unexplored', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live(ledger: [
      _revealed(fixture.route.audioTour!.fragments.first),
    ]));
    expect(fixture.value.target?.fragment.id, 'middle');
    expect(fixture.value.points.first.status, NearbyStoryPointStatus.triggered);
  });

  test('all explored falls back to nearest place', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live(ledger: [
      for (final fragment in fixture.route.audioTour!.fragments)
        _revealed(fragment, heard: true),
    ]));
    expect(fixture.value.target?.fragment.id, 'near');
    expect(fixture.value.allExplored, isTrue);
  });

  test('manual target remains fixed and never changes audio or session', () {
    final fixture = _Fixture();
    final initial = fixture.live().copyWith(
          current: _revealed(fixture.route.audioTour!.fragments.first),
          selectedFragmentId: 'near',
          isPlaying: true,
          position: const Duration(seconds: 47),
        );
    fixture.tour.emit(initial);
    fixture.value;
    fixture.controller.selectPoint('far');

    expect(fixture.value.mode, CompanionDistanceMode.manual);
    expect(fixture.value.target?.fragment.id, 'far');
    expect(fixture.tour.snapshot, same(initial));
    fixture.tour.emit(initial.copyWith(
      latestLocationSample: fixture.sample(latitude: .0001),
    ));
    expect(fixture.value.target?.fragment.id, 'far');
    expect(fixture.tour.snapshot.selectedFragmentId, 'near');
    expect(fixture.tour.snapshot.position, const Duration(seconds: 47));
    expect(fixture.tour.snapshot.isPlaying, isTrue);

    fixture.controller.useAutomatic();
    expect(fixture.value.mode, CompanionDistanceMode.automatic);
    expect(fixture.value.target?.fragment.id, 'near');
  });

  test('GPS jitter does not switch target until meaningfully nearer', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live(latitude: .00049));
    expect(fixture.value.target?.fragment.id, 'near');

    fixture.tour.emit(fixture.live(latitude: .00051));
    expect(fixture.value.target?.fragment.id, 'near');

    fixture.tour.emit(fixture.live(latitude: .0008));
    expect(fixture.value.target?.fragment.id, 'middle');
    fixture.tour.emit(fixture.live(latitude: .00051));
    expect(fixture.value.target?.fragment.id, 'middle');
  });

  test('exploring automatic target advances to next unexplored place', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live());
    expect(fixture.value.target?.fragment.id, 'near');
    fixture.tour.emit(fixture.live(ledger: [
      _revealed(fixture.route.audioTour!.fragments.first),
    ]));
    expect(fixture.value.target?.fragment.id, 'middle');
  });

  test('expired automatic target clears when that place becomes explored', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live());
    expect(fixture.value.target?.fragment.id, 'near');
    final expiredSample = fixture.sample();
    fixture.now = fixture.now.add(const Duration(seconds: 61));
    fixture.tour.emit(fixture.live(ledger: [
      _revealed(fixture.route.audioTour!.fragments.first),
    ]).copyWith(latestLocationSample: expiredSample));
    expect(fixture.value.target, isNull);
    expect(fixture.value.hasLocation, isFalse);
  });

  test('idle and simulated locations never invent distance or nearest place',
      () async {
    final fixture = _Fixture();
    fixture.value;
    await fixture.container.read(offlineAwareRouteProvider('walk').future);
    expect(fixture.value.points, hasLength(3));
    expect(fixture.value.target, isNull);
    fixture.controller.selectPoint('far');
    expect(fixture.value.target?.fragment.id, 'far');
    expect(fixture.value.target?.distanceMeters, isNull);
    expect(fixture.tour.snapshot.session, isNull);

    fixture.tour.emit(fixture.live().copyWith(
      locationMode: TourLocationMode.simulated,
      nearbyStoryPoints: [
        NearbyStoryPoint(
          fragment: fixture.route.audioTour!.fragments.last,
          status: NearbyStoryPointStatus.inRange,
          distanceMeters: 20,
        ),
      ],
    ));
    expect(fixture.value.mode, CompanionDistanceMode.manual);
    expect(fixture.value.target?.fragment.id, 'far');
    expect(fixture.value.hasLocation, isFalse);
    expect(fixture.value.points.every((p) => p.distanceMeters == null), isTrue);
  });

  test(
      'distance estimates accept ordinary fixes without arrival-level accuracy',
      () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture
        .live()
        .copyWith(latestLocationSample: fixture.sample(accuracy: 70)));
    expect(fixture.value.hasLocation, isTrue);
    expect(fixture.value.isApproximate, isTrue);
    expect(fixture.value.target?.distanceMeters, isNotNull);
    expect(fixture.tour.snapshot.current, isNull);
    expect(fixture.tour.snapshot.isPlaying, isFalse);
  });

  test('a stationary recent fix remains an estimate after 15 seconds', () {
    final fixture = _Fixture();
    final live = fixture.live();
    fixture.now = fixture.now.add(const Duration(seconds: 30));
    fixture.tour.emit(live);
    expect(fixture.value.hasLocation, isTrue);
    expect(fixture.value.target?.distanceMeters, isNotNull);
  });

  test('invalid and inaccurate samples leave distances unknown', () {
    final fixture = _Fixture();
    for (final sample in [
      fixture.sample(latitude: double.nan),
      fixture.sample(latitude: 91),
      fixture.sample(accuracy: -1),
      fixture.sample(accuracy: double.infinity),
      fixture.sample(accuracy: 201),
      fixture.sample(time: fixture.now.subtract(const Duration(seconds: 61))),
      fixture.sample(time: fixture.now.add(const Duration(seconds: 6))),
    ]) {
      fixture.tour.emit(fixture.live().copyWith(latestLocationSample: sample));
      expect(fixture.value.hasLocation, isFalse);
      expect(fixture.value.target, isNull);
      expect(
          fixture.value.points.every((p) => p.distanceMeters == null), isTrue);
    }
  });

  testWidgets('stale distance disappears without another GPS update',
      (tester) async {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live());
    fixture.value;
    fixture.controller.selectPoint('far');
    final subscription = fixture.container.listen(
        companionDistanceControllerProvider('walk'), (previous, next) {});
    addTearDown(subscription.close);
    expect(fixture.value.hasLocation, isTrue);

    fixture.now = fixture.now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 61));
    expect(fixture.value.target?.fragment.id, 'far');
    expect(fixture.value.target?.distanceMeters, isNull);
    expect(fixture.value.hasLocation, isFalse);
    expect(fixture.value.mode, CompanionDistanceMode.manual);
  });

  test('navigation keeps selection; route switch, stop and account reset it',
      () async {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live());
    final provider = companionDistanceControllerProvider('walk');
    final subscription =
        fixture.container.listen(provider, (previous, next) {});
    fixture.controller.selectPoint('far');
    fixture.value;
    subscription.close();
    await fixture.container.pump();
    expect(fixture.value.target?.fragment.id, 'far');

    final otherProvider = companionDistanceControllerProvider('other');
    fixture.container.read(otherProvider);
    await fixture.container.read(offlineAwareRouteProvider('other').future);
    expect(fixture.container.read(otherProvider).mode,
        CompanionDistanceMode.automatic);
    expect(fixture.container.read(otherProvider).target, isNull);
    fixture.controller.reset();
    expect(fixture.value.mode, CompanionDistanceMode.automatic);

    fixture.controller.selectPoint('far');
    fixture.value;
    fixture.tour.emit(fixture.live().copyWith(
          status: 'stopped',
          clearLatestLocationSample: true,
        ));
    expect(fixture.value.mode, CompanionDistanceMode.automatic);
    expect(fixture.value.target, isNull);

    fixture.tour.emit(fixture.live());
    fixture.controller.selectPoint('far');
    fixture.value;
    fixture.container.read(_userProvider.notifier).setUser('user-two');
    expect(fixture.value.mode, CompanionDistanceMode.automatic);
  });

  test('replacing or completing a session resets target', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live());
    fixture.value;
    fixture.controller.selectPoint('far');
    fixture.value;
    fixture.tour.emit(fixture.live(sessionId: 'new-session'));
    expect(fixture.value.mode, CompanionDistanceMode.automatic);
    fixture.controller.selectPoint('far');
    fixture.value;
    fixture.tour.emit(fixture.live(sessionId: 'new-session').copyWith(
          session:
              _session('walk', 'new-session').copyWith(status: 'completed'),
        ));
    expect(fixture.value.mode, CompanionDistanceMode.automatic);
    expect(fixture.value.hasLocation, isFalse);
  });

  test('new manual choice after stopping is kept when starting again', () {
    final fixture = _Fixture();
    fixture.tour.emit(fixture.live());
    fixture.value;
    fixture.controller.selectPoint('far');
    fixture.value;
    fixture.tour.emit(fixture.live().copyWith(status: 'stopped'));
    expect(fixture.value.mode, CompanionDistanceMode.automatic);

    fixture.controller.selectPoint('middle');
    expect(fixture.value.mode, CompanionDistanceMode.manual);
    fixture.tour.emit(fixture.live(sessionId: 'next-walk'));
    expect(fixture.value.mode, CompanionDistanceMode.manual);
    expect(fixture.value.target?.fragment.id, 'middle');
  });

  test('idle route load errors expose retry state without leaking other route',
      () async {
    final tour = _Tour();
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('user'),
      activeTourControllerProvider.overrideWith(() => tour),
      offlineAwareRouteProvider.overrideWith((ref, slug) =>
          Future<RouteExperience>.error(StateError('unavailable'))),
    ]);
    addTearDown(container.dispose);
    final provider = companionDistanceControllerProvider('missing');
    expect(container.read(provider).isLoading, isTrue);
    await container
        .read(offlineAwareRouteProvider('missing').future)
        .catchError((Object _) => _route('unrelated'));
    expect(container.read(provider).error, isA<StateError>());
    expect(container.read(provider).points, isEmpty);
    expect(container.read(provider).target, isNull);
  });
}

final _userProvider = NotifierProvider<_User, String>(_User.new);

class _User extends Notifier<String> {
  @override
  String build() => 'user-one';
  void setUser(String value) => state = value;
}

class _Tour extends ActiveTourController {
  @override
  ActiveTourState build() => const ActiveTourState();
  void emit(ActiveTourState value) => state = value;
  ActiveTourState get snapshot => state;
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      activeTourControllerProvider.overrideWith(() => tour),
      companionDistanceNowProvider.overrideWithValue(() => now),
      offlineAwareRouteProvider.overrideWith((ref, slug) async => _route(slug)),
    ]);
    container.read(activeTourControllerProvider);
    addTearDown(container.dispose);
  }

  DateTime now = DateTime.utc(2026, 9, 30, 12);
  final route = _route('walk');
  final tour = _Tour();
  late final ProviderContainer container;
  CompanionDistanceState get value =>
      container.read(companionDistanceControllerProvider('walk'));
  CompanionDistanceController get controller =>
      container.read(companionDistanceControllerProvider('walk').notifier);

  LocationSample sample(
          {double latitude = 0, double accuracy = 8, DateTime? time}) =>
      LocationSample(
        latitude: latitude,
        longitude: 0,
        accuracyM: accuracy,
        recordedAt: time ?? now,
      );

  ActiveTourState live({
    double latitude = 0,
    List<StoryFragment> ledger = const [],
    String sessionId = 'session',
  }) =>
      ActiveTourState(
        route: route,
        session: _session(route.id, sessionId),
        status: 'listening',
        latestLocationSample: sample(latitude: latitude),
        ledger: StoryLedger(
          centralQuestion: '',
          collectedCount: ledger.where((entry) => entry.isCollected).length,
          totalCount: 3,
          reconstructionUnlocked: false,
          entries: ledger,
        ),
      );
}

JourneySession _session(String routeId, String id) => JourneySession(
      id: id,
      routeId: routeId,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
    );

RouteExperience _route(String slug) => RouteExperience(
      id: slug,
      slug: slug,
      title: '沿途地点',
      subtitle: '',
      description: '',
      durationMinutes: 30,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: const [],
      centerLatitude: 40,
      centerLongitude: 100,
      audioTour: AudioTourManifest(
        title: '',
        centralQuestion: '',
        scriptVersion: 'v1',
        reviewState: 'approved',
        fieldAuditState: 'approved',
        productionReady: true,
        demoLabel: null,
        contentMethod: '',
        downloadSizeBytes: 1,
        fragments: [
          _fragment('near', 1, 0),
          _fragment('middle', 2, .001),
          _fragment('far', 3, .003)
        ],
      ),
    );

StoryFragment _fragment(String id, int position, double latitude) =>
    StoryFragment(
      id: id,
      position: position,
      safePreview: id,
      interactionType: 'listen',
      reviewState: 'approved',
      triggerRegion: TriggerRegion(
        latitude: latitude,
        longitude: 0,
        entryRadiusM: 50,
        exitRadiusM: 80,
        maxAccuracyM: 50,
        qualifyingSamples: 2,
        sampleWindowSeconds: 15,
        cooldownSeconds: 30,
        auditState: 'approved',
      ),
      audio: const NarrationAsset(
          url: '', mimeType: 'audio/mpeg', sizeBytes: 1, scriptVersion: 'v1'),
    );

StoryFragment _revealed(StoryFragment fragment, {bool heard = false}) =>
    StoryFragment(
      id: fragment.id,
      position: fragment.position,
      safePreview: fragment.safePreview,
      interactionType: fragment.interactionType,
      reviewState: fragment.reviewState,
      triggerRegion: fragment.triggerRegion,
      audio: fragment.audio,
      title: '讲述 ${fragment.id}',
      state: heard ? 'collected' : 'triggered',
    );
