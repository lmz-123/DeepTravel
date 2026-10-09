import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import 'widgets/discovery_art.dart';

const _paper = Color(0xfff5f0e7);
const _ink = Color(0xff30372d);
const _rust = Color(0xffc84832);
const _muted = Color(0xff807664);
const _line = Color(0xffd7d2c5);

String cityAtlasCategory(RouteExperience route) {
  final theme = route.theme;
  if (RegExp('海|滨|沙滩').hasMatch(theme)) return '海边';
  if (RegExp('山|自然|森林|郊野').hasMatch(theme)) return '山野';
  if (RegExp('街|巷|古城|老城|历史').hasMatch(theme)) return '街巷';
  if (RegExp('建筑|设计|艺术|商业').hasMatch(theme)) return '建筑';
  return theme.isEmpty ? '城市' : theme;
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
      super.key});
  final String citySlug;
  final List<Offset> coordinates;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        label: '城市地图，查看景点与介绍',
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
                  child: FutureBuilder<List<_District>>(
                    future: _districts(citySlug),
                    builder: (context, snapshot) => CustomPaint(
                        painter: _AtlasPainter(
                            districts: snapshot.data ?? const [],
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
                        Text('城市地图',
                            style: discoverySerif(25,
                                weight: FontWeight.w500, color: _ink)),
                        const SizedBox(height: 7),
                        Text('查看景点与介绍  ↗',
                            style: discoverySans(11, color: _rust)),
                      ])),
            ])),
      );
}

class CityAtlas extends StatefulWidget {
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
      super.key});
  final String citySlug, cityName;
  final List<RouteExperience> routes;
  final Set<String> saved, busyFavorites;
  final ValueChanged<RouteExperience> onFavorite, onOpen;
  final VoidCallback onBack;
  final bool visible;
  @override
  State<CityAtlas> createState() => _CityAtlasState();
}

