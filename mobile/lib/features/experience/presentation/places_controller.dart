import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_experience_repository.dart';
import '../data/place_repository.dart';
import 'experience_providers.dart';

final placeRepositoryProvider = Provider<PlaceRepository?>((ref) =>
    ref.watch(experienceRepositoryProvider) is ApiExperienceRepository
        ? ApiPlaceRepository(ref.watch(dioProvider))
        : null);

/// Cursor loading follows NotesFeed: one request at a time, deduplicate IDs,
/// and discard replies belonging to a previous filter or city.
class PlacesController extends ChangeNotifier {
  PlacesController(this.repository);
  final PlaceRepository repository;
  PlaceQuery? query;
  PlacePage? page, map;
  bool loading = false, loadingMore = false, loadingMap = false;
  bool failed = false, moreFailed = false, mapFailed = false;
  int _generation = 0;
  bool _disposed = false;
  int get generation => _generation;
  bool _current(int generation) => !_disposed && generation == _generation;
  Future<void> reload(PlaceQuery next, {bool withMap = false}) async {
    query = next;
    final generation = ++_generation;
    page = map = null;
    loading = true;
    failed = moreFailed = mapFailed = loadingMore = loadingMap = false;
    notifyListeners();
    if (withMap) loadMap();
    try {
      final value = await repository.page(next);
      if (_current(generation)) page = value;
    } catch (_) {
      if (_current(generation)) failed = true;
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final current = page, next = query;
    if (loading || loadingMore || current?.nextCursor == null || next == null) {
      return;
    }
    final generation = _generation;
    loadingMore = true;
    moreFailed = false;
    notifyListeners();
    try {
      final value = await repository.page(next, cursor: current!.nextCursor);
      if (_current(generation)) {
        page = PlacePage(
            items: {
              for (final route in page!.items) route.id: route,
              for (final route in value.items) route.id: route,
            }.values.toList(),
            total: value.total,
            nextCursor: value.nextCursor,
            categories: value.categories,
            districts: value.districts);
      }
    } catch (_) {
      if (_current(generation)) moreFailed = true;
    } finally {
      if (_current(generation)) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMap() async {
    if (loadingMap || map != null || query == null) return;
    final generation = _generation;
    loadingMap = true;
    mapFailed = false;
    notifyListeners();
    try {
      final value = await repository.markers(query!);
      if (_current(generation)) map = value;
    } catch (_) {
      if (_current(generation)) mapFailed = true;
    } finally {
      if (_current(generation)) {
        loadingMap = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
