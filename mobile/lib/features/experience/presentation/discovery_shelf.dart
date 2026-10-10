part of 'discovery_page.dart';

class _ShelfEntry {
  const _ShelfEntry(this.route, this.city);
  final RouteExperience route;
  final CityExperience city;
}

class _ShelfCatalog {
  const _ShelfCatalog(this.entries, this.failedCities);
  final List<_ShelfEntry> entries;
  final int failedCities;
}

final _shelfCatalogProvider = FutureProvider.autoDispose<_ShelfCatalog>((
  ref,
) async {
  final repository = ref.watch(experienceRepositoryProvider);
  final cities = await repository.cities();
  var failures = 0;
  final groups = await Future.wait(
    cities.map((city) async {
      try {
        final catalog = await repository.discoveryForCity(city.slug);
        return catalog.routes.map((route) => _ShelfEntry(route, city)).toList();
      } catch (_) {
        failures++;
        return <_ShelfEntry>[];
      }
    }),
  );
  return _ShelfCatalog(groups.expand((g) => g).toList(), failures);
});

class _DiscoveryShelf extends ConsumerStatefulWidget {
  const _DiscoveryShelf(
      {required this.favorites,
      required this.favoritesLoading,
      required this.favoritesError,
      required this.onRetryFavorites,
      required this.state,
      required this.visible,
      required this.busyFavorites,
      required this.onRemove,
      required this.onOpen,
      required this.onCity,
      required this.onBrowse});
  final List<TravelerFavorite> favorites;
  final bool favoritesLoading, favoritesError, visible;
  final VoidCallback onRetryFavorites, onCity, onBrowse;
  final DiscoveryState state;
  final Set<String> busyFavorites;
  final ValueChanged<String> onRemove;
  final ValueChanged<RouteExperience> onOpen;
  @override
  ConsumerState<_DiscoveryShelf> createState() => _DiscoveryShelfState();
}