class _CityAtlasState extends State<CityAtlas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
      vsync: this, value: 1, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  String _filter = '全部';
  String? _selected;
  double _zoom = 1, _startZoom = 1;
  Offset _pan = Offset.zero, _startPan = Offset.zero, _startFocal = Offset.zero;
  late Future<List<_District>> _geometry;
  List<RouteExperience> get _routes =>
      widget.routes.where((route) => route.isPublished).toList();
  List<RouteExperience> get _visible => _routes
      .where((route) => _filter == '全部' || cityAtlasCategory(route) == _filter)
      .toList();
  @override
  void initState() {
    super.initState();
    _geometry = _districts(widget.citySlug);
  }

  @override
  void didUpdateWidget(CityAtlas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.visible &&
        widget.visible &&
        !MediaQuery.disableAnimationsOf(context)) {
      _arrival.forward(from: 0);
    }
    if (oldWidget.citySlug != widget.citySlug) {
      _geometry = _districts(widget.citySlug);
      _filter = '全部';
      _selected = null;
      _zoom = 1;
      _pan = Offset.zero;
    }
    if (_filter != '全部' &&
        !_routes.any((route) => cityAtlasCategory(route) == _filter)) {
      _filter = '全部';
    }
  }

  void _changeZoom(double next, Size size) {
    final value = next.clamp(1.0, 5.0);
    setState(() {
      _pan = (size.center(Offset.zero) -
          (size.center(Offset.zero) - _pan) * (value / _zoom));
      _zoom = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selected =
        visible.where((route) => route.id == _selected).firstOrNull ??
            visible.firstOrNull;
    final categories = [
      '全部',
      ...{'街巷', '海边', '山野', '建筑', ..._routes.map(cityAtlasCategory)}
    ];
    final side = MediaQuery.sizeOf(context).width <= 360 ? 19.0 : 23.0;
    return FadeTransition(
        opacity: _arrival.drive(CurveTween(curve: Curves.easeOutQuart)),
        child: SingleChildScrollView(
            key: const PageStorageKey('city-map-scroll'),
            padding: const EdgeInsets.only(bottom: 110),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: SizedBox(
                      height: 51,
                      child: Row(children: [
                        DiscoveryTouch(
                            label: '返回随刊',
                            onTap: widget.onBack,
                            child: SizedBox(
                                height: 44,
                                child: Row(children: [
                                  const DiscoveryIcon(DiscoveryMark.arrowLeft,
                                      size: 17, color: _muted),
                                  const SizedBox(width: 7),
                                  Text('随刊',
                                      style: discoverySans(11, color: _muted)),
                                ]))),
                        const Spacer(),
                        Text(
                            widget.citySlug == 'shenzhen'
                                ? 'CITY ATLAS / SZ'
                                : 'CITY ATLAS',
                            style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                                color: _muted)),
                      ]))),
              Padding(
                padding: EdgeInsets.fromLTRB(side, 5, side, 0),
                child: SizedBox(
                    width: double.infinity,
                    child: Stack(children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('循着好奇，',
                                style: discoverySerif(39,
                                    color: _ink,
                                    height: 1.22,
                                    weight: FontWeight.w600,
                                    spacing: -2.3)),
                            Padding(
                                padding: const EdgeInsets.only(left: 35),
                                child: Text('走进城市。',
                                    style: discoverySerif(39,
                                        color: _rust,
                                        height: 1.22,
                                        weight: FontWeight.w600,
                                        spacing: -2.3))),
                          ]),
                      Positioned(
                          top: 10,
                          right: 0,
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text: visible.length.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 23,
                                    color: _rust)),
                            TextSpan(
                                text: ' 处发现',
                                style: discoverySans(11, color: _muted)),
                          ]))),
                    ])),
              ),
              Container(
                  height: 59,
                  margin: EdgeInsets.fromLTRB(side, 0, side, 0),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _line))),
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final category in categories)
                          Padding(
                              padding: const EdgeInsets.only(right: 15),
                              child: DiscoveryTouch(
                                label: '$category主题',
                                selected: _filter == category,
                                onTap: () => setState(() {
                                  _filter = category;
                                  _selected = null;
                                }),
                                child: SizedBox(
                                    width: 58,
                                    height: 48,
                                    child: Center(
                                        child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3),
                                      decoration: _filter == category
                                          ? BoxDecoration(
                                              border: Border.all(
                                                  color: _rust, width: .8),
                                              borderRadius:
                                                  BorderRadius.circular(50))
                                          : null,
                                      child: Text(category,
                                          style: discoverySerif(16,
                                              color: _filter == category
                                                  ? _rust
                                                  : _ink)),
                                    ))),
                              )),
                      ]))),
              FutureBuilder<List<_District>>(
                  future: _geometry,
                  builder: (context, snapshot) =>
                      _map(snapshot.data ?? const [], visible, selected?.id)),
              if (selected != null)
                _sheet(selected)
              else
                Padding(
                    padding: EdgeInsets.all(side),
                    child: Text(
                        _routes.isEmpty ? '这座城市的景点正在准备中。' : '这个主题还没有景点，换一个看看。',
                        style: discoverySans(13, color: _muted))),
              if (visible.any((route) => cityAtlasCoordinate(route) == null))
                Padding(
                    padding: EdgeInsets.fromLTRB(side, 12, side, 0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('以下景点暂无地图位置，仍可查看介绍',
                              style: discoverySans(11, color: _muted)),
                          Wrap(spacing: 12, children: [
                            for (final route in visible.where(
                                (route) => cityAtlasCoordinate(route) == null))
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _selected = route.id),
                                  child: Text(route.title))
                          ]),
                        ])),
              Padding(
                  padding: EdgeInsets.fromLTRB(side, 8, side, 0),
                  child: Text(
                      widget.citySlug == 'shenzhen'
                          ? '底图：DataV 地理数据 · 地点：见地内容库 · 非导航地图'
                          : '地点：见地内容库 · 地点分布示意，非导航地图',
                      style: discoverySans(9, color: _muted))),
            ])));
  }

  bool _labelBelow(RouteExperience route) =>
      ['海边', '建筑'].contains(cityAtlasCategory(route));

  Widget _map(List<_District> districts, List<RouteExperience> visible,
      String? selected) {
    final coordinates =
        _routes.map(cityAtlasCoordinate).whereType<Offset>().toList();
    return LayoutBuilder(builder: (context, constraints) {
      final size =
          Size(constraints.maxWidth, constraints.maxWidth <= 370 ? 317 : 291);
      final projection = _Projection(districts, coordinates, size);
      final markers =
          <({RouteExperience route, Offset anchor, Offset point})>[];
      for (final route in visible) {
        final coordinate = cityAtlasCoordinate(route);
        if (coordinate == null) continue;
        final anchor = projection.project(coordinate) * _zoom + _pan;
        // Screen-space displacement preserves geographic anchors while separating
        // neighboring labels and their 44 px touch targets at every zoom level.
        final offset = switch (cityAtlasCategory(route)) {
          '海边' => const Offset(10, 17),
          '街巷' => const Offset(-12, -29),
          '建筑' => const Offset(12, 30),
          _ => const Offset(-3, -21),
        };
        var point = anchor + offset;
        Rect touch(Offset p) =>
            Rect.fromCenter(center: p, width: 44, height: 44);
        Rect label(RouteExperience r, Offset p) => Rect.fromCenter(
            center: p + Offset(0, _labelBelow(r) ? 34 : -26),
            width: (r.title.characters.length * 11.0 + 12).clamp(44.0, 132.0),
            height: 26);
        for (var attempt = 0; attempt < 24; attempt++) {
          if (!markers.any((m) =>
              touch(point).overlaps(touch(m.point)) ||
              label(route, point).overlaps(label(m.route, m.point)) ||
              label(route, point).overlaps(touch(m.point)) ||
              touch(point).overlaps(label(m.route, m.point)))) {
            break;
          }
          final angle = attempt * 2.4;
          final radius = 35 + (attempt ~/ 6) * 20;
          point = anchor +
              Offset(math.cos(angle) * radius, math.sin(angle) * radius);
        }
        markers.add((route: route, anchor: anchor, point: point));
      }
      return SizedBox.fromSize(
          size: size,
          child: ClipRect(
              child: ColoredBox(
                  color: const Color(0xffe9e9df),
                  child: Stack(children: [
                    Positioned.fill(
                        child: GestureDetector(
                      key: const ValueKey('city-map-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _startZoom = _zoom;
                        _startPan = _pan;
                        _startFocal = details.localFocalPoint;
                      },
                      onScaleUpdate: (details) => setState(() {
                        _zoom = (_startZoom * details.scale).clamp(1.0, 5.0);
                        _pan = details.localFocalPoint -
                            (_startFocal - _startPan) * (_zoom / _startZoom);
                      }),
                      child: CustomPaint(
                          painter: _AtlasPainter(
                              districts: districts,
                              coordinates: coordinates,
                              zoom: _zoom,
                              pan: _pan)),
                    )),
                    Positioned.fill(
                        child: IgnorePointer(
                            child: CustomPaint(
                                painter: _Leaders(markers
                                    .map((m) => (m.anchor, m.point))
                                    .toList())))),
                    for (final marker in markers)
                      _marker(marker.route, marker.point,
                          marker.route.id == selected),
                    Positioned(
                        left: 22,
                        top: 15,
                        child: Text('N ↑',
                            style: discoverySans(12, color: _muted))),
                    Positioned(
                        left: 23,
                        bottom: 16,
                        child: IgnorePointer(
                            child: Text(
                                coordinates.isEmpty
                                    ? '景点位置正在完善'
                                    : '拖动地图 · 点一处，慢慢看',
                                style: discoverySans(11,
                                    color: const Color(0xff7f8477))))),
                    Positioned(
                        right: 17,
                        bottom: 20,
                        child: Container(
                            decoration: BoxDecoration(
                                color: _paper,
                                border: Border.all(color: _line),
                                borderRadius: BorderRadius.circular(3)),
                            child: Column(children: [
                              _tool('放大地图', '+',
                                  () => _changeZoom(_zoom * 1.4, size)),
                              _tool('缩小地图', '−',
                                  () => _changeZoom(_zoom / 1.4, size)),
                              _tool(
                                  '查看全城',
                                  '⛶',
                                  () => setState(() {
                                        _zoom = 1;
                                        _pan = Offset.zero;
                                      })),
                            ]))),
                  ]))));
    });
  }

  Widget _marker(RouteExperience route, Offset point, bool selected) {
    final below = _labelBelow(route);
    final width =
        (route.title.characters.length * 11.0 + 12).clamp(44.0, 132.0);
    return Positioned(
        left: point.dx - width / 2,
        top: point.dy - (below ? 22 : 38),
        child: DiscoveryTouch(
          key: ValueKey('city-map-point-${route.id}'),
          selected: selected,
          label: '${route.title}，${cityAtlasCategory(route)}，查看介绍',
          onTap: () => setState(() => _selected = route.id),
          child: ExcludeSemantics(
              child: SizedBox(
                  width: width,
                  height: below ? 70 : 60,
                  child: Stack(children: [
                    Positioned(
                        left: 0,
                        right: 0,
                        top: below ? 0 : 16,
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
                    Positioned(
                        left: 0,
                        right: 0,
                        top: below ? 43 : 0,
                        child: Center(
                            child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                              color: selected ? _rust : _paper,
                              borderRadius: BorderRadius.circular(2)),
                          child: Text(route.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: discoverySans(11,
                                  color: selected ? _paper : _ink)),
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
              margin: const EdgeInsets.symmetric(horizontal: 13),
              padding: const EdgeInsets.fromLTRB(17, 9, 17, 0),
              decoration: const BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(2))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(width: 28, height: 2, color: _line)),
                    const SizedBox(height: 10),
                    Row(children: [
                      ClipRRect(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(36)),
                          child: SizedBox(
                              width: 76,
                              height: 83,
                              child: route.heroImage.isEmpty
                                  ? _thumb(route)
                                  : Image.network(route.heroImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _thumb(route)))),
                      const SizedBox(width: 15),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                '${route.district} / ${cityAtlasCategory(route)}',
                                style: discoverySans(11, color: _muted)),
                            Text(route.title,
                                style: discoverySerif(25,
                                    weight: FontWeight.w600,
                                    color: _ink,
                                    height: 1.5)),
                            Text(
                                '${route.durationMinutes} 分钟 · ${route.distanceKm.toStringAsFixed(1)} km · ${route.numberOfStops} 处故事',
                                style: discoverySans(11, color: _muted)),
                          ])),
                    ]),
                    Padding(
                        padding: const EdgeInsets.only(top: 13, bottom: 10),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Text(
                                route.description.isNotEmpty
                                    ? route.description
                                    : route.subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: discoverySans(12,
                                    height: 1.85, color: _ink)))),
                    Container(
                        decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: _line))),
                        child: Row(children: [
                          Expanded(
                              child: DiscoveryTouch(
                                  key: const ValueKey('city-map-open'),
                                  label: '翻开${route.title}这段漫游',
                                  onTap: () => widget.onOpen(route),
                                  child: SizedBox(
                                      height: 47,
                                      child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('翻开这段漫游    ↗',
                                              style: discoverySans(12,
                                                  color: _rust)))))),
                          IconButton(
                              tooltip:
                                  '${widget.saved.contains(route.id) ? '取消收藏' : '收藏'}${route.title}',
                              onPressed: widget.busyFavorites.contains(route.id)
                                  ? null
                                  : () => widget.onFavorite(route),
                              icon: DiscoveryIcon(DiscoveryMark.heart,
                                  size: 20,
                                  color: _rust,
                                  filled: widget.saved.contains(route.id))),
                        ])),
                  ]))));
  Widget _thumb(RouteExperience route) => ColoredBox(
      color: const Color(0xffe0e5c5),
      child: Center(
          child: Text(route.title.characters.firstOrNull ?? '',
              style: discoverySerif(38, color: const Color(0xff687355)))));
}

