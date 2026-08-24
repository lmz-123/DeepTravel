import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/demo_content.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/discovery_location.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  test('locality matching is generic and does not require city coordinates',
      () {
    const cities = [
      CityExperience(
        id: 'sz',
        slug: 'shenzhen',
        name: '深圳市',
        subtitle: '',
        heroImage: '',
      ),
      CityExperience(
        id: 'sh',
        slug: 'shanghai',
        name: '上海',
        subtitle: '',
        heroImage: '',
      ),
    ];

    expect(matchDiscoveryCity(' 上海市 ', cities)?.slug, 'shanghai');
    expect(
      matchDiscoveryCityCandidates(
        ['南山区', '深圳市', '广东省'],
        cities,
      )?.slug,
      'shenzhen',
    );
    expect(
      matchDiscoveryCityCandidates(['Shenzhen City'], cities)?.slug,
      'shenzhen',
    );
    expect(
      matchDiscoveryCityCandidates(['广东省深圳市南山区'], cities)?.slug,
      'shenzhen',
    );
    expect(matchDiscoveryCity('广州市', cities), isNull);
    expect(normalizeDiscoveryLocality('香港特别行政区'), '香港');
  });

  test('route centers identify a supported city without geocoder text', () {
    const shenzhen = CityExperience(
      id: 'sz',
      slug: 'shenzhen',
      name: '深圳',
      subtitle: '',
      heroImage: '',
    );
    const shanghai = CityExperience(
      id: 'sh',
      slug: 'shanghai',
      name: '上海',
      subtitle: '',
      heroImage: '',
    );
    const shenzhenRoute = RouteExperience(
      id: 'sz-route',
      slug: 'sz-route',
      title: '深圳景区',
      subtitle: '',
      description: '',
      durationMinutes: 1,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: [],
      centerLatitude: 22.54,
      centerLongitude: 114.06,
    );
    const shanghaiRoute = RouteExperience(
      id: 'sh-route',
      slug: 'sh-route',
      title: '上海景区',
      subtitle: '',
      description: '',
      durationMinutes: 1,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: [],
      centerLatitude: 31.23,
      centerLongitude: 121.47,
    );
    final sample = DiscoveryLocationSample(
      latitude: 22.541,
      longitude: 114.061,
      recordedAt: DateTime.now(),
    );

    final nearest = nearestDiscoveryCity(
      sample,
      const [
        (
          city: shanghai,
          catalog: CityDiscoveryCatalog(routes: [shanghaiRoute]),
        ),
        (
          city: shenzhen,
          catalog: CityDiscoveryCatalog(routes: [shenzhenRoute]),
        ),
      ],
      maximumDistanceMeters: 100000,
    );

    expect(nearest?.city.slug, 'shenzhen');
    expect(nearest?.distanceMeters, lessThan(1000));
  });

  test('unsupported coordinates do not fabricate a supported city', () {
    const city = CityExperience(
      id: 'sz',
      slug: 'shenzhen',
      name: '深圳',
      subtitle: '',
      heroImage: '',
    );
    const route = RouteExperience(
      id: 'sz-route',
      slug: 'sz-route',
      title: '深圳景区',
      subtitle: '',
      description: '',
      durationMinutes: 1,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: [],
      centerLatitude: 22.54,
      centerLongitude: 114.06,
    );
    final sample = DiscoveryLocationSample(
      latitude: 0,
      longitude: 0,
      recordedAt: DateTime.now(),
    );

    expect(
      nearestDiscoveryCity(
        sample,
        const [
          (city: city, catalog: CityDiscoveryCatalog(routes: [route])),
        ],
        maximumDistanceMeters: 100000,
      ),
      isNull,
    );
  });

  test('Haversine ranks scenic areas by center and keeps nodes contained', () {
    const farRoute = RouteExperience(
      id: 'far-route',
      slug: 'far-route',
      title: '较远景区',
      subtitle: '',
      description: '',
      durationMinutes: 1,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: [],
      centerLatitude: 22.501,
      centerLongitude: 114,
    );
    const nearRoute = RouteExperience(
      id: 'near-route',
      slug: 'near-route',
      title: '最近景区',
      subtitle: '',
      description: '',
      durationMinutes: 1,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: [],
      centerLatitude: 22.5,
      centerLongitude: 114,
    );
    const uncenteredRoute = RouteExperience(
      id: 'uncentered-route',
      slug: 'uncentered-route',
      title: '暂缺中心景区',
      subtitle: '',
      description: '',
      durationMinutes: 1,
      distanceKm: 1,
      difficulty: '',
      theme: '',
      heroImage: '',
      contentStatus: 'published',
      stops: [],
    );
    const catalog = CityDiscoveryCatalog(
      routes: [farRoute, uncenteredRoute, nearRoute],
    );

    final serverOrder = scenicAreaCards(catalog);
    expect(serverOrder.map((item) => item.route.id), [
      'far-route',
      'uncentered-route',
      'near-route',
    ]);
    expect(serverOrder.every((item) => item.distanceMeters == null), isTrue);

    final ranked = scenicAreaCards(
      catalog,
      sample: DiscoveryLocationSample(
        latitude: 22.5,
        longitude: 114,
        recordedAt: DateTime.now(),
      ),
    );
    expect(ranked.map((item) => item.route.id), [
      'near-route',
      'far-route',
      'uncentered-route',
    ]);
    expect(ranked.last.distanceMeters, isNull);
  });

  test('cold entry matches backend city without an accuracy gate', () async {
    final location = _LocationSource(
      samples: [_sample(locality: '上海市')],
    );
    final container = _container(location);
    addTearDown(container.dispose);

    await container.read(discoveryControllerProvider.future);
    final action = await container
        .read(discoveryControllerProvider.notifier)
        .prepareColdStart();
    final state = await container.read(discoveryControllerProvider.future);

    expect(action, DiscoveryStartupAction.completed);
    expect(state.city?.slug, 'shanghai');
    expect(state.cards.first.distanceMeters, isNotNull);
    expect(location.requests, [false]);
  });

  test('unmatched locality and empty matched city use supported route centers',
      () async {
    for (final locality in ['不存在的城市', '上海市']) {
      final location = _LocationSource(samples: [_sample(locality: locality)]);
      final container = _container(
        location,
        repository: _ShanghaiWithoutPointsRepository(),
      );
      await container.read(discoveryControllerProvider.future);
      await container
          .read(discoveryControllerProvider.notifier)
          .prepareColdStart();
      final state = await container.read(discoveryControllerProvider.future);

      expect(state.city?.slug, 'shenzhen');
      expect(state.cards.first.distanceMeters, isNotNull);
      expect(state.locationFailure, isNull);
      container.dispose();
    }
  });

  test('manual switch wins over locality and refresh keeps that city',
      () async {
    final location = _LocationSource(samples: [
      _sample(locality: '深圳'),
      _sample(locality: '深圳'),
    ]);
    final container = _container(location);
    addTearDown(container.dispose);

    await container.read(discoveryControllerProvider.future);
    final controller = container.read(discoveryControllerProvider.notifier);
    await controller.switchCity('shanghai');
    expect(
        (await container.read(discoveryControllerProvider.future)).city?.slug,
        'shanghai');

    await controller.refreshDiscovery();
    final state = await container.read(discoveryControllerProvider.future);
    expect(state.city?.slug, 'shanghai');
    expect(location.requests, [false, false]);
  });

  test('a late cold-entry result cannot overwrite a manual city switch',
      () async {
    final coldSample = Completer<DiscoveryLocationSample>();
    final location = _QueuedLocationSource([
      coldSample.future,
      Future.value(_sample(locality: '深圳')),
    ]);
    final container = ProviderContainer(
      overrides: [
        experienceRepositoryProvider.overrideWithValue(
          DemoExperienceRepository(latency: Duration.zero),
        ),
        currentLocationSourceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);
    await container.read(discoveryControllerProvider.future);
    final controller = container.read(discoveryControllerProvider.notifier);

    final coldEntry = controller.prepareColdStart();
    await location.firstRequest.future;
    await controller.switchCity('shanghai');
    coldSample.complete(_sample(locality: '深圳'));
    await coldEntry;

    final state = await container.read(discoveryControllerProvider.future);
    expect(state.city?.slug, 'shanghai');
    expect(location.requests, [false, false]);
  });

  test('stale samples restore server order and no fake distance', () async {
    final location = _LocationSource(samples: [
      _sample(
        locality: '深圳',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ]);
    final container = _container(location);
    await container.read(discoveryControllerProvider.future);
    await container
        .read(discoveryControllerProvider.notifier)
        .prepareColdStart();
    final state = await container.read(discoveryControllerProvider.future);
    expect(state.locationFailure, DiscoveryLocationFailureReason.unavailable);
    expect(state.cards.every((item) => item.distanceMeters == null), isTrue);
    container.dispose();
  });

  test('permission and acquisition failures keep discovery usable', () async {
    for (final entry
        in <(DiscoveryPermissionState, DiscoveryLocationFailureReason?)>[
      (
        DiscoveryPermissionState.deniedForever,
        DiscoveryLocationFailureReason.deniedForever,
      ),
      (
        DiscoveryPermissionState.serviceDisabled,
        DiscoveryLocationFailureReason.serviceDisabled,
      ),
    ]) {
      final location = _LocationSource(permission: entry.$1);
      final container = _container(location);
      await container.read(discoveryControllerProvider.future);
      await container
          .read(discoveryControllerProvider.notifier)
          .prepareColdStart();
      final state = await container.read(discoveryControllerProvider.future);
      expect(state.city?.slug, 'shenzhen');
      expect(state.cards, isNotEmpty);
      expect(state.locationFailure, entry.$2);
      expect(location.requests, isEmpty);
      container.dispose();
    }

    final timeout = _LocationSource(
      failure: DiscoveryLocationFailureReason.timeout,
    );
    final container = _container(timeout);
    await container.read(discoveryControllerProvider.future);
    await container
        .read(discoveryControllerProvider.notifier)
        .prepareColdStart();
    final state = await container.read(discoveryControllerProvider.future);
    expect(state.cards, isNotEmpty);
    expect(state.locationFailure, DiscoveryLocationFailureReason.timeout);
    container.dispose();
  });

  test('purpose explanation precedes the first permission request', () async {
    final location = _LocationSource(
      permission: DiscoveryPermissionState.requestable,
      samples: [_sample(locality: '深圳')],
    );
    final container = _container(location);
    addTearDown(container.dispose);
    await container.read(discoveryControllerProvider.future);
    final controller = container.read(discoveryControllerProvider.notifier);

    expect(await controller.prepareColdStart(),
        DiscoveryStartupAction.needsPurposeExplanation);
    expect(location.requests, isEmpty);

    await controller.continueColdStart();
    expect(location.requests, [true]);
  });
}

ProviderContainer _container(
  _LocationSource location, {
  DemoExperienceRepository? repository,
}) =>
    ProviderContainer(
      overrides: [
        experienceRepositoryProvider.overrideWithValue(
          repository ?? DemoExperienceRepository(latency: Duration.zero),
        ),
        currentLocationSourceProvider.overrideWithValue(location),
      ],
    );

class _ShanghaiWithoutPointsRepository extends DemoExperienceRepository {
  _ShanghaiWithoutPointsRepository() : super(latency: Duration.zero);

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async =>
      citySlug == 'shanghai'
          ? const CityDiscoveryCatalog(routes: [])
          : super.discoveryForCity(citySlug);
}

DiscoveryLocationSample _sample({
  String? locality,
  List<String> localityCandidates = const [],
  DateTime? recordedAt,
}) =>
    DiscoveryLocationSample(
      latitude: demoRoute.stops.first.latitude,
      longitude: demoRoute.stops.first.longitude,
      recordedAt: recordedAt ?? DateTime.now(),
      locality: locality,
      localityCandidates: localityCandidates,
    );

class _LocationSource implements CurrentLocationSource {
  _LocationSource({
    this.permission = DiscoveryPermissionState.granted,
    this.samples = const [],
    this.failure,
  });

  final DiscoveryPermissionState permission;
  final List<DiscoveryLocationSample> samples;
  final DiscoveryLocationFailureReason? failure;
  final List<bool> requests = [];
  var _sampleIndex = 0;

  @override
  Future<DiscoveryPermissionState> permissionState() async => permission;

  @override
  Future<DiscoveryLocationSample> currentPosition({
    required bool requestPermission,
  }) async {
    requests.add(requestPermission);
    if (failure != null) throw DiscoveryLocationFailure(failure!);
    final sample = samples[_sampleIndex.clamp(0, samples.length - 1)];
    _sampleIndex += 1;
    return sample;
  }
}

class _QueuedLocationSource implements CurrentLocationSource {
  _QueuedLocationSource(this.samples);

  final List<Future<DiscoveryLocationSample>> samples;
  final List<bool> requests = [];
  final firstRequest = Completer<void>();
  var _index = 0;

  @override
  Future<DiscoveryPermissionState> permissionState() async =>
      DiscoveryPermissionState.granted;

  @override
  Future<DiscoveryLocationSample> currentPosition({
    required bool requestPermission,
  }) {
    requests.add(requestPermission);
    if (!firstRequest.isCompleted) firstRequest.complete();
    return samples[_index++];
  }
}
