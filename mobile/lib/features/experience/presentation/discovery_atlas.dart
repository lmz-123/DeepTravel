part of 'discovery_page.dart';

enum _AtlasDuration { any, short, medium, long }

enum _AtlasOrder { editorial, duration, distance }

const _durationLabels = ['时间不限', '45 分钟内', '45–90 分钟', '90 分钟以上'];
const _durationNotes = ['按你的节奏来', '留一个小空隙', '刚好一个下午', '再走远一点'];
const _sortLabels = ['编辑精选', '用时最短', '路程最短'];

class _DiscoveryAtlas extends StatefulWidget {
  const _DiscoveryAtlas({
    required this.state,
    required this.saved,
    required this.busyFavorites,
    required this.onFavorite,
    required this.onOpen,
    required this.onCity,
    required this.onRefresh,
    super.key,
  });
  final DiscoveryState state;
  final Set<String> saved, busyFavorites;
  final ValueChanged<RouteExperience> onFavorite, onOpen;
  final VoidCallback onCity;
  final Future<void> Function() onRefresh;
  @override
  State<_DiscoveryAtlas> createState() => _DiscoveryAtlasState();
}

class _DiscoveryAtlasState extends State<_DiscoveryAtlas> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _theme = '全部';
  Set<String> _areas = {};
  var _duration = _AtlasDuration.any;
  var _order = _AtlasOrder.editorial;
  bool _onlySaved = false;
  int _limit = 20;
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<RouteExperience> get _routes => widget.state.catalog.routes;
  int get _filterCount =>
      _areas.length + (_duration == _AtlasDuration.any ? 0 : 1);
  bool get _hasConditions =>
      _filterCount > 0 ||
      _theme != '全部' ||
      _search.text.isNotEmpty ||
      _onlySaved;
  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  bool _matches(
    RouteExperience route,
    Set<String> areas,
    _AtlasDuration duration,
  ) {
    final query = _normalize(_search.text);
    return (query.isEmpty ||
            _normalize(
              '${route.title}${route.subtitle}${route.description}${route.theme}${route.district}',
            ).contains(query)) &&
        (_theme == '全部' || route.theme == _theme) &&
        (areas.isEmpty || areas.contains(route.district)) &&
        (!_onlySaved || widget.saved.contains(route.id)) &&
        switch (duration) {
          _AtlasDuration.any => true,
          _AtlasDuration.short => route.durationMinutes <= 45,
          _AtlasDuration.medium =>
            route.durationMinutes > 45 && route.durationMinutes <= 90,
          _AtlasDuration.long => route.durationMinutes > 90,
        };
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
      _limit = 20;
    });
    if (_scroll.hasClients && _scroll.offset > 275) _scroll.jumpTo(275);
  }

  void _reset() => _change(() {
        _search.clear();
        _theme = '全部';
        _areas = {};
        _duration = _AtlasDuration.any;
        _onlySaved = false;
        _order = _AtlasOrder.editorial;
      });
  Future<void> _showFilters() async {
    final areas = _routes
        .map((r) => r.district)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    var draftAreas = {..._areas};
    var draftDuration = _duration;
    final result = await showModalBottomSheet<
        ({Set<String> areas, _AtlasDuration duration})>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      barrierColor: const Color(0x571e2418),
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          final count = _routes
              .where((r) => _matches(r, draftAreas, draftDuration))
              .length;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.terracotta, width: 3),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 29,
                  height: 3,
                  margin: const EdgeInsets.only(top: 10),
                  color: const Color(0xffc6cdb9),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 23, bottom: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MAKE ROOM FOR WANDERING',
                              style: discoverySans(
                                9,
                                spacing: 1,
                                color: const Color(0xff8a947a),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: '给漫游，'),
                                  TextSpan(
                                    text: '留一点时间',
                                    style: discoverySerif(
                                      33,
                                      color: AppColors.terracotta,
                                      spacing: -2,
                                    ),
                                  ),
                                ],
                              ),
                              style: discoverySerif(33, spacing: -2),
                            ),
                          ],
                        ),
                      ),
                      _DiscoveryIconButton(
                        mark: DiscoveryMark.close,
                        label: '关闭筛选',
                        onTap: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (areas.isNotEmpty)
                          _filterSection(
                            title: '想去哪个区域',
                            caption: '可多选',
                            child: LayoutBuilder(
                              builder: (context, c) => Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: areas
                                    .map(
                                      (area) => SizedBox(
                                        width: (c.maxWidth - 16) / 3,
                                        child: DiscoveryTouch(
                                          label: area,
                                          selected: draftAreas.contains(
                                            area,
                                          ),
                                          onTap: () => update(() {
                                            draftAreas.contains(area)
                                                ? draftAreas.remove(area)
                                                : draftAreas.add(area);
                                          }),
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minHeight: 48,
                                            ),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 9,
                                            ),
                                            decoration: BoxDecoration(
                                              color: draftAreas.contains(area)
                                                  ? const Color(0xffdbe782)
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: draftAreas.contains(
                                                  area,
                                                )
                                                    ? const Color(
                                                        0xffa8b976,
                                                      )
                                                    : const Color(
                                                        0xffd8dfca,
                                                      ),
                                              ),
                                            ),
                                            child: Text(
                                              area,
                                              style: discoverySans(
                                                13,
                                                color: draftAreas.contains(
                                                  area,
                                                )
                                                    ? const Color(
                                                        0xff344726,
                                                      )
                                                    : const Color(
                                                        0xff748163,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        _filterSection(
                          title: '这次，留多久',
                          caption: '按步行总时长',
                          child: Column(
                            children: _AtlasDuration.values
                                .map(
                                  (duration) => DiscoveryTouch(
                                    label: _durationLabels[duration.index],
                                    selected: draftDuration == duration,
                                    onTap: () => update(
                                      () => draftDuration = duration,
                                    ),
                                    tint: true,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 49,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color:
                                                duration == _AtlasDuration.long
                                                    ? Colors.transparent
                                                    : const Color(0xffe0e6d4),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: draftDuration == duration
                                                    ? AppColors.terracotta
                                                    : const Color(
                                                        0xffbecda8,
                                                      ),
                                              ),
                                            ),
                                            child: draftDuration == duration
                                                ? Center(
                                                    child: Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: AppColors
                                                            .terracotta,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 11),
                                          Text(
                                            _durationLabels[duration.index],
                                            style: discoverySans(
                                              14,
                                              color: const Color(
                                                0xff555e49,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _durationNotes[duration.index],
                                            style: discoverySans(
                                              12,
                                              color: const Color(
                                                0xff748163,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xffd4dec6)),
                      ),
                    ),
                    child: Row(
                      children: [
                        DiscoveryTouch(
                          label: '重置筛选',
                          onTap: () => update(() {
                            draftAreas = {};
                            draftDuration = _AtlasDuration.any;
                          }),
                          child: SizedBox(
                            width: 72,
                            height: 52,
                            child: Center(
                              child: Text(
                                '重置',
                                style: discoverySans(14).copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: DiscoveryPaperButton(
                            label: '查看 $count 条路线',
                            color: AppColors.terracotta,
                            onTap: () => Navigator.pop(sheetContext, (
                              areas: draftAreas,
                              duration: draftDuration,
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result != null && mounted) {
      _change(() {
        _areas = result.areas;
        _duration = result.duration;
      });
    }
  }

  Widget _filterSection({
    required String title,
    required String caption,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.only(top: 19, bottom: 24),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xffc7d1b7))),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: discoverySans(
                    14,
                    weight: FontWeight.w500,
                    color: const Color(0xff555e49),
                  ),
                ),
                const Spacer(),
                Text(
                  caption,
                  style: discoverySans(12, color: const Color(0xff748163)),
                ),
              ],
            ),
            const SizedBox(height: 17),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 374;
    final pad = narrow ? 19.0 : 22.0;
    final themes = [
      '全部',
      ..._routes.map((r) => r.theme).where((s) => s.isNotEmpty).toSet(),
    ];
    final results =
        _routes.where((route) => _matches(route, _areas, _duration)).toList();
    if (_order != _AtlasOrder.editorial) {
      results.sort(
        (a, b) => _order == _AtlasOrder.duration
            ? a.durationMinutes.compareTo(b.durationMinutes)
            : a.distanceKm.compareTo(b.distanceKm),
      );
    }
    final displayed = math.min(_limit, results.length);
    final savedCount = _routes.where((r) => widget.saved.contains(r.id)).length;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.terracotta,
      child: CustomScrollView(
        key: const PageStorageKey('atlas-scroll'),
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _DiscoveryHeader()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.ink)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'THE CITY, ON FOOT.',
                          style: discoverySans(
                            10,
                            color: AppColors.ink,
                            weight: FontWeight.w500,
                            spacing: 1,
                          ),
                        ),
                        Text('索引 / 02', style: discoverySans(10, spacing: .6)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: '城市索引'),
                                TextSpan(
                                  text: '.',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    color: AppColors.terracotta,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                            style: discoverySerif(
                              narrow ? 40 : 42,
                              height: 1.25,
                              spacing: -2.94,
                            ),
                          ),
                        ),
                        Text(
                          _routes.length.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 42,
                            height: 1,
                            letterSpacing: -2.3,
                            color: AppColors.terracotta,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text('条', style: discoverySans(11)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 13, bottom: 24),
                    child: Row(
                      children: [
                        DiscoveryTouch(
                          label: '选择城市，当前${widget.state.city?.name ?? ''}',
                          onTap: widget.onCity,
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                const DiscoveryIcon(
                                  DiscoveryMark.pin,
                                  size: 15,
                                  color: AppColors.terracotta,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.state.city?.name ?? '选择城市',
                                  style: discoverySerif(
                                    23,
                                    height: 1.4,
                                    spacing: -.69,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                const DiscoveryIcon(
                                  DiscoveryMark.down,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text('不赶路，去读一座城。', style: discoverySans(12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _AtlasStickyHeader(
              height: _filterCount > 0 ? 225 : 177,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Column(
                  children: [
                    Container(
                      height: 49,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.ink),
                        ),
                      ),
                      child: Row(
                        children: [
                          const DiscoveryIcon(
                            DiscoveryMark.search,
                            size: 20,
                            color: Color(0xff62665b),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              onChanged: (_) => _change(() {}),
                              style: discoverySans(16, color: AppColors.ink),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: '搜索街区、地点或故事',
                                hintStyle: discoverySans(
                                  14,
                                  color: const Color(0xff94958a),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                isDense: true,
                                filled: false,
                              ),
                            ),
                          ),
                          if (_search.text.isNotEmpty)
                            _DiscoveryIconButton(
                              mark: DiscoveryMark.close,
                              size: 18,
                              label: '清除搜索',
                              onTap: () => _change(_search.clear),
                            )
                          else
                            Text(
                              '↵',
                              style: discoverySans(
                                18,
                                height: 1,
                                color: const Color(0xff898c7d),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 68,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: themes.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(width: narrow ? 15 : 17),
                        itemBuilder: (_, i) {
                          final theme = themes[i], selected = theme == _theme;
                          return DiscoveryTouch(
                            label: '$theme主题',
                            selected: selected,
                            onTap: () => _change(() => _theme = theme),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 55),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 13),
                                      child: Text(
                                        i.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontStyle: FontStyle.italic,
                                          fontSize: 10,
                                          color: selected
                                              ? AppColors.terracotta
                                              : const Color(0xff9b8971),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  DiscoveryCircle(
                                    color: selected
                                        ? AppColors.terracotta
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        theme,
                                        style: discoverySerif(
                                          15,
                                          spacing: -.45,
                                          color: selected
                                              ? AppColors.terracotta
                                              : const Color(0xff797568),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          DiscoveryTouch(
                            label: '区域和时长筛选',
                            onTap: _showFilters,
                            tint: true,
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  if (!narrow) ...[
                                    const DiscoveryIcon(
                                      DiscoveryMark.sliders,
                                      size: 16,
                                      color: Color(0xff5c6253),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    '区域 / 时长',
                                    style: discoverySans(
                                      12,
                                      color: _filterCount > 0
                                          ? AppColors.terracotta
                                          : const Color(0xff5c6253),
                                    ),
                                  ),
                                  if (_filterCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: CircleAvatar(
                                        radius: 8.5,
                                        backgroundColor: AppColors.terracotta,
                                        child: Text(
                                          '$_filterCount',
                                          style: discoverySans(
                                            11,
                                            height: 1,
                                            color: AppColors.paper,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  const DiscoveryIcon(
                                    DiscoveryMark.down,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: narrow ? 8 : 11),
                          if (!narrow) ...[
                            Container(
                              height: 12,
                              width: 1,
                              color: const Color(0x2b252824),
                            ),
                            const SizedBox(width: 11),
                          ],
                          DiscoveryTouch(
                            label: '只看已收藏',
                            selected: _onlySaved,
                            onTap: () =>
                                _change(() => _onlySaved = !_onlySaved),
                            tint: true,
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  DiscoveryIcon(
                                    DiscoveryMark.bookmark,
                                    size: 15,
                                    color: _onlySaved
                                        ? AppColors.terracotta
                                        : const Color(0xff5c6253),
                                    filled: _onlySaved,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '已收藏',
                                    style: discoverySans(
                                      12,
                                      color: _onlySaved
                                          ? AppColors.terracotta
                                          : const Color(0xff5c6253),
                                    ),
                                  ),
                                  if (savedCount > 0)
                                    Text(
                                      ' $savedCount',
                                      style: const TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 11,
                                        color: AppColors.terracotta,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<_AtlasOrder>(
                            tooltip: '路线排序',
                            initialValue: _order,
                            color: AppColors.paper,
                            onSelected: (value) =>
                                _change(() => _order = value),
                            itemBuilder: (_) => _AtlasOrder.values
                                .map(
                                  (o) => PopupMenuItem(
                                    value: o,
                                    child: Text(_sortLabels[o.index]),
                                  ),
                                )
                                .toList(),
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  Text(
                                    _sortLabels[_order.index],
                                    style: discoverySans(
                                      12,
                                      color: const Color(0xff7f8275),
                                    ),
                                  ),
                                  const DiscoveryIcon(
                                    DiscoveryMark.down,
                                    size: 13,
                                    color: Color(0xff7f8275),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_filterCount > 0)
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._areas.map(
                              (area) => _appliedFilter(
                                area,
                                () => _change(() => _areas.remove(area)),
                              ),
                            ),
                            if (_duration != _AtlasDuration.any)
                              _appliedFilter(
                                _durationLabels[_duration.index],
                                () => _change(
                                  () => _duration = _AtlasDuration.any,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverToBoxAdapter(
              child: Container(
                height: 47,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.ink)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_hasConditions ? '找到' : '收录'} ${results.length} 条路线',
                      style: discoverySans(12),
                    ),
                    Text(
                      '${displayed.toString().padLeft(2, '0')} / ${results.length.toString().padLeft(2, '0')}',
                      style: discoverySans(12, color: const Color(0xff919787)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (results.isEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverToBoxAdapter(child: _empty(savedCount)),
            ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverList.builder(
              itemCount: displayed,
              itemBuilder: (context, index) => _AtlasRouteRow(
                route: results[index],
                index: index,
                saved: widget.saved.contains(results[index].id),
                busy: widget.busyFavorites.contains(results[index].id),
                onOpen: () => widget.onOpen(results[index]),
                onSave: () => widget.onFavorite(results[index]),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 26, pad, 155),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  if (displayed < results.length)
                    DiscoveryTouch(
                      onTap: () => setState(() => _limit += 20),
                      child: Container(
                        height: 51,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.terracotta),
                            bottom: BorderSide(color: AppColors.terracotta),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '再看 ${math.min(20, results.length - displayed)} 条路线',
                              style: discoverySans(
                                14,
                                color: AppColors.terracotta,
                              ),
                            ),
                            const DiscoveryIcon(
                              DiscoveryMark.arrowDown,
                              color: AppColors.terracotta,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (results.isNotEmpty)
                    Text(
                      '—  城市的故事，未完待续。  —',
                      style: discoverySerif(
                        13,
                        color: const Color(0xff8a9777),
                        height: 2,
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    '步行的尺度，刚好认识一座城。',
                    style: discoverySans(12, color: const Color(0xff7d876f)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appliedFilter(String title, VoidCallback remove) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: DiscoveryTouch(
          label: '移除$title筛选',
          onTap: remove,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Container(
              color: const Color(0xffe7ebce),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: Row(
                children: [
                  Text(
                    title,
                    style: discoverySans(12, color: const Color(0xff656c53)),
                  ),
                  const SizedBox(width: 7),
                  const DiscoveryIcon(DiscoveryMark.close, size: 12),
                ],
              ),
            ),
          ),
        ),
      );
  Widget _empty(int savedCount) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 42, 4, 51),
        child: Column(
          children: [
            const Text(
              '∅',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 65,
                height: 1,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              _onlySaved && savedCount == 0 ? '把想走的路，先留下。' : '换个方向，继续找。',
              style: discoverySerif(21),
            ),
            const SizedBox(height: 12),
            Text(
              _onlySaved && savedCount == 0
                  ? '点一下书签，把下一次出发留在这里。'
                  : _search.text.isNotEmpty
                      ? '没有找到与「${_search.text}」匹配的路线，试试地点简称，或放宽筛选条件。'
                      : '暂时没有符合这些条件的路线，试试其他主题、区域或时长。',
              style: discoverySans(
                13,
                height: 1.95,
                color: const Color(0xff78846a),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _reset,
              child: Text(
                '重置全部筛选 ↗',
                style: discoverySans(13, color: AppColors.terracotta),
              ),
            ),
          ],
        ),
      );
}

class _AtlasStickyHeader extends SliverPersistentHeaderDelegate {
  const _AtlasStickyHeader({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      ColoredBox(color: AppColors.paper, child: child);
  @override
  bool shouldRebuild(_AtlasStickyHeader oldDelegate) => true;
}

class _AtlasRouteRow extends StatelessWidget {
  const _AtlasRouteRow({
    required this.route,
    required this.index,
    required this.saved,
    required this.busy,
    required this.onOpen,
    required this.onSave,
  });
  final RouteExperience route;
  final int index;
  final bool saved, busy;
  final VoidCallback onOpen, onSave;
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 374;
    return Container(
      key: ValueKey('atlas-route-${route.id}'),
      padding: const EdgeInsets.only(top: 19, bottom: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2b252824))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DiscoveryTouch(
              label: '查看${route.title}',
              onTap: onOpen,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ClipRRect(
                      borderRadius: index.isEven
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(2),
                              bottomLeft: Radius.circular(2),
                              bottomRight: Radius.circular(15),
                            )
                          : const BorderRadius.only(
                              topLeft: Radius.circular(2),
                              topRight: Radius.circular(22),
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(2),
                            ),
                      child: SizedBox(
                        width: 70,
                        height: 84,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DiscoveryPhoto(
                              source: route.heroImage,
                              saturation: .78,
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 19,
                                height: 19,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xffdbe782),
                                ),
                                child: const DiscoveryIcon(
                                  DiscoveryMark.arrowUpRight,
                                  size: 14,
                                  color: Color(0xff4b5d31),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: narrow ? 11 : 13),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${index + 1}'.padLeft(3, '0'),
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 10,
                                  color: Color(0xffb05e47),
                                ),
                              ),
                              if (route.district.isNotEmpty) ...[
                                Text(route.district, style: discoverySans(12)),
                                Text('·', style: discoverySans(12)),
                              ],
                              Text(route.theme, style: discoverySans(12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            route.title,
                            style: discoverySerif(
                              narrow ? 17 : 18,
                              height: 1.6,
                              spacing: -.72,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            route.subtitle,
                            style: discoverySans(12, height: 1.6),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${route.durationMinutes} 分钟',
                                style: discoverySans(
                                  12,
                                  color: const Color(0xff545d48),
                                ),
                              ),
                              Container(
                                height: 8,
                                width: 1,
                                color: const Color(0xffc4cdb5),
                              ),
                              Text(
                                '${route.distanceKm.toStringAsFixed(1)} km',
                                style: discoverySans(
                                  12,
                                  color: const Color(0xff545d48),
                                ),
                              ),
                              Text(
                                route.isPublished ? _routeFormat(route) : '筹备中',
                                style: discoverySans(
                                  12,
                                  color: const Color(0xff6e7e56),
                                ),
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
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _DiscoveryIconButton(
              mark: DiscoveryMark.bookmark,
              label: '${saved ? '取消收藏' : '收藏'}${route.title}',
              onTap: busy ? null : onSave,
              selected: saved,
              size: 19,
              filled: saved,
              color: saved ? AppColors.terracotta : const Color(0xff929e80),
            ),
          ),
        ],
      ),
    );
  }
}