class _District {
  const _District(this.name, this.center, this.polygons);
  final String name;
  final Offset center;
  final List<List<List<Offset>>> polygons;
}

List<_District>? _shenzhen;
Future<List<_District>> _districts(String city) async {
  if (city != 'shenzhen') return const [];
  if (_shenzhen != null) return _shenzhen!;
  return rootBundle.loadString('assets/maps/shenzhen.geojson').then((source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return _shenzhen = (data['features'] as List).map((feature) {
      final props = feature['properties'];
      final center = props['center'] as List;
      final geometry = feature['geometry'];
      final polygons = geometry['type'] == 'Polygon'
          ? [geometry['coordinates']]
          : geometry['coordinates'] as List;
      return _District(
          props['name'] as String,
          Offset((center[0] as num).toDouble(), (center[1] as num).toDouble()),
          polygons
              .map<List<List<Offset>>>((polygon) => (polygon as List)
                  .map<List<Offset>>((ring) => (ring as List)
                      .map<Offset>((point) => Offset(
                          (point[0] as num).toDouble(),
                          (point[1] as num).toDouble()))
                      .toList())
                  .toList())
              .toList());
    }).toList();
  });
}

Offset _mercator(Offset point) => Offset(point.dx * math.pi / 180,
    -math.log(math.tan(math.pi / 4 + point.dy * math.pi / 360)));