class _DiscoveryShelfState extends ConsumerState<_DiscoveryShelf> {
  bool _notes = false;
  final _busy = <String>{};
  Future<void> _removeNote(CommunityPost post) async {
    if (!_busy.add(post.id)) return;
    setState(() {});
    final user = ref.read(currentUserIdProvider);
    try {
      await ref
          .read(experienceRepositoryProvider)
          .setCommunitySaved(post.id, false);
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      ref.invalidate(savedNotesProvider);
      ref.invalidate(notesFeedProvider);
      ref.invalidate(communityDetailControllerProvider(
          CommunityPostKey(user ?? 'demo', post.id)));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('已取消收藏'),
          action: SnackBarAction(
              label: '撤销',
              onPressed: () async {
                if (!mounted || user != ref.read(currentUserIdProvider)) return;
                try {
                  await ref
                      .read(experienceRepositoryProvider)
                      .setCommunitySaved(post.id, true);
                  ref.invalidate(savedNotesProvider);
                  ref.invalidate(notesFeedProvider);
                } catch (_) {
                  if (mounted) noteNotice(context, '收藏未能恢复，请重试');
                }
              })));
    } catch (_) {
      if (mounted) noteNotice(context, '收藏未能更新，请重试');
    } finally {
      if (mounted) setState(() => _busy.remove(post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.visible && widget.favorites.isNotEmpty
        ? ref.watch(_shelfCatalogProvider)
        : null;
    final saved = widget.visible
        ? ref.watch(savedNotesProvider)
        : const AsyncValue<CommunityPage<CommunityPost>>.loading();
    final entries = <String, _ShelfEntry>{
      for (final e in catalog?.value?.entries ?? <_ShelfEntry>[]) e.route.id: e,
      if (widget.state.city != null)
        for (final r in widget.state.catalog.routes)
          r.id: _ShelfEntry(r, widget.state.city!)
    };
    return SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                noteInset(context), 0, noteInset(context), 150),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  height: 72,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: NoteArrow('我的',
                          icon: DiscoveryMark.arrowLeft,
                          leadingIcon: true,
                          underline: false,
                          size: 13,
                          onTap: () => context.push('/profile')))),
              const SizedBox(height: 20),
              Text('KEPT FOR ANOTHER DAY', style: noteItalic(10)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: '我的收藏'),
                          TextSpan(
                              text: '。', style: noteSerif(34, color: noteRed))
                        ]),
                        style: noteSerif(34))),
                const DiscoveryIcon(DiscoveryMark.bookmark,
                    size: 26, color: noteRed)
              ]),
              const SizedBox(height: 22),
              Row(children: [
                for (final notes in [false, true])
                  Expanded(
                      child: NoteButton(
                          label: notes ? '收藏的见闻' : '收藏的地点',
                          selected: _notes == notes,
                          onTap: () => setState(() => _notes = notes),
                          child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: _notes == notes
                                              ? noteRed
                                              : noteLine))),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(notes ? '见闻' : '地点',
                                        style: noteSerif(18,
                                            color: _notes == notes
                                                ? noteRed
                                                : noteQuiet)),
                                    const SizedBox(width: 12),
                                    Text(
                                        '${notes ? saved.value?.total ?? saved.value?.items.length ?? 0 : widget.favorites.length}'
                                            .padLeft(2, '0'),
                                        style: noteItalic(12))
                                  ]))))
              ]),
              const SizedBox(height: 24),
              if (_notes)
                saved.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 1, color: noteRed)),
                    error: (_, __) => NoteFailure(
                        '收藏暂时无法读取', () => ref.invalidate(savedNotesProvider)),
                    data: (page) => Column(children: [
                          if (page.items.isEmpty) _empty(true),
                          for (final post in page.items)
                            Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(color: noteLine))),
                                child: Column(children: [
                                  NoteButton(
                                      label: '查看收藏见闻',
                                      onTap: () async {
                                        await context
                                            .push('/community/post/${post.id}');
                                        if (mounted) {
                                          ref.invalidate(savedNotesProvider);
                                        }
                                      },
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(
                                                      '${post.author.displayName} · ${noteTime(post.createdAt)}',
                                                      style: noteSans(10,
                                                          color: noteQuiet)),
                                                  const SizedBox(height: 8),
                                                  Text(post.title ?? post.body,
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: noteSerif(20))
                                                ])),
                                            if (post.media.isNotEmpty) ...[
                                              const SizedBox(width: 15),
                                              SizedBox(
                                                  width: 78,
                                                  height: 86,
                                                  child: NoteMediaImage(
                                                      post.media.first))
                                            ]
                                          ])),
                                  Row(children: [
                                    Expanded(child: NotePlaceRow(post)),
                                    IconButton(
                                        tooltip: '取消收藏这则见闻',
                                        onPressed: _busy.contains(post.id)
                                            ? null
                                            : () => _removeNote(post),
                                        icon: const DiscoveryIcon(
                                            DiscoveryMark.bookmark,
                                            filled: true,
                                            color: noteRed,
                                            size: 18))
                                  ]),
                                ])),
                          if (page.hasMore)
                            NoteArrow('更多收藏', onTap: () async {
                              try {
                                await ref
                                    .read(savedNotesProvider.notifier)
                                    .loadMore();
                              } catch (_) {
                                if (context.mounted) {
                                  noteNotice(context, '加载失败，请重试');
                                }
                              }
                            }),
                        ]))
              else ...[
                if (widget.favoritesLoading && widget.favorites.isEmpty)
                  const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 1, color: noteRed))
                else if (widget.favoritesError)
                  NoteFailure('收藏暂时无法读取', widget.onRetryFavorites)
                else if (widget.favorites.isEmpty)
                  _empty(false),
                if (catalog?.hasError == true ||
                    (catalog?.value?.failedCities ?? 0) > 0)
                  NoteFailure(
                      '部分地点暂未载入', () => ref.invalidate(_shelfCatalogProvider)),
                for (final favorite in widget.favorites)
                  _place(favorite, entries[favorite.targetId]),
              ],
            ])));
  }

  Widget _empty(bool notes) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: Column(children: [
        const DiscoveryIcon(DiscoveryMark.bookmark, size: 30, color: noteQuiet),
        const SizedBox(height: 20),
        Text(notes ? '留住值得再看的见闻。' : '下一次想去哪里？', style: noteSerif(23)),
        const SizedBox(height: 18),
        NoteArrow(notes ? '去看见闻' : '去发现',
            onTap:
                notes ? () => context.go('/?tab=community') : widget.onBrowse)
      ]));
  Widget _place(TravelerFavorite favorite, _ShelfEntry? entry) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (entry != null)
          NoteButton(
              label: '查看${entry.route.title}',
              onTap: () => widget.onOpen(entry.route),
              child: ClipRRect(
                  borderRadius:
                      const BorderRadius.only(topRight: Radius.circular(42)),
                  child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: DiscoveryPhoto(
                          source: entry.route.heroImage, saturation: .8)))),
        Row(children: [
          Expanded(
              child: Text(entry?.route.title ?? favorite.label,
                  style: noteSerif(25))),
          IconButton(
              tooltip: '取消收藏${favorite.label}',
              onPressed: widget.busyFavorites.contains(favorite.targetId)
                  ? null
                  : () => widget.onRemove(favorite.targetId),
              icon: const DiscoveryIcon(DiscoveryMark.bookmark,
                  filled: true, color: noteRed, size: 18))
        ]),
        if (entry != null) ...[
          Text('${entry.city.name} · ${entry.route.theme}',
              style: noteSans(11, color: noteQuiet)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text(
                    '${entry.route.durationMinutes} 分钟 · ${entry.route.distanceKm.toStringAsFixed(1)} km',
                    style: noteSans(11, color: noteQuiet))),
            NoteArrow('去随行',
                onTap: () => context.go(companionLocation(entry.route.slug)))
          ])
        ] else
          Text('内容暂不可用', style: noteSans(11, color: noteQuiet)),
      ]));
}
