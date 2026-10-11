import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'community/notes_controller.dart';
import '../domain/community_models.dart';

import '../domain/models.dart';
import 'city_atlas_geometry.dart';
import 'widgets/discovery_art.dart';

const _paper = Color(0xfff5f0e7);
const _ink = Color(0xff30372d);
const _rust = Color(0xffc84832);
const _muted = Color(0xff807664);
const _line = Color(0xffd7d2c5);

String cityAtlasCategory(RouteExperience route) {
  const labels = {
    'coast': '海边',
    'nature': '山野',
    'streets': '街巷',
    'architecture': '建筑',
    'park': '公园',
    'other': '其他'
  };
  if (labels.containsKey(route.mapCategory)) return labels[route.mapCategory]!;
  String? classify(String text) {
    if (RegExp('海边|海岸|海滨|滨海|海岛|海滩|沙滩|大梅沙').hasMatch(text)) return '海边';
    if (RegExp('山|自然|森林|郊野').hasMatch(text)) return '山野';
    if (RegExp('街|巷|古城|老城|历史|南头|西关|永庆坊').hasMatch(text)) return '街巷';
    if (RegExp('建筑|设计|艺术|商业|万象').hasMatch(text)) return '建筑';
    if (RegExp('公园|园林|花园|绿地').hasMatch(text)) return '公园';
    return null;
  }

  // Legacy themes may describe playback mechanics rather than the place.
  return classify(route.theme) ?? classify(route.title) ?? '其他';
}

/// Coordinates are public catalog coordinates only. Browsing never requests GPS.
Offset? cityAtlasCoordinate(RouteExperience route) {
  Offset? valid(double? latitude, double? longitude) {
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 85 ||
        longitude.abs() > 180 ||
        (latitude == 0 && longitude == 0)) {
      return null;
    }
    return Offset(longitude, latitude);
  }

  final center = valid(route.centerLatitude, route.centerLongitude);
  if (center != null) return center;
  for (final stop in route.stops) {
    final point = valid(stop.latitude, stop.longitude);
    if (point != null) return point;
  }
  return null;
}

class CityMapEntry extends StatelessWidget {
  const CityMapEntry(
      {required this.citySlug,
      required this.onTap,
      this.coordinates = const [],
      this.cityName = '',
      this.mapUpdates,
      this.revision,
      super.key});
  final String citySlug;
  final String cityName;
  final List<Offset> coordinates;
  final CityMapUpdates? mapUpdates;
  final Object? revision;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        label: '全部景点，查看景点与介绍',
        onTap: onTap,
        child: Container(
            height: 118,
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _line))),
            child: Stack(children: [
              Positioned(
                  right: -4,
                  top: 7,
                  width: 154,
                  height: 100,
                  child: CityMapGeometryView(
                    city: citySlug,
                    updates: mapUpdates,
                    revision: revision,
                    builder: (districts) => CustomPaint(
                        painter: _AtlasPainter(
                            cityLabel: citySlug.startsWith('city-')
                                ? cityName
                                : citySlug.toUpperCase(),
                            districts: districts,
                            coordinates: coordinates,
                            zoom: 1,
                            pan: Offset.zero,
                            miniature: true)),
                  )),
              Positioned(
                  right: 22,
                  top: 29,
                  child: Transform.rotate(
                      angle: -.28,
                      child: Container(
                          width: 69,
                          height: 55,
                          decoration: BoxDecoration(
                              border: Border.all(color: _rust),
                              borderRadius: BorderRadius.circular(100)),
                          alignment: Alignment.center,
                          child: const Text('Explore',
                              style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 15,
                                  color: _rust))))),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('THE CITY, MAPPED',
                            style: TextStyle(
                                fontFamily: 'Georgia',
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                                letterSpacing: .7,
                                color: _muted)),
                        const SizedBox(height: 10),
                        Text('全部景点',
                            style: discoverySerif(25,
                                weight: FontWeight.w500, color: _ink)),
                        const SizedBox(height: 7),
                        Text('查看景点与介绍  ↗',
                            style: discoverySans(11, color: _rust)),
                      ])),
            ])),
      );
}

