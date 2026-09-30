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
    required this.onCompanion,
    required this.onRefresh,
    super.key,
  });
  final DiscoveryState state;
  final Set<String> saved, busyFavorites;
  final ValueChanged<RouteExperience> onFavorite, onOpen;
  final VoidCallback onCity, onAtlas;
  final VoidCallback onCompanion;
  final Future<void> Function() onRefresh;
  @override
  State<_DiscoveryJournal> createState() => _DiscoveryJournalState();
}

class _DiscoveryJournalState extends State<_DiscoveryJournal>
    with SingleTickerProviderStateMixin {
  int _edition = 0;
  late final AnimationController _turn =
      AnimationController.unbounded(vsync: this);
  int _motionEpoch = 0;
  bool _dragging = false;
  bool _reduceMotion = false;
  int? _destination;
  double _quietDrag = 0;
  final Set<String> _warmedImages = {};

  List<RouteExperience> _issues(DiscoveryState state) {
    final routes = state.cards
        .map((card) => card.route)
        .where((route) => route.isPublished)
        .toList();
    return [
      ...routes.where((route) => route.isFeatured),
      ...routes.where((route) => !route.isFeatured),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && !_reduceMotion) {
      final target = _destination ?? 0;
      _resetMotion();
      final issues = _issues(widget.state);
      if (issues.isNotEmpty) _edition = (_edition + target) % issues.length;
    }
    _reduceMotion = reduce;
    _warmNeighbors();
  }

  @override
  void didUpdateWidget(covariant _DiscoveryJournal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = _issues(oldWidget.state);
    final after = _issues(widget.state);
    final sameOrder = before.length == after.length &&
        List.generate(before.length, (i) => before[i].id == after[i].id)
            .every((same) => same);
    if (!sameOrder) {
      final selected =
          before.isEmpty ? null : before[_edition % before.length].id;
      _resetMotion();
      final index = after.indexWhere((route) => route.id == selected);
      _edition = index < 0 ? 0 : index;
    }
    _warmNeighbors();
  }

  void _warmNeighbors() {
    final issues = _issues(widget.state);
    if (issues.isEmpty) return;
    for (final delta in [-1, 0, 1]) {
      final source = issues[(_edition + delta) % issues.length].heroImage;
      if (source.isNotEmpty && _warmedImages.add(source)) {
        precacheImage(NetworkImage(source), context, onError: (_, __) {});
      }
    }
  }

  void _resetMotion() {
    _motionEpoch++;
    _turn.stop();
    _turn.value = 0;
    _dragging = false;
    _destination = null;
    _quietDrag = 0;
  }

  void _change(int delta, int length) {
    if (length < 2 || _turn.isAnimating || _dragging) return;
    _settle(delta, length);
  }

  void _settle(int destination, int length) {
    _dragging = false;
    _destination = destination;
    final epoch = ++_motionEpoch;
    void finish() {
      if (!mounted || epoch != _motionEpoch) return;
      setState(() {
        _edition = (_edition + destination) % length;
        _destination = null;
        _turn.value = 0;
      });
      _warmNeighbors();
    }

    if (_reduceMotion || (_turn.value - destination).abs() < .001) {
      finish();
      return;
    }
    // Match the approved collage timeline, including its minimum settle time.
    final remaining = (_turn.value - destination).abs();
    _turn
        .animateTo(
          destination.toDouble(),
          duration:
              Duration(milliseconds: math.max(220, (820 * remaining).round())),
          curve: const _JournalTurnCurve(),
        )
        .then((_) => finish());
  }

  void _startDrag() {
    _motionEpoch++;
    _turn.stop();
    _destination = null;
    _dragging = true;
    _quietDrag = 0;
  }

  void _dragBy(double dx, double width) {
    if (_reduceMotion) {
      _quietDrag = (_quietDrag - dx / (width * .78)).clamp(-1.0, 1.0);
    } else {
      _turn.value = (_turn.value - dx / (width * .78)).clamp(-1.0, 1.0);
    }
  }

  void _endDrag(int length) {
    if (!_dragging) return;
    final progress = _reduceMotion ? _quietDrag : _turn.value;
    _settle(progress.abs() > .18 ? progress.sign.toInt() : 0, length);
  }

  @override
  void dispose() {
    _motionEpoch++;
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issues = _issues(widget.state);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width <= 360;
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
            padding: const EdgeInsets.only(bottom: 155),
            sliver: SliverToBoxAdapter(
              child: route == null
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: _empty())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 48,
                          margin: EdgeInsets.symmetric(horizontal: pad),
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
                              AnimatedBuilder(
                                animation: _turn,
                                child: Text(
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
                                builder: (context, child) {
                                  final pulse =
                                      math.sin(math.pi * _turn.value.abs());
                                  return Transform.translate(
                                    offset: Offset(0, -pulse * 3 * width / 390),
                                    child: Opacity(
                                        opacity: 1 - pulse * .65, child: child),
                                  );
                                },
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
                        Listener(
                          // Flutter can report an accepted pointer cancellation
                          // as drag-end. Always restore the issue in that case.
                          onPointerCancel: (_) {
                            if (_dragging) {
                              _settle(0, issues.length);
                            }
                          },
                          child: GestureDetector(
                            key: const ValueKey('journal-swipe'),
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart:
                                issues.length < 2 ? null : (_) => _startDrag(),
                            onHorizontalDragUpdate: issues.length < 2
                                ? null
                                : (details) => _dragBy(details.delta.dx, width),
                            onHorizontalDragEnd: issues.length < 2
                                ? null
                                : (_) => _endDrag(issues.length),
                            onHorizontalDragCancel: issues.length < 2
                                ? null
                                : () {
                                    if (_dragging) _settle(0, issues.length);
                                  },
                            child: AnimatedBuilder(
                              animation: _turn,
                              builder: (context, _) {
                                final progress = _turn.value;
                                final neighbor = progress < 0 ? -1 : 1;
                                final next = progress == 0
                                    ? null
                                    : issues[
                                        (_edition + neighbor) % issues.length];
                                final pages = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _JournalCollageCover(
                                      route: route,
                                      nextRoute: next,
                                      city: widget.state.city,
                                      progress: progress.abs(),
                                      direction: neighbor,
                                      onOpen: () => widget.onOpen(route),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: pad),
                                      child: _issueDetails(
                                          route,
                                          next,
                                          width / 390,
                                          progress.abs(),
                                          neighbor),
                                    ),
                                  ],
                                );
                                // Reserve space for either title while turning;
                                // long names must never collide with the footer.
                                return ClipRect(
                                  child: _reduceMotion
                                      ? pages
                                      : AnimatedSize(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeOutQuart,
                                          alignment: Alignment.topCenter,
                                          clipBehavior: Clip.none,
                                          child: pages,
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
                        DiscoveryTouch(
                          label: '打开城市索引',
                          onTap: widget.onAtlas,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: pad),
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
                        const SizedBox(height: 2),
                        DiscoveryTouch(
                          label: '打开随行，开启到点提醒',
                          onTap: widget.onCompanion,
                          child: Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(horizontal: pad),
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 2,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x35252824)),
                                bottom: BorderSide(color: AppColors.terracotta),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                  child: const Center(
                                    child: DiscoveryIcon(
                                      DiscoveryMark.pin,
                                      size: 15,
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '随行',
                                        style: discoverySerif(
                                          17,
                                          color: AppColors.terracotta,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '到点先提醒，再决定听不听',
                                        style: discoverySans(
                                          9,
                                          color: const Color(0xff8a7763),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const DiscoveryIcon(
                                  DiscoveryMark.arrowUpRight,
                                  size: 17,
                                  color: AppColors.terracotta,
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

  Widget _issueDetails(RouteExperience route, RouteExperience? next,
          double scale, double progress, int direction) =>
      Container(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 13),
        decoration: const BoxDecoration(
            border: Border(
          bottom: BorderSide(color: Color(0x222d3026)),
        )),
        child: Row(children: [
          Expanded(
              child: Stack(children: [
            _detailsLayer(route, scale, progress, direction, false),
            if (next != null)
              _detailsLayer(next, scale, progress, direction, true),
          ])),
          IgnorePointer(
            ignoring: progress != 0,
            child: Opacity(
              opacity: 1 - math.sin(math.pi * progress) * .78,
              child: _DiscoveryIconButton(
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
            ),
          ),
        ]),
      );

  Widget _detailsLayer(RouteExperience route, double scale, double progress,
      int direction, bool incoming) {
    final remaining = incoming ? 1 - progress : progress;
    final dir = incoming ? direction : -direction;
    final alpha = incoming
        ? _journalInterval(.5, .95, progress)
        : 1 - _journalInterval(.08, .45, progress);
    return ExcludeSemantics(
      excluding: progress != 0,
      child: IgnorePointer(
        ignoring: progress != 0,
        child: Transform.translate(
          key: ValueKey('journal-page-${route.id}'),
          offset: Offset(dir * remaining * 16 * scale,
              (incoming ? 1 : -1) * remaining * 6 * scale),
          child: Opacity(
            opacity: alpha,
            child: DiscoveryTouch(
              key: ValueKey('route-card-${route.slug}'),
              label: '查看${route.title}',
              onTap: () => widget.onOpen(route),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.state.city?.name ?? ''}  /  ${route.theme}',
                        style: discoverySans(10 * scale,
                            color: const Color(0xff887962))),
                    Row(children: [
                      Flexible(
                          child: Text(route.title,
                              style: discoverySerif(26 * scale,
                                  weight: FontWeight.w600,
                                  height: 1.65,
                                  spacing: -1 * scale),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 15.6 * scale),
                      DiscoveryIcon(DiscoveryMark.arrowUpRight,
                          size: 17.55 * scale, color: const Color(0xffcf4630)),
                    ]),
                    Text(_routeMetadata(route),
                        style: discoverySans(11 * scale,
                            height: 1.8, color: const Color(0xff796f5e))),
                  ]),
            ),
          ),
        ),
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

// Exact easing functions used by journal-photographic-montage.html.
double _journalInterval(double start, double end, double value) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0);

class _JournalTurnCurve extends Curve {
  const _JournalTurnCurve();
  @override
  double transformInternal(double t) =>
      t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}