class _Projection {
  _Projection(List<_District> districts, List<Offset> coordinates, Size size,
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
      {required this.districts,
      required this.coordinates,
      required this.zoom,
      required this.pan,
      this.miniature = false});
  final List<_District> districts;
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
      if (!miniature && ['宝安区', '龙岗区', '坪山区', '龙华区'].contains(district.name)) {
        final label = TextPainter(
            text: TextSpan(
                text: district.name,
                style: discoverySans(11,
                        color: const Color(0xff9b9789), spacing: 1.4)
                    .copyWith(fontFamily: 'Noto Sans SC')),
            textDirection: TextDirection.ltr)
          ..layout();
        label.paint(
            canvas,
            project(district.center) -
                Offset(label.width / 2, label.height / 2));
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
          text: const TextSpan(
              text: 'SHENZHEN',
              style: TextStyle(
                  fontFamily: 'Georgia',
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
      old.districts != districts ||
      old.coordinates != coordinates ||
      old.zoom != zoom ||
      old.pan != pan;
}

class _Leaders extends CustomPainter {
  const _Leaders(this.lines);
  final List<(Offset, Offset)> lines;
  @override
  void paint(Canvas canvas, Size size) {
    for (final (anchor, point) in lines) {
      canvas.drawLine(
          anchor,
          point,
          Paint()
            ..color = const Color(0xff9d9e88)
            ..strokeWidth = .8);
      canvas.drawCircle(anchor, 2, Paint()..color = const Color(0xff8e967a));
    }
  }

  @override
  bool shouldRepaint(_Leaders old) => old.lines != lines;
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
