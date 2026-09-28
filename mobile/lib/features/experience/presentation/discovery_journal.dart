part of 'discovery_page.dart';

class _DiscoveryJournal extends StatefulWidget {
  const _DiscoveryJournal({
    required this.state,
    required this.saved,
    required this.busyFavorites,
    required this.onFavorite,
    required this.onOpen,
    required this.onCity,
    required this.onAtlas,
    required this.onRefresh,
    super.key,
  });
  final DiscoveryState state;
  final Set<String> saved, busyFavorites;
  final ValueChanged<RouteExperience> onFavorite, onOpen;
  final VoidCallback onCity, onAtlas;
  final Future<void> Function() onRefresh;
  @override
  State<_DiscoveryJournal> createState() => _DiscoveryJournalState();
}

class _DiscoveryJournalState extends State<_DiscoveryJournal> {
  int _edition = 0;
  double _drag = 0;
  void _change(int delta, int length) {
    if (length > 1) setState(() => _edition = (_edition + delta) % length);
  }

  @override
  Widget build(BuildContext context) {
    final routes = widget.state.cards.map((card) => card.route).toList();
    final featured = routes.where((route) => route.isFeatured).toList();
    final issues = featured.isEmpty ? routes : featured;
    final narrow = MediaQuery.sizeOf(context).width <= 360;
    final pad = narrow ? 20.0 : 23.0;
    final route = issues.isEmpty ? null : issues[_edition % issues.length];
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.terracotta,
      child: CustomScrollView(
        key: const PageStorageKey('journal-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _DiscoveryHeader(
              city: widget.state.city?.name ?? '选择城市',
              onCity: widget.onCity,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 155),
            sliver: SliverToBoxAdapter(
              child: route == null
                  ? _empty()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 48,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0x35252824)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '城市随刊',
                                style: discoverySans(
                                  10,
                                  color: const Color(0xff857766),
                                  spacing: .4,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('·', style: discoverySans(10)),
                              const SizedBox(width: 10),
                              Text(
                                '${_edition % issues.length + 1}'.padLeft(
                                  2,
                                  '0',
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 18,
                                  color: AppColors.terracotta,
                                ),
                              ),
                              Text(
                                ' / ${issues.length.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  color: Color(0xffa19784),
                                ),
                              ),
                              const Spacer(),
                              _DiscoveryIconButton(
                                mark: DiscoveryMark.arrowLeft,
                                label: '上一期随刊',
                                size: 16,
                                onTap: issues.length < 2
                                    ? null
                                    : () => _change(-1, issues.length),
                              ),
                              _DiscoveryIconButton(
                                mark: DiscoveryMark.arrowRight,
                                label: '下一期随刊',
                                size: 16,
                                onTap: issues.length < 2
                                    ? null
                                    : () => _change(1, issues.length),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onHorizontalDragStart: (_) => _drag = 0,
                          onHorizontalDragUpdate: (details) =>
                              _drag += details.delta.dx,
                          onHorizontalDragEnd: (_) {
                            if (_drag.abs() > 55) {
                              _change(_drag < 0 ? 1 : -1, issues.length);
                            }
                          },
                          child: _JournalCover(
                            route: route,
                            city: widget.state.city,
                            narrow: narrow,
                            onOpen: () => widget.onOpen(route),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(0, 14, 0, 13),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0x222d3026)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DiscoveryTouch(
                                  key: ValueKey('route-card-${route.slug}'),
                                  label: '查看${route.title}',
                                  onTap: () => widget.onOpen(route),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.state.city?.name ?? ''}  /  ${route.theme}',
                                        style: discoverySans(
                                          10,
                                          color: const Color(0xff897661),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              route.title,
                                              style: discoverySerif(
                                                narrow ? 24 : 26,
                                                weight: FontWeight.w600,
                                                height: 1.7,
                                                spacing: -1,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const DiscoveryIcon(
                                            DiscoveryMark.arrowUpRight,
                                            size: 19,
                                            color: AppColors.terracotta,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _routeMetadata(route),
                                        style: discoverySans(
                                          11,
                                          height: 1.8,
                                          color: const Color(0xff796f5e),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _DiscoveryIconButton(
                                mark: DiscoveryMark.bookmark,
                                label:
                                    '${widget.saved.contains(route.id) ? '取消收藏' : '收藏'}${route.title}',
                                onTap: widget.busyFavorites.contains(route.id)
                                    ? null
                                    : () => widget.onFavorite(route),
                                size: 23,
                                selected: widget.saved.contains(route.id),
                                filled: widget.saved.contains(route.id),
                                color: widget.saved.contains(route.id)
                                    ? AppColors.terracotta
                                    : const Color(0xff817761),
                              ),
                            ],
                          ),
                        ),
                        DiscoveryTouch(
                          label: '打开城市索引',
                          onTap: widget.onAtlas,
                          child: SizedBox(
                            height: 50,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '有目的地，也有自己的节奏。',
                                  style: discoverySans(
                                    narrow ? 8 : 9,
                                    color: const Color(0xffa08b75),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '打开城市索引',
                                      style: discoverySans(
                                        10,
                                        weight: FontWeight.w500,
                                        color: const Color(0xff6d6656),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const DiscoveryIcon(
                                      DiscoveryMark.arrowUpRight,
                                      size: 15,
                                      color: Color(0xff6d6656),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (widget.state.storyHome.modules
              .any((module) => module.items.isNotEmpty))
            SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 150),
                sliver: SliverToBoxAdapter(
                    child: _DiscoveryStoryIndex(home: widget.state.storyHome))),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下一本随刊，\n正在慢慢生长。', style: discoverySerif(37, spacing: -2)),
            const SizedBox(height: 20),
            Text('这座城市的路线还在准备中，先去另一座城看看。', style: discoverySans(13)),
            const SizedBox(height: 25),
            DiscoveryPaperButton(label: '选择另一座城市', onTap: widget.onCity),
          ],
        ),
      );
}

String _routeMetadata(RouteExperience route) => !route.isPublished
    ? '筹备中 · 可看构想'
    : '${route.durationMinutes} 分钟 · ${route.distanceKm.toStringAsFixed(1)} km · ${_routeFormat(route)}';
String _routeFormat(RouteExperience route) =>
    route.audioTour != null ? '声音导览' : '文字漫游';

class _JournalCover extends StatelessWidget {
  const _JournalCover({
    required this.route,
    required this.city,
    required this.narrow,
    required this.onOpen,
  });
  final RouteExperience route;
  final CityExperience? city;
  final bool narrow;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final copy = _JournalCopy.forRoute(route, city);
    final size = narrow ? 57.0 : 62.0;
    final pad = narrow ? 20.0 : 23.0;
    return SizedBox(
      height: narrow ? 440 : 463,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -38,
            bottom: narrow ? 3 : 0,
            child: ExcludeSemantics(
              child: Transform.rotate(
                angle: -.2094,
                child: Text(
                  copy.print,
                  style: discoverySerif(
                    narrow ? 180 : 193,
                    weight: FontWeight.w900,
                    height: 1,
                    color: copy.printColor,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: narrow ? 125 : 131,
            left: narrow ? 30 : 37,
            right: -pad,
            height: narrow ? 286 : 307,
            child: DiscoveryTouch(
              label: '打开${route.title}',
              onTap: onOpen,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  ClipPath(
                    clipper: JournalPhotoClipper(town: copy.town),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DiscoveryPhoto(
                          source: route.heroImage,
                          alignment: copy.town
                              ? const Alignment(-.2, .2)
                              : const Alignment(.12, .12),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x7a12221a)],
                              stops: [.64, 1],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 22,
                    bottom: 25,
                    right: 52,
                    child: Text(
                      copy.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: discoverySans(
                        11,
                        color: const Color(0xfffff8ed),
                        height: 1.7,
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0x77000000),
                            blurRadius: 5,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 17,
                    bottom: -19,
                    child: Transform.rotate(
                      angle: -.1222,
                      child: Container(
                        width: 63,
                        height: 63,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: copy.sealColor,
                          border: Border.all(color: AppColors.paper, width: 5),
                        ),
                        child: Center(
                          child: DiscoveryIcon(
                            DiscoveryMark.arrowUpRight,
                            size: 31,
                            color: copy.sealColor == AppColors.terracotta
                                ? Colors.white
                                : const Color(0xff3c4329),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 194,
            child: ExcludeSemantics(
              child: SizedBox(
                width: 15,
                child: Text(
                  copy.note.split('').join('\n'),
                  textAlign: TextAlign.center,
                  style: discoverySans(
                    narrow ? 9 : 10,
                    height: 1.6,
                    color: const Color(0xff8f7b65),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 0,
            right: -6,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.first,
                    style: discoverySerif(
                      size,
                      weight: FontWeight.w700,
                      height: 1.15,
                      spacing: -size * .065,
                      color: copy.color,
                    ),
                    maxLines: 1,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: narrow ? 42 : 53),
                    child: Container(
                      padding: const EdgeInsets.only(right: 12, bottom: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(23),
                        ),
                      ),
                      child: Text(
                        copy.second,
                        style: discoverySerif(
                          size,
                          weight: FontWeight.w700,
                          height: 1.15,
                          spacing: -size * .065,
                          color: copy.color,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalCopy {
  const _JournalCopy(
    this.first,
    this.second,
    this.note,
    this.caption,
    this.print, {
    this.color = AppColors.terracotta,
    this.printColor = const Color(0xffe5e8cc),
    this.sealColor = const Color(0xffdbe782),
    this.town = false,
  });
  final String first, second, note, caption, print;
  final Color color, printColor, sealColor;
  final bool town;
  // Editorial copy describes a real route. Media, route identity and inventory
  // always come from the API; this never creates an artificial destination.
  factory _JournalCopy.forRoute(RouteExperience route, CityExperience? city) {
    final subject = '${route.title}${route.theme}';
    if (RegExp('海|沙滩|海滨|海岸').hasMatch(subject)) {
      return const _JournalCopy(
        '不赶路，',
        '去听海。',
        '把一点时间，交给潮汐。',
        '一座城市，也有呼吸的另一面。',
        '海',
      );
    }
    if (RegExp('古城|老街|南头|古镇').hasMatch(subject)) {
      return const _JournalCopy(
        '旧街里，',
        '有新意。',
        '拐进日常，遇见一座城的来处。',
        '不是所有故事，都在博物馆里。',
        '街',
        town: true,
        color: Color(0xff3c4839),
        printColor: Color(0xffe8d9c8),
        sealColor: Color(0xffe7a286),
      );
    }
    if (RegExp('公园|山林|森林').hasMatch(subject)) {
      return const _JournalCopy(
        '树荫下，',
        '等故事。',
        '把日常，交给树影和微风。',
        '一座公园，一段共同的记忆。',
        '树',
        color: Color(0xff607046),
      );
    }
    return _JournalCopy(
      '走慢点，',
      city?.name == '上海' ? '听上海。' : '读一城。',
      route.subtitle.isEmpty ? '日常深处，故事正在发生。' : route.subtitle,
      route.subtitle.isEmpty ? '换个角度，重新读一条街。' : route.subtitle,
      '城',
      color: const Color(0xff343e35),
      printColor: const Color(0xffe9a783),
      sealColor: AppColors.terracotta,
    );
  }
}

class _DiscoveryStoryIndex extends StatelessWidget {
  const _DiscoveryStoryIndex({required this.home});
  final CityStoryHome home;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
      key: const ValueKey('city-short-stories-action'),
      label: '打开城市短篇',
      onTap: () => _open(context),
      child: Container(
          height: 58,
          decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0x35252824)),
                  bottom: BorderSide(color: Color(0x222d3026)))),
          child: Row(children: [
            Text('城市短篇', style: discoverySerif(22)),
            const SizedBox(width: 12),
            Expanded(child: Text('把几分钟，留给街角。', style: discoverySans(11))),
            const DiscoveryIcon(DiscoveryMark.arrowUpRight,
                size: 22, color: AppColors.terracotta),
          ])));
  Future<void> _open(BuildContext context) async {
    final stories = <String, CityStoryCard>{};
    for (final module in home.modules) {
      for (final item in module.items) {
        stories.putIfAbsent(item.story.id, () => item);
      }
    }
    final cards = stories.values.toList();
    final selected = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: AppColors.paper,
        shape: const RoundedRectangleBorder(),
        builder: (sheetContext) => Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .88),
            decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.terracotta, width: 3))),
            padding: const EdgeInsets.fromLTRB(23, 16, 23, 25),
            child: SafeArea(
                top: false,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('CITY STORIES / 短篇集',
                                style: discoverySans(10, spacing: .8))),
                        _DiscoveryIconButton(
                            mark: DiscoveryMark.close,
                            label: '关闭城市短篇',
                            onTap: () => Navigator.pop(sheetContext))
                      ]),
                      Text('读一处日常。', style: discoverySerif(36, spacing: -1.8)),
                      const SizedBox(height: 20),
                      Flexible(
                          child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: cards.length,
                              itemBuilder: (context, index) {
                                final card = cards[index];
                                return DiscoveryTouch(
                                    key: ValueKey(
                                        'city-short-story-${card.story.id}'),
                                    label:
                                        '${card.contentType}：${card.story.title}',
                                    onTap: () => Navigator.pop(
                                        sheetContext, card.story.id),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                        decoration: const BoxDecoration(
                                            border: Border(
                                                top: BorderSide(
                                                    color: Color(0x22252824)))),
                                        child: Row(children: [
                                          Text('${index + 1}'.padLeft(2, '0'),
                                              style: const TextStyle(
                                                  fontFamily: 'Georgia',
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 16,
                                                  color: AppColors.terracotta)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(card.contentType,
                                                    style: discoverySans(10)),
                                                const SizedBox(height: 4),
                                                Text(card.story.title,
                                                    style: discoverySerif(20)),
                                              ])),
                                          const SizedBox(width: 12),
                                          const DiscoveryIcon(
                                              DiscoveryMark.arrowUpRight,
                                              size: 22),
                                        ])));
                              })),
                    ]))));
    if (selected != null && context.mounted) context.push('/story/$selected');
  }
}
