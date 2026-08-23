import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_discovery_location.dart';
import '../domain/discovery_location.dart';
import '../domain/city_story.dart';
import '../domain/experience_repository.dart';
import '../domain/models.dart';
import 'experience_providers.dart';

enum DiscoveryStartupAction { completed, needsPurposeExplanation }

class DiscoveryState {
  const DiscoveryState({
    required this.cities,
    required this.city,
    required this.catalog,
    required this.cards,
    this.storyHome = CityStoryHome.empty,
    required this.revision,
    this.isLocating = false,
    this.locationFailure,
  });

  final List<CityExperience> cities;
  final CityExperience? city;
  final CityDiscoveryCatalog catalog;
  final List<ScenicAreaCard> cards;
  final CityStoryHome storyHome;
  final int revision;
  final bool isLocating;
  final DiscoveryLocationFailureReason? locationFailure;

  DiscoveryState copyWith({
    List<CityExperience>? cities,
    CityExperience? city,
    CityDiscoveryCatalog? catalog,
    List<ScenicAreaCard>? cards,
    CityStoryHome? storyHome,
    int? revision,
    bool? isLocating,
    DiscoveryLocationFailureReason? locationFailure,
    bool clearLocationFailure = false,
    bool clearCity = false,
  }) =>
      DiscoveryState(
        cities: cities ?? this.cities,
        city: clearCity ? null : city ?? this.city,
        catalog: catalog ?? this.catalog,
        cards: cards ?? this.cards,
        storyHome: storyHome ?? this.storyHome,
        revision: revision ?? this.revision,
        isLocating: isLocating ?? this.isLocating,
        locationFailure: clearLocationFailure
            ? null
            : locationFailure ?? this.locationFailure,
      );
}

final currentLocationSourceProvider = Provider<CurrentLocationSource>(
  (ref) => PlatformCurrentLocationSource(),
);

final discoveryControllerProvider =
    AsyncNotifierProvider<DiscoveryController, DiscoveryState>(
  DiscoveryController.new,
);