class CityAtlas extends ConsumerStatefulWidget {
  const CityAtlas(
      {required this.citySlug,
      required this.cityName,
      required this.routes,
      required this.saved,
      required this.busyFavorites,
      required this.onFavorite,
      required this.onOpen,
      required this.onBack,
      this.visible = true,
      this.mapUpdates,
      this.revision,
      super.key});
  final String citySlug, cityName;
  final List<RouteExperience> routes;
  final Set<String> saved, busyFavorites;
  final ValueChanged<RouteExperience> onFavorite, onOpen;
  final VoidCallback onBack;
  final bool visible;
  final CityMapUpdates? mapUpdates;
  final Object? revision;
  @override
  ConsumerState<CityAtlas> createState() => _CityAtlasState();
}

class _CityAtlasState extends ConsumerState<CityAtlas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
      vsync: this, value: 1, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _arrival.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  String _filter = '全部', _region = '全部区域', _query = '';
  String? _selected, _focus;
  int? _geometrySignature;
  bool _mapMode = false, _nearest = false;
  int _pageSize = 20;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  double _zoom = 1, _startZoom = 1;
  Offset _pan = Offset.zero, _startPan = Offset.zero, _startFocal = Offset.zero;
  List<RouteExperience> get _routes =>
      widget.routes.where((r) => r.isPublished).toList();
  double? _distance(RouteExperience r) {
    final point = cityAtlasCoordinate(r);
    if (point == null) return null;
    return noteDistance(
        CommunityPlace(
            fragmentId: r.id,
            name: r.title,
            routeSlug: r.slug,
            routeTitle: r.title,
            citySlug: widget.citySlug,
            cityName: widget.cityName,
            latitude: point.dy,
            longitude: point.dx),
        ref.read(notesLocationProvider).value);
  }

  List<RouteExperience> get _visible {
    final result = _routes
        .where((r) =>
            (_filter == '全部' || cityAtlasCategory(r) == _filter) &&
            (_region == '全部区域' || r.district == _region) &&
            ('${r.title} ${r.district} ${r.subtitle}'
                .toLowerCase()
                .contains(_query.toLowerCase())))
        .toList();
    if (_nearest) {
      result.sort((a, b) => (_distance(a) ?? double.infinity)
          .compareTo(_distance(b) ?? double.infinity));
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_mapMode &&
          _scroll.position.extentAfter < 500 &&
          _pageSize < _visible.length) {
        setState(() => _pageSize += 20);
      }
    });
  }

  void _filterChanged(VoidCallback change) => setState(() {
        change();
        _pageSize = 20;
        if (!_visible.any((r) => r.id == _selected)) _selected = null;
        _zoom = 1;
        _pan = Offset.zero;
      });
  @override
  void didUpdateWidget(CityAtlas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.visible && widget.visible) {
      _mapMode = false;
      if (!MediaQuery.disableAnimationsOf(context)) _arrival.forward(from: 0);
    }
    if (oldWidget.citySlug != widget.citySlug) {
      _filter = '全部';
      _region = '全部区域';
      _query = '';
      _search.clear();
      _selected = null;
      _focus = null;
      _mapMode = false;
      _pageSize = 20;
      _zoom = 1;
      _pan = Offset.zero;
    }
  }

  void _changeZoom(double next, Size size) {
    final value = next.clamp(1.0, 24.0);
    setState(() {
      _pan = size.center(Offset.zero) -
          (size.center(Offset.zero) - _pan) * (value / _zoom);
      _zoom = value;
    });
  }

  void _select(RouteExperience r) {
    setState(() {
      _selected = r.id;
      _focus = r.id;
      _mapMode = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _regions() async {
    final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: _paper,
        builder: (c) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              for (final region in [
                '全部区域',
                ..._routes
                    .map((r) => r.district)
                    .where((s) => s.isNotEmpty)
                    .toSet()
              ])
                ListTile(
                    title: Text(region, style: discoverySerif(18)),
                    trailing: region == _region
                        ? const Icon(Icons.check, color: _rust, size: 18)
                        : null,
                    onTap: () => Navigator.pop(c, region))
            ])));
    if (result != null && mounted) _filterChanged(() => _region = result);
  }

  String _admission(RouteExperience r) =>
      switch (r.travelPreparation.admission) {
        'ticket' => '需购票',
        'free' => '免费开放',
        'reservation' => '需预约',
        _ => '',
      };
  @override
  Widget build(BuildContext context) {
    ref.watch(notesLocationProvider);
    final visible = _visible;
    final selected = visible.where((r) => r.id == _selected).firstOrNull;
    final categories = [
      '全部',
      ...{'街巷', '海边', '山野', '建筑', '公园', '其他'}
          .where(_routes.map(cityAtlasCategory).toSet().contains)
    ];
    final side = MediaQuery.sizeOf(context).width < 350 ? 19.0 : 23.0;
    return FadeTransition(
        opacity: _arrival.drive(CurveTween(curve: Curves.easeOutQuart)),
        child: CustomScrollView(
            controller: _scroll,
            // ignore: deprecated_member_use
            cacheExtent: 400,
            slivers: [
              SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SizedBox(
                            height: 65,
                            child: Row(children: [
                              TextButton.icon(
                                  key: const ValueKey('atlas-back'),
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  onPressed: widget.onBack,
                                  icon: const Icon(Icons.arrow_back, size: 17),
                                  label: Text('发现',
                                      style: discoverySans(12, color: _muted))),
                            ])),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                              child: Text('全部景点',
                                  style: discoverySerif(32,
                                      weight: FontWeight.w500))),
                          Text(widget.cityName,
                              style: discoverySans(12, color: _muted))
                        ]),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _search,
                            onChanged: (s) => _filterChanged(() => _query = s),
                            style: discoverySans(14),
                            decoration: InputDecoration(
                                hintText: '搜索景点或区域',
                                hintStyle: discoverySans(14, color: _muted),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: IconButton(
                                    tooltip: '清空搜索',
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      _search.clear();
                                      _filterChanged(() => _query = '');
                                    }),
                                filled: false,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 28),
                                enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: _ink)),
                                focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: _ink)))),
                        const SizedBox(height: 12),
                        Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                                border:
                                    Border(bottom: BorderSide(color: _line))),
                            child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (final category in categories)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(right: 18),
                                        child: InkWell(
                                            onTap: () => _filterChanged(
                                                () => _filter = category),
                                            child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 18),
                                                decoration: BoxDecoration(
                                                    border: Border(
                                                        bottom: BorderSide(
                                                            color: _filter == category
                                                                ? _rust
                                                                : Colors
                                                                    .transparent))),
                                                child: Text(category,
                                                    style: discoverySans(12, color: _filter == category ? _rust : _muted)))))
                                ]))),
                        Row(children: [
                          TextButton(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(64, 44)),
                              onPressed: _regions,
                              child: Text('$_region ⌄',
                                  style: discoverySans(11, color: _ink))),
                          TextButton(
                              onPressed: () async {
                                if (!_nearest &&
                                    ref.read(notesLocationProvider).value ==
                                        null) {
                                  await ref
                                      .read(notesLocationProvider.notifier)
                                      .locate();
                                }
                                if (mounted) {
                                  _filterChanged(() => _nearest = !_nearest);
                                }
                              },
                              child: Text(_nearest ? '距离最近 ⌄' : '推荐 ⌄',
                                  style: discoverySans(11, color: _ink))),
                          const Spacer(),
                          _viewButton(true, Icons.map_outlined, '地图'),
                          _viewButton(false, Icons.view_list_outlined, '列表')
                        ]),
                        if (!_mapMode)
                          Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text('${visible.length} 处景点',
                                  style: discoverySans(11, color: _muted))),
                      ]))),
              if (_mapMode)
                SliverToBoxAdapter(
                    child: Column(children: [
                  CityMapGeometryView(
                      city: widget.citySlug,
                      updates: widget.mapUpdates,
                      revision: (widget.revision, widget.visible),
                      builder: (districts) =>
                          _map(districts, visible, selected?.id)),
                  Padding(
                      padding: EdgeInsets.fromLTRB(side, 15, side, 15),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${visible.length} 处景点',
                              style: discoverySans(11, color: _muted)))),
                  if (selected != null) _sheet(selected),
                  Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text('底图：DataV 地理数据',
                          style: discoverySans(9, color: _muted))),
                ]))
              else
                SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverList.builder(
                        itemCount: math.min(_pageSize, visible.length),
                        itemBuilder: (context, i) => _listRow(visible[i]))),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                            child:
                                Text('没有符合条件的景点', style: discoverySerif(18))))),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ]));
  }

  Widget _viewButton(bool map, IconData icon, String label) => Tooltip(
      message: label,
      child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: InkWell(
              onTap: () => setState(() => _mapMode = map),
              child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: _mapMode == map
                                  ? _rust
                                  : Colors.transparent))),
                  child: Row(children: [
                    Icon(icon,
                        size: 15, color: _mapMode == map ? _rust : _muted),
                    const SizedBox(width: 4),
                    Text(label,
                        style: discoverySerif(13,
                            color: _mapMode == map ? _rust : _muted))
                  ])))));
  Widget _listRow(RouteExperience r) => Container(
      key: ValueKey('place-row-${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          border: Border(
              bottom: const BorderSide(color: _line),
              left: BorderSide(
                  color: _selected == r.id ? _rust : Colors.transparent,
                  width: 2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
            onTap: () => _select(r),
            child: ClipRRect(
                borderRadius:
                    const BorderRadius.only(topRight: Radius.circular(20)),
                child: SizedBox(
                    width: MediaQuery.sizeOf(context).width < 360 ? 75 : 85,
                    height: 114,
                    child: _image(r)))),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
              onTap: () => _select(r),
              child: SizedBox(
                  width: double.infinity,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            [r.district, cityAtlasCategory(r)]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: discoverySans(11, color: _muted)),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(r.title,
                                style: discoverySerif(
                                    MediaQuery.sizeOf(context).width < 360
                                        ? 18
                                        : 20,
                                    weight: FontWeight.w500))),
                        Row(children: [
                          Expanded(
                              child: Text(noteDistanceLabel(_distance(r)),
                                  style: discoverySans(10, color: _muted))),
                          Text(_admission(r),
                              style: discoverySans(10, color: _muted))
                        ]),
                      ]))),
          Row(children: [
            TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _select(r),
                icon: const Icon(Icons.location_on_outlined,
                    size: 14, color: _rust),
                label: Text('地图查看', style: discoverySans(11, color: _rust))),
            const Spacer(),
            TextButton(
                onPressed: () => widget.onOpen(r),
                child: Text('详情 ↗', style: discoverySans(11, color: _muted)))
          ])
        ]))
      ]));
  Widget _image(RouteExperience r) =>
      ScenicThumbnail(url: r.heroImage, label: r.title);

  Widget _map(List<CityAtlasDistrict> districts, List<RouteExperience> visible,
      String? selected) {
    final coordinates =
        _routes.map(cityAtlasCoordinate).whereType<Offset>().toList();
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, 370);
      final signature = Object.hashAll(
          districts.map((d) => Object.hash(d.name, d.polygons.length)));
      if (_geometrySignature != signature) {
        _geometrySignature = signature;
        _focus ??= selected;
      }
      final projection = _Projection(districts, coordinates, size);
      if (_focus != null) {
        final route = visible.where((r) => r.id == _focus).firstOrNull;
        final point = route == null ? null : cityAtlasCoordinate(route);
        if (point != null) {
          _zoom = 3;
          _pan = size.center(Offset.zero) - projection.project(point) * _zoom;
        }
        _focus = null;
      }
      final groups = <List<({RouteExperience route, Offset point})>>[];
      for (final route in visible) {
        final coordinate = cityAtlasCoordinate(route);
        if (coordinate == null) continue;
        final point = projection.project(coordinate) * _zoom + _pan;
        if (!Rect.fromLTWH(-60, -60, size.width + 120, size.height + 120)
            .contains(point)) {
          continue;
        }
        final group = groups
            .where((g) =>
                (g.first.point - point).distance < 48 &&
                g.first.route.id != selected &&
                route.id != selected)
            .firstOrNull;
        if (group == null) {
          groups.add([(route: route, point: point)]);
        } else {
          group.add((route: route, point: point));
        }
      }
      groups.sort((a, b) => (a.first.route.id == selected ? 1 : 0)
          .compareTo(b.first.route.id == selected ? 1 : 0));
      return SizedBox.fromSize(
          size: size,
          child: ClipRect(
              child: GestureDetector(
                  key: const ValueKey('city-map-canvas'),
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    _startZoom = _zoom;
                    _startPan = _pan;
                    _startFocal = d.localFocalPoint;
                  },
                  onScaleUpdate: (d) => setState(() {
                        _zoom = (_startZoom * d.scale).clamp(1.0, 24.0);
                        _pan = d.localFocalPoint -
                            (_startFocal - _startPan) * (_zoom / _startZoom);
                      }),
                  child: ColoredBox(
                      color: const Color(0xffe9e9df),
                      child: Stack(children: [
                        Positioned.fill(
                            child: CustomPaint(
                                painter: _AtlasPainter(
                                    cityLabel: widget.cityName,
                                    districts: districts,
                                    coordinates: coordinates,
                                    zoom: _zoom,
                                    pan: _pan))),
                        for (final group in groups)
                          if (group.length == 1)
                            _marker(group.first.route, group.first.point,
                                group.first.route.id == selected)
                          else
                            Positioned(
                                left: group.first.point.dx - 24,
                                top: group.first.point.dy - 24,
                                child: Semantics(
                                    label: '${group.length} 处景点，放大查看',
                                    button: true,
                                    child: GestureDetector(
                                        onTap: () {
                                          if (_zoom >= 24) {
                                            _showGroup(group
                                                .map((m) => m.route)
                                                .toList());
                                            return;
                                          }
                                          setState(() {
                                            final next =
                                                (_zoom * 2).clamp(1.0, 24.0);
                                            _pan = size.center(Offset.zero) -
                                                (group.first.point - _pan) *
                                                    (next / _zoom);
                                            _zoom = next;
                                          });
                                        },
                                        child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Transform.rotate(
                                                      angle: -.22,
                                                      child: Container(
                                                          width: 33,
                                                          height: 36,
                                                          decoration: BoxDecoration(
                                                              color: const Color(
                                                                  0xffd8dbc7),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          18),
                                                              border: Border.all(
                                                                  color: const Color(
                                                                      0xff9da48b))))),
                                                  Container(
                                                      width: 32,
                                                      height: 32,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                          color: _paper,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(18),
                                                          border: Border.all(
                                                              color: const Color(
                                                                  0xff9da48b))),
                                                      child: Text(
                                                          '${group.length}',
                                                          style: discoverySerif(
                                                              16)))
                                                ]))))),
                        Positioned(
                            left: 22,
                            top: 15,
                            child: IgnorePointer(
                                child: Text('N ↑',
                                    style: discoverySans(12, color: _muted)))),
                        Positioned(
                            right: 17,
                            bottom: 20,
                            child: Container(
                                color: _paper,
                                child: Column(children: [
                                  _tool('放大地图', '+',
                                      () => _changeZoom(_zoom * 1.5, size)),
                                  _tool('缩小地图', '−',
                                      () => _changeZoom(_zoom / 1.5, size)),
                                  _tool(
                                      '查看全城',
                                      '⛶',
                                      () => setState(() {
                                            _zoom = 1;
                                            _pan = Offset.zero;
                                          }))
                                ]))),
                      ])))));
    });
  }

  void _showGroup(List<RouteExperience> routes) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      builder: (c) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
            for (final r in routes)
              ListTile(
                  title: Text(r.title, style: discoverySerif(19)),
                  onTap: () {
                    Navigator.pop(c);
                    _select(r);
                  })
          ])));

  Widget _marker(RouteExperience route, Offset point, bool selected) {
    final width =
        (route.title.characters.length * 11.0 + 12).clamp(44.0, 132.0);
    return Positioned(
        left: point.dx - width / 2,
        top: point.dy - 22,
        child: DiscoveryTouch(
          key: ValueKey('city-map-point-${route.id}'),
          selected: selected,
          label: '${route.title}，${cityAtlasCategory(route)}，查看介绍',
          onTap: () => setState(() => _selected = route.id),
          child: ExcludeSemantics(
              child: SizedBox(
                  width: width,
                  height: 70,
                  child: Stack(children: [
                    Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 44,
                        child: Center(
                            child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          width: selected ? 16 : 12,
                          height: selected ? 16 : 12,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? _rust : _paper,
                              border: Border.all(
                                  color: selected
                                      ? _paper
                                      : const Color(0xff9c9e83),
                                  width: selected ? 2 : 1)),
                        ))),
                    if (selected)
                      Positioned(
                          left: 0,
                          right: 0,
                          top: 43,
                          child: Center(
                              child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                                color: _paper,
                                borderRadius: BorderRadius.circular(2)),
                            child: Text(route.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: discoverySans(11,
                                    color: selected ? _rust : _ink)),
                          ))),
                  ]))),
        ));
  }

  Widget _tool(String label, String glyph, VoidCallback onTap) =>
      DiscoveryTouch(
          label: label,
          onTap: onTap,
          child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color:
                              label == '查看全城' ? Colors.transparent : _line))),
              child: label == '查看全城'
                  ? const DiscoveryIcon(DiscoveryMark.expand,
                      size: 14, color: _ink)
                  : Text(glyph, style: discoverySans(19, color: _ink))));

  Widget _sheet(RouteExperience route) => Semantics(
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      child: _AtlasPlaceArrival(
          key: ValueKey(route.id),
          child: Container(
              key: const ValueKey('city-map-place-sheet'),
              margin: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 350 ? 19 : 23),
              padding: const EdgeInsets.only(top: 20),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _line))),
              child: Stack(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(20)),
                        child: SizedBox(
                            width: 75, height: 85, child: _image(route))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.only(right: 23),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      [route.district, cityAtlasCategory(route)]
                                          .where((s) => s.isNotEmpty)
                                          .join(' · '),
                                      style: discoverySans(11, color: _muted)),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Text(route.title,
                                          style: discoverySerif(23,
                                              weight: FontWeight.w500))),
                                  Text(noteDistanceLabel(_distance(route)),
                                      style: discoverySans(11, color: _muted))
                                ])))
                  ]),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                          route.description.isNotEmpty
                              ? route.description
                              : route.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: discoverySans(12, height: 1.85))),
                  Text(_admission(route),
                      style: discoverySans(11, color: _muted)),
                  DiscoveryTouch(
                      key: const ValueKey('city-map-open'),
                      label: '查看${route.title}详情',
                      onTap: () => widget.onOpen(route),
                      child: SizedBox(
                          height: 48,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  route.travelPreparation.canBook
                                      ? '查看景点与门票  ↗'
                                      : '查看景点  ↗',
                                  style: discoverySerif(17, color: _rust)))))
                ]),
                Positioned(
                    top: 0,
                    right: -10,
                    child: IconButton(
                        tooltip: '取消选中地点',
                        onPressed: () => setState(() => _selected = null),
                        icon: const Icon(Icons.close, size: 15, color: _muted)))
              ]))));
}

