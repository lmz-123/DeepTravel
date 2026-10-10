import 'dart:math' as math;
import '../discovery_controller.dart';
import '../../domain/discovery_location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/community_models.dart';
import '../experience_providers.dart';

final notesNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class NotesCity extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(currentUserIdProvider);
    return null;
  }

  void select(String? city) => state = city;
}

final notesCityProvider = NotifierProvider<NotesCity, String?>(NotesCity.new);
final notesPlacesProvider = FutureProvider<List<CommunityPlace>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(experienceRepositoryProvider).communityPlaces();
});
final notesPolicyProvider = FutureProvider<CommunityPolicy>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(experienceRepositoryProvider).communityPolicy();
});

class NotesFilters extends Notifier<CommunityQuery> {
  @override
  CommunityQuery build() {
    ref.watch(currentUserIdProvider);
    return const CommunityQuery();
  }

  void select(CommunityQuery value) => state = value;
}

final notesFiltersProvider =
    NotifierProvider<NotesFilters, CommunityQuery>(NotesFilters.new);

class NotesLocation extends AsyncNotifier<DiscoveryLocationSample?> {
  @override
  Future<DiscoveryLocationSample?> build() async {
    ref.watch(currentUserIdProvider);
    final source = ref.read(currentLocationSourceProvider);
    if (await source.permissionState() != DiscoveryPermissionState.granted) {
      return null;
    }
    try {
      return await source.currentPosition(requestPermission: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> locate() async {
    final user = ref.read(currentUserIdProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(currentLocationSourceProvider)
        .currentPosition(requestPermission: true));
    if (ref.mounted && user == ref.read(currentUserIdProvider)) state = result;
  }
}

final notesLocationProvider =
    AsyncNotifierProvider<NotesLocation, DiscoveryLocationSample?>(
        NotesLocation.new);

double? noteDistance(CommunityPlace? place, DiscoveryLocationSample? location) {
  if (place?.latitude == null || place?.longitude == null || location == null) {
    return null;
  }
  final lat1 = location.latitude * math.pi / 180,
      lat2 = place!.latitude! * math.pi / 180;
  final dlat = lat2 - lat1,
      dlon = (place.longitude! - location.longitude) * math.pi / 180;
  final a = math.pow(math.sin(dlat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
  return 6371008.8 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}

String noteDistanceLabel(double? meters) => meters == null
    ? '距离未知'
    : meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
CommunityQuery locatedQuery(
        CommunityQuery filters, DiscoveryLocationSample? location) =>
    CommunityQuery(
        category: filters.category,
        radiusKm: filters.radiusKm,
        order: filters.order,
        savedOnly: filters.savedOnly,
        latitude: location?.latitude,
        longitude: location?.longitude);

class NotesFeed extends AsyncNotifier<CommunityPage<CommunityPost>> {
  int _generation = 0;
  bool _loadingMore = false;
  @override
  Future<CommunityPage<CommunityPost>> build() {
    _generation++;
    _loadingMore = false;
    ref.watch(currentUserIdProvider);
    final city = ref.watch(notesCityProvider);
    final filters = ref.watch(notesFiltersProvider);
    final location =
        ref.watch(notesLocationProvider.select((value) => value.value));
    return ref.watch(experienceRepositoryProvider).discoverCommunity(
        citySlug: city, query: locatedQuery(filters, location));
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    final generation = _generation;
    try {
      final page = await ref
          .read(experienceRepositoryProvider)
          .discoverCommunity(
              citySlug: ref.read(notesCityProvider),
              cursor: current.nextCursor,
              query: locatedQuery(ref.read(notesFiltersProvider),
                  ref.read(notesLocationProvider).value));
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(CommunityPage(
          items: {
            for (final post in state.requireValue.items) post.id: post,
            for (final post in page.items) post.id: post,
          }.values.toList(),
          nextCursor: page.nextCursor,
          total: page.total));
    } finally {
      if (ref.mounted && generation == _generation) _loadingMore = false;
    }
  }

  void replace(CommunityPost post) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(CommunityPage(
        items: current.items.map((p) => p.id == post.id ? post : p).toList(),
        nextCursor: current.nextCursor,
        total: current.total));
  }
}

final notesFeedProvider =
    AsyncNotifierProvider<NotesFeed, CommunityPage<CommunityPost>>(
        NotesFeed.new);

class SavedNotes extends AsyncNotifier<CommunityPage<CommunityPost>> {
  bool _loading = false;
  @override
  Future<CommunityPage<CommunityPost>> build() {
    ref.watch(currentUserIdProvider);
    return ref
        .watch(experienceRepositoryProvider)
        .discoverCommunity(query: const CommunityQuery(savedOnly: true));
  }

  Future<void> loadMore() async {
    final page = state.value;
    if (_loading || page == null || !page.hasMore) return;
    _loading = true;
    final user = ref.read(currentUserIdProvider);
    try {
      final more = await ref
          .read(experienceRepositoryProvider)
          .discoverCommunity(
              query: const CommunityQuery(savedOnly: true),
              cursor: page.nextCursor);
      if (ref.mounted &&
          user == ref.read(currentUserIdProvider) &&
          identical(state.value, page)) {
        state = AsyncData(CommunityPage(
            items: {
              ...{for (final p in page.items) p.id: p},
              ...{for (final p in more.items) p.id: p}
            }.values.toList(),
            nextCursor: more.nextCursor,
            total: more.total));
      }
    } finally {
      _loading = false;
    }
  }
}

final savedNotesProvider =
    AsyncNotifierProvider<SavedNotes, CommunityPage<CommunityPost>>(
        SavedNotes.new);