class DiscoveryController extends AsyncNotifier<DiscoveryState> {
  static const maximumSampleAge = Duration(minutes: 2);

  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);
  CurrentLocationSource get _location =>
      ref.read(currentLocationSourceProvider);
  var _eventToken = 0;

  @override
  Future<DiscoveryState> build() async {
    final cities = await _repository.cities();
    final city = fallbackDiscoveryCity(cities);
    final catalog = city == null
        ? const CityDiscoveryCatalog(routes: [])
        : await _repository.discoveryForCity(city.slug);
    final storyHome =
        city == null ? CityStoryHome.empty : await _loadStoryHome(city.slug);
    return DiscoveryState(
      cities: cities,
      city: city,
      catalog: catalog,
      cards: scenicAreaCards(catalog),
      storyHome: storyHome,
      revision: 0,
    );
  }

  Future<DiscoveryStartupAction> prepareColdStart() async {
    final token = _beginEvent();
    await future;
    if (!_isCurrent(token)) return DiscoveryStartupAction.completed;
    final permission = await _location.permissionState();
    if (!_isCurrent(token)) return DiscoveryStartupAction.completed;
    switch (permission) {
      case DiscoveryPermissionState.granted:
        await _locateInitial(token, requestPermission: false);
        return DiscoveryStartupAction.completed;
      case DiscoveryPermissionState.requestable:
        return DiscoveryStartupAction.needsPurposeExplanation;
      case DiscoveryPermissionState.deniedForever:
        _setFailure(DiscoveryLocationFailureReason.deniedForever);
        return DiscoveryStartupAction.completed;
      case DiscoveryPermissionState.serviceDisabled:
        _setFailure(DiscoveryLocationFailureReason.serviceDisabled);
        return DiscoveryStartupAction.completed;
    }
  }

  Future<void> continueColdStart() =>
      _locateInitial(_beginEvent(), requestPermission: true);

  void declineColdStart() {
    _beginEvent();
    _setFailure(DiscoveryLocationFailureReason.denied);
  }

  Future<void> refreshDiscovery() async {
    final token = _beginEvent();
    final current = state.asData?.value ?? await future;
    final cities = await _repository.cities();
    if (!_isCurrent(token)) return;
    final active = cities.where((city) => city.slug == current.city?.slug);
    final city =
        active.isNotEmpty ? active.first : fallbackDiscoveryCity(cities);
    final catalog = city == null
        ? const CityDiscoveryCatalog(routes: [])
        : await _repository.discoveryForCity(city.slug);
    final storyHome =
        city == null ? CityStoryHome.empty : await _loadStoryHome(city.slug);
    if (!_isCurrent(token)) return;
    final base = current.copyWith(
      cities: cities,
      city: city,
      clearCity: city == null,
      catalog: catalog,
      cards: scenicAreaCards(catalog),
      storyHome: storyHome,
      revision: current.revision + 1,
      isLocating: true,
      clearLocationFailure: true,
    );
    state = AsyncData(base);
    await _locateForActive(token, base, requestPermission: false);
  }

  Future<void> switchCity(String citySlug) async {
    final token = _beginEvent();
    final current = state.asData?.value ?? await future;
    final city = current.cities
        .where((candidate) => candidate.slug == citySlug)
        .firstOrNull;
    if (city == null) return;
    final catalog = await _repository.discoveryForCity(city.slug);
    final storyHome = await _loadStoryHome(city.slug);
    if (!_isCurrent(token)) return;
    final base = current.copyWith(
      city: city,
      catalog: catalog,
      cards: scenicAreaCards(catalog),
      storyHome: storyHome,
      revision: current.revision + 1,
      isLocating: true,
      clearLocationFailure: true,
    );
    state = AsyncData(base);
    await _locateForActive(token, base, requestPermission: false);
  }

  Future<void> _locateInitial(
    int token, {
    required bool requestPermission,
  }) async {
    final current = state.asData?.value ?? await future;
    if (!_isCurrent(token)) return;
    state = AsyncData(current.copyWith(
      isLocating: true,
      clearLocationFailure: true,
    ));
    try {
      final sample = await _currentSample(requestPermission);
      if (!_isCurrent(token)) return;
      final matched = matchDiscoveryCity(sample.locality, current.cities);
      if (matched == null) {
        await _restoreFallback(token, current);
        return;
      }
      final catalog = matched.slug == current.city?.slug
          ? current.catalog
          : await _repository.discoveryForCity(matched.slug);
      final storyHome = matched.slug == current.city?.slug
          ? current.storyHome
          : await _loadStoryHome(matched.slug);
      if (!_isCurrent(token)) return;
      if (catalog.routes.isEmpty) {
        await _restoreFallback(token, current);
        return;
      }
      state = AsyncData(current.copyWith(
        city: matched,
        catalog: catalog,
        cards: scenicAreaCards(catalog, sample: sample),
        storyHome: storyHome,
        revision: current.revision + 1,
        isLocating: false,
        clearLocationFailure: true,
      ));
    } on DiscoveryLocationFailure catch (failure) {
      if (_isCurrent(token)) _setFailure(failure.reason);
    }
  }

  Future<void> _restoreFallback(int token, DiscoveryState current) async {
    final fallback = fallbackDiscoveryCity(current.cities);
    final catalog = fallback == null
        ? const CityDiscoveryCatalog(routes: [])
        : fallback.slug == current.city?.slug
            ? current.catalog
            : await _repository.discoveryForCity(fallback.slug);
    final storyHome = fallback == null
        ? CityStoryHome.empty
        : fallback.slug == current.city?.slug
            ? current.storyHome
            : await _loadStoryHome(fallback.slug);
    if (!_isCurrent(token)) return;
    state = AsyncData(current.copyWith(
      city: fallback,
      catalog: catalog,
      cards: scenicAreaCards(catalog),
      storyHome: storyHome,
      revision: current.revision + 1,
      isLocating: false,
      locationFailure: DiscoveryLocationFailureReason.unavailable,
    ));
  }

  Future<void> _locateForActive(
    int token,
    DiscoveryState base, {
    required bool requestPermission,
  }) async {
    try {
      final sample = await _currentSample(requestPermission);
      if (!_isCurrent(token)) return;
      state = AsyncData(base.copyWith(
        cards: scenicAreaCards(base.catalog, sample: sample),
        isLocating: false,
        clearLocationFailure: true,
      ));
    } on DiscoveryLocationFailure catch (failure) {
      if (!_isCurrent(token)) return;
      state = AsyncData(base.copyWith(
        cards: scenicAreaCards(base.catalog),
        isLocating: false,
        locationFailure: failure.reason,
      ));
    }
  }

  Future<DiscoveryLocationSample> _currentSample(
    bool requestPermission,
  ) async {
    final sample = await _location.currentPosition(
      requestPermission: requestPermission,
    );
    final age = DateTime.now().toUtc().difference(
          sample.recordedAt.toUtc(),
        );
    if (age > maximumSampleAge || age < -const Duration(seconds: 5)) {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.unavailable,
      );
    }
    return sample;
  }

  Future<CityStoryHome> _loadStoryHome(String citySlug) async {
    try {
      return await _repository.cityStoryHome(citySlug);
    } catch (_) {
      return CityStoryHome.empty;
    }
  }

  void _setFailure(DiscoveryLocationFailureReason reason) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      cards: scenicAreaCards(current.catalog),
      isLocating: false,
      locationFailure: reason,
      revision: current.revision + 1,
    ));
  }

  int _beginEvent() => ++_eventToken;

  bool _isCurrent(int token) => token == _eventToken;
}

