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

class NotesFeed extends AsyncNotifier<CommunityPage<CommunityPost>> {
  int _generation = 0;
  bool _loadingMore = false;
  @override
  Future<CommunityPage<CommunityPost>> build() {
    _generation++;
    _loadingMore = false;
    ref.watch(currentUserIdProvider);
    final city = ref.watch(notesCityProvider);
    return ref
        .watch(experienceRepositoryProvider)
        .discoverCommunity(citySlug: city);
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
              cursor: current.nextCursor);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(CommunityPage(
          items: {
            for (final post in state.requireValue.items) post.id: post,
            for (final post in page.items) post.id: post,
          }.values.toList(),
          nextCursor: page.nextCursor));
    } finally {
      if (ref.mounted && generation == _generation) _loadingMore = false;
    }
  }

  void replace(CommunityPost post) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(CommunityPage(
        items: current.items.map((p) => p.id == post.id ? post : p).toList(),
        nextCursor: current.nextCursor));
  }
}

final notesFeedProvider =
    AsyncNotifierProvider<NotesFeed, CommunityPage<CommunityPost>>(
        NotesFeed.new);