Offset _mercator(Offset point) => Offset(point.dx * math.pi / 180,
    -math.log(math.tan(math.pi / 4 + point.dy * math.pi / 360)));

class _Projection {
  _Projection(
      List<CityAtlasDistrict> districts, List<Offset> coordinates, Size size,
      {bool miniature = false}) {
    final points = [
      ...districts.expand((d) => d.polygons.expand((p) => p.expand((r) => r))),
      ...coordinates
    ].map(_mercator).toList();
    if (points.isEmpty) {
      scale = 1;
      origin = Offset.zero;
      return;
    }
    var minX = points.first.dx,
        maxX = minX,
        minY = points.first.dy,
        maxY = minY;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final inset = miniature ? 4.0 : 25.0;
    final top = miniature ? 4.0 : 21.0;
    final bottom = miniature ? 4.0 : 42.0;
    scale = math.min((size.width - inset * 2) / math.max(maxX - minX, .002),
        (size.height - top - bottom) / math.max(maxY - minY, .002));
    origin = Offset(size.width / 2 - (minX + maxX) / 2 * scale,
        top + (size.height - top - bottom) / 2 - (minY + maxY) / 2 * scale);
  }
  late final double scale;
  late final Offset origin;
  Offset project(Offset coordinate) => _mercator(coordinate) * scale + origin;
}