CityExperience? fallbackDiscoveryCity(List<CityExperience> cities) {
  if (cities.isEmpty) return null;
  for (final city in cities) {
    if (city.slug == 'shenzhen') return city;
  }
  return cities.first;
}

CityExperience? matchDiscoveryCity(
  String? locality,
  List<CityExperience> cities,
) {
  final normalized = normalizeDiscoveryLocality(locality ?? '');
  if (normalized.isEmpty) return null;
  for (final city in cities) {
    if (normalizeDiscoveryLocality(city.name) == normalized) return city;
  }
  return null;
}

String normalizeDiscoveryLocality(String value) {
  var normalized = value.trim().toLowerCase().replaceAll(RegExp(r'[\s·・]'), '');
  for (final suffix in const [
    '特别行政区',
    '自治州',
    '地区',
    '市',
    '盟',
  ]) {
    if (normalized.endsWith(suffix)) {
      normalized = normalized.substring(0, normalized.length - suffix.length);
      break;
    }
  }
  return normalized;
}

List<ScenicAreaCard> scenicAreaCards(
  CityDiscoveryCatalog catalog, {
  DiscoveryLocationSample? sample,
}) {
  final indexed = <({int index, ScenicAreaCard card})>[];
  for (var index = 0; index < catalog.routes.length; index++) {
    final route = catalog.routes[index];
    final latitude = route.centerLatitude;
    final longitude = route.centerLongitude;
    indexed.add((
      index: index,
      card: ScenicAreaCard(
        route: route,
        distanceMeters: sample == null || latitude == null || longitude == null
            ? null
            : discoveryDistanceMeters(
                sample.latitude,
                sample.longitude,
                latitude,
                longitude,
              ),
      ),
    ));
  }
  if (sample != null) {
    indexed.sort((left, right) {
      final leftDistance = left.card.distanceMeters;
      final rightDistance = right.card.distanceMeters;
      if (leftDistance == null && rightDistance != null) return 1;
      if (leftDistance != null && rightDistance == null) return -1;
      final distance =
          leftDistance == null ? 0 : leftDistance.compareTo(rightDistance!);
      if (distance != 0) return distance;
      final serverOrder = left.index.compareTo(right.index);
      if (serverOrder != 0) return serverOrder;
      return left.card.route.id.compareTo(right.card.route.id);
    });
  }
  return indexed.map((item) => item.card).toList(growable: false);
}

double discoveryDistanceMeters(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusMeters = 6371000.0;
  final latA = latitudeA * math.pi / 180;
  final latB = latitudeB * math.pi / 180;
  final deltaLat = (latitudeB - latitudeA) * math.pi / 180;
  final deltaLon = (longitudeB - longitudeA) * math.pi / 180;
  final value = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(latA) *
          math.cos(latB) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  return 2 * earthRadiusMeters * math.asin(math.sqrt(value));
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
