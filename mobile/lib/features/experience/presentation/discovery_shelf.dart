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

class _DiscoveryShelf extends ConsumerWidget {
  const _DiscoveryShelf({
    required this.favorites,
    required this.favoritesLoading,
    required this.favoritesError,
    required this.onRetryFavorites,
    required this.state,
    required this.visible,
    required this.busyFavorites,
    required this.onRemove,
    required this.onOpen,
    required this.onCity,
    required this.onBrowse,
  });
  final List<TravelerFavorite> favorites;
  final bool favoritesLoading, favoritesError;
  final VoidCallback onRetryFavorites;
  final DiscoveryState state;
  final bool visible;
  final Set<String> busyFavorites;
  final ValueChanged<String> onRemove;
  final ValueChanged<RouteExperience> onOpen;
  final VoidCallback onCity, onBrowse;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Avoid requesting every city's catalogue before the bookshelf is opened.
    final catalog = visible && favorites.isNotEmpty
        ? ref.watch(_shelfCatalogProvider)
        : null;
    final entries = <String, _ShelfEntry>{
      for (final entry in catalog?.value?.entries ?? <_ShelfEntry>[])
        entry.route.id: entry,
      if (state.city != null)
        for (final route in state.catalog.routes)
          route.id: _ShelfEntry(route, state.city!),
    };
    final narrow = MediaQuery.sizeOf(context).width <= 360;
    final pad = narrow ? 20.0 : 23.0;
    final hasFailure =
        catalog?.hasError == true || (catalog?.value?.failedCities ?? 0) > 0;
    return CustomScrollView(
      key: const PageStorageKey('shelf-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: _DiscoveryHeader(
            city: state.city?.name ?? '选择城市',
            onCity: onCity,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '把想去的，留给以后',
                  style: discoverySans(
                    10,
                    spacing: .4,
                    color: const Color(0xff8a7762),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '私人'),
                            TextSpan(
                              text: '书架',
                              style: TextStyle(color: AppColors.terracotta),
                            ),
                          ],
                        ),
                        style: discoverySerif(
                          narrow ? 48 : 54,
                          spacing: narrow ? -3.84 : -4.32,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 15),
                        child: Text(
                          favorites.length.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 17,
                            color: Color(0xff8a9271),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '无需打卡，也值得留下一页。',
                  style: discoverySans(12, color: const Color(0xff8f7d67)),
                ),
                if (hasFailure)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '部分书页暂未载入，收藏仍为你保留。',
                            style: discoverySans(12),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(_shelfCatalogProvider),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (favoritesLoading && favorites.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.terracotta,
                ),
              ),
            ),
          )
        else if (favoritesError && favorites.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Text('书架暂时没有翻开。', style: discoverySerif(25)),
                  const SizedBox(height: 12),
                  Text('你的收藏仍然保留，稍后再试一次。', style: discoverySans(13)),
                  const SizedBox(height: 24),
                  DiscoveryPaperButton(
                    label: '重新加载书架',
                    onTap: onRetryFavorites,
                  ),
                ],
              ),
            ),
          )
        else if (favorites.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 30, pad, 150),
            sliver: SliverToBoxAdapter(child: _empty()),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 35, pad, 182),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 21,
                mainAxisSpacing: 7,
                mainAxisExtent: narrow ? 269 : 284,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final favorite = favorites[index],
                    entry = entries[favorite.targetId];
                final loading = entry == null && catalog?.isLoading == true;
                return Padding(
                  padding: EdgeInsets.only(
                    top: index % 3 == 1 ? 24 : 0,
                    bottom: index % 3 == 1 ? 0 : 24,
                  ),
                  child: _ShelfBook(
                    entry: entry,
                    favorite: favorite,
                    narrow: narrow,
                    loading: loading,
                    busy: busyFavorites.contains(favorite.targetId),
                    onOpen: entry == null ? null : () => onOpen(entry.route),
                    onRemove: () => onRemove(favorite.targetId),
                  ),
                );
              }, childCount: favorites.length),
            ),
          ),
      ],
    );
  }

  Widget _empty() => Column(
    children: [
      SizedBox(
        width: 170,
        height: 166,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -.157,
              child: Text(
                '留',
                style: discoverySerif(
                  121,
                  color: const Color(0xffcfd599),
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const Positioned(
              left: 20,
              top: 48,
              child: SizedBox(
                width: 123,
                height: 73,
                child: DiscoveryCircle(angle: -.436, child: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 17),
        child: Text(
          '你的下一页，\n还没有写下。',
          style: discoverySerif(27, height: 1.55),
          textAlign: TextAlign.center,
        ),
      ),
      Text(
        '在随刊或路线里轻点收藏，\n想去的地方就会出现在这里。',
        style: discoverySans(12, height: 2, color: const Color(0xff86765f)),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 26),
      SizedBox(
        width: 230,
        child: DiscoveryPaperButton(label: '去翻一翻', onTap: onBrowse),
      ),
    ],
  );
}

class _ShelfBook extends StatelessWidget {
  const _ShelfBook({
    required this.entry,
    required this.favorite,
    required this.narrow,
    required this.loading,
    required this.busy,
    required this.onOpen,
    required this.onRemove,
  });
  final _ShelfEntry? entry;
  final TravelerFavorite favorite;
  final bool narrow, loading, busy;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final route = entry?.route;
    final title = route?.title ?? favorite.label;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DiscoveryTouch(
          label: route == null
              ? '$title，${loading ? '正在载入' : '暂不可用'}'
              : '打开$title',
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: narrow ? 190 : 205,
                decoration: BoxDecoration(
                  color: const Color(0xffc4cd9b),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(2),
                    right: Radius.circular(7),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0xffdbd6c9), offset: Offset(-4, 5)),
                    BoxShadow(
                      color: Color(0x144f4639),
                      offset: Offset(0, 9),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(2),
                    right: Radius.circular(7),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (route != null)
                        DiscoveryPhoto(
                          source: route.heroImage,
                          saturation: .75,
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [.25, 1],
                            colors: [Colors.transparent, Color(0xb0122218)],
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 5,
                          child: ColoredBox(color: Color(0x66ffffff)),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 15,
                        child: Text(
                          entry?.city.name ?? (loading ? '正在载入' : '收藏仍在'),
                          style: discoverySans(
                            9,
                            color: const Color(0xfffffbe9),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 15,
                        right: 10,
                        bottom: 22,
                        child: Text(
                          title.replaceAll(RegExp(r'\s*·\s*'), '\n'),
                          style: discoverySerif(
                            narrow ? 20 : 22,
                            color: const Color(0xfffff7e8),
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 11, right: 36),
                child: Text(
                  route == null
                      ? loading
                            ? '正在寻找这一页…'
                            : '内容暂不可用'
                      : '${route.durationMinutes} 分钟 · ${route.isPublished ? _routeFormat(route) : '筹备中'}',
                  style: discoverySans(
                    10,
                    height: 1.8,
                    color: const Color(0xff85755f),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: -10,
          bottom: 0,
          child: _DiscoveryIconButton(
            mark: DiscoveryMark.bookmark,
            label: '取消收藏$title',
            onTap: busy ? null : onRemove,
            size: 17,
            filled: true,
            color: AppColors.terracotta,
          ),
        ),
      ],
    );
  }
}