class _AtlasPainter extends CustomPainter {
  const _AtlasPainter(
      {required this.cityLabel,
      required this.districts,
      required this.coordinates,
      required this.zoom,
      required this.pan,
      this.miniature = false});
  final String cityLabel;
  final List<CityAtlasDistrict> districts;
  final List<Offset> coordinates;
  final double zoom;
  final Offset pan;
  final bool miniature;
  @override
  void paint(Canvas canvas, Size size) {
    final projection =
        _Projection(districts, coordinates, size, miniature: miniature);
    Offset project(Offset coordinate) =>
        projection.project(coordinate) * zoom + pan;
    for (var i = 0; i < districts.length; i++) {
      final district = districts[i];
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final polygon in district.polygons) {
        for (final ring in polygon) {
          if (ring.isEmpty) continue;
          final first = project(ring.first);
          path.moveTo(first.dx, first.dy);
          for (final point in ring.skip(1)) {
            final p = project(point);
            path.lineTo(p.dx, p.dy);
          }
          path.close();
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = miniature
                ? const Color(0xffe0e5cb)
                : (i % 3 == 0
                    ? const Color(0xffe2e6ce)
                    : const Color(0xffefeee2)));
      canvas.drawPath(
          path,
          Paint()
            ..color = miniature ? _paper : const Color(0xffc9cbb8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = miniature ? .6 : .8);
    }
    final labels = <Rect>[];
    if (!miniature) {
      for (final district in districts) {
        final label = TextPainter(
            text: TextSpan(
                text: district.name,
                style: discoverySans(11,
                        color: const Color(0xff9b9789), spacing: 1.4)
                    .copyWith(fontFamily: 'Noto Sans SC')),
            textDirection: TextDirection.ltr)
          ..layout();
        final origin = project(district.center) -
            Offset(label.width / 2, label.height / 2);
        final bounds = origin & label.size;
        if ((Offset.zero & size).contains(bounds.topLeft) &&
            (Offset.zero & size).contains(bounds.bottomRight) &&
            !labels.any((other) => other.overlaps(bounds.inflate(4)))) {
          label.paint(canvas, origin);
          labels.add(bounds);
        }
        label.dispose();
      }
    }
    if (miniature) {
      for (final coordinate in coordinates) {
        canvas.drawCircle(project(coordinate), 2, Paint()..color = _rust);
      }
    }
    if (!miniature && districts.isNotEmpty) {
      final label = TextPainter(
          text: TextSpan(
              text: cityLabel,
              style: const TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Color(0xff909e97))),
          textDirection: TextDirection.ltr)
        ..layout();
      label.paint(canvas, Offset(size.width * .49, size.height * .73));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(_AtlasPainter old) =>
      old.cityLabel != cityLabel ||
      old.districts != districts ||
      old.coordinates != coordinates ||
      old.zoom != zoom ||
      old.pan != pan;
}

class _AtlasPlaceArrival extends StatelessWidget {
  const _AtlasPlaceArrival({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 360),
        curve: Curves.easeOutQuart,
        child: child,
        builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)), child: child)),
      );
}

/// Built lazily by the sliver list; decoded images share Flutter's bounded LRU.
class ScenicThumbnail extends StatefulWidget {
  const ScenicThumbnail({super.key, required this.url, required this.label});
  final String url, label;
  @override
  State<ScenicThumbnail> createState() => _ScenicThumbnailState();
}

class _ScenicThumbnailState extends State<ScenicThumbnail> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: const Color(0xffe6e7d8),
      child: widget.url.isEmpty
          ? Center(
              child: Text(widget.label.characters.firstOrNull ?? '',
                  style: discoverySerif(28, color: _muted)))
          : Image.network(widget.url,
              key: ValueKey((widget.url, _attempt)),
              fit: BoxFit.cover,
              cacheWidth: (110 * MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(110, 440),
              frameBuilder: (c, child, frame, synchronous) =>
                  frame != null || synchronous
                      ? child
                      : const SizedBox.expand(),
              errorBuilder: (c, e, stack) => Center(
                  child: IconButton(
                      tooltip: '重新加载图片',
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () async {
                        await NetworkImage(widget.url).evict();
                        if (mounted) setState(() => _attempt++);
                      }))));
}
