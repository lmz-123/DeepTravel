import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/nearby_story_points.dart';
import 'route_manual/manual_visuals.dart';

const _red = Color(0xFFBC4432);
const _muted = Color(0xFF76796C);
const _line = Color(0x2F252824);

/// A null modal result means dismissal; a null fragment means automatic mode.
class CompanionPointChoice {
  const CompanionPointChoice.automatic() : fragmentId = null;
  const CompanionPointChoice.point(this.fragmentId);

  final String? fragmentId;
}

/// The distance directory only chooses a target. It never starts a walk or
/// changes the story currently playing.
class CompanionPointPicker extends StatefulWidget {
  const CompanionPointPicker({
    required this.routeTitle,
    required this.points,
    required this.targetId,
    required this.automatic,
    required this.hasLocation,
    super.key,
  });

  final String routeTitle;
  final List<NearbyStoryPoint> points;
  final String? targetId;
  final bool automatic;
  final bool hasLocation;

  @override
  State<CompanionPointPicker> createState() => _CompanionPointPickerState();
}

enum _PointFilter { all, unexplored, heard }

class _CompanionPointPickerState extends State<CompanionPointPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late final bool _orderedByDistance;
  late final List<String> _order;
  _PointFilter _filter = _PointFilter.all;

  @override
  void initState() {
    super.initState();
    _orderedByDistance = widget.hasLocation;
    final sorted = [...widget.points]..sort((a, b) {
        if (_orderedByDistance) {
          final distance = (a.distanceMeters ?? double.infinity)
              .compareTo(b.distanceMeters ?? double.infinity);
          if (distance != 0) return distance;
        }
        final position = a.fragment.position.compareTo(b.fragment.position);
        return position != 0
            ? position
            : a.fragment.id.compareTo(b.fragment.id);
      });
    _order = sorted.map((point) => point.fragment.id).toList();
  }

  @override
  void didUpdateWidget(covariant CompanionPointPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GPS continues updating, but rows must not move away from a user's finger.
    final currentIds = widget.points.map((point) => point.fragment.id).toSet();
    _order.removeWhere((id) => !currentIds.contains(id));
    final knownIds = _order.toSet();
    _order.addAll(currentIds.where((id) => !knownIds.contains(id)));
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _refreshList() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width <= 375;
    final byId = {for (final point in widget.points) point.fragment.id: point};
    final query = _search.text.trim().toLowerCase();
    final visible = _order.map((id) => byId[id]!).where((point) {
      final accepted = switch (_filter) {
        _PointFilter.all => true,
        _PointFilter.unexplored => _isUnexplored(point),
        _PointFilter.heard => point.status == NearbyStoryPointStatus.heard,
      };
      return accepted &&
          point.fragment.publicPlaceName.toLowerCase().contains(query);
    }).toList();

    return Material(
      key: const ValueKey('companion-point-picker'),
      color: manualPaper,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
          left: small ? 20 : 23,
          right: small ? 20 : 23,
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            // Keep search and filters reachable when the keyboard or larger
            // text leaves too little room for the full editorial introduction.
            final compact = constraints.maxHeight < 520 * scale;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _top(),
                if (!compact) _introduction(small),
                _searchField(),
                _filters(small),
                Expanded(
                  child: CustomScrollView(
                    key: const ValueKey('companion-point-list'),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (compact)
                        SliverToBoxAdapter(child: _introduction(small)),
                      if (visible.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 35),
                            child: Text(
                              widget.points.isEmpty
                                  ? '这条路的地点，正在慢慢展开。'
                                  : query.isNotEmpty
                                      ? '没有找到这个地点，换个名字试试。'
                                      : _filter == _PointFilter.heard
                                          ? '还没有听过的地点，沿途慢慢发现。'
                                          : '这条路的地点，你都已探索过。',
                              textAlign: TextAlign.center,
                              style: _type(12, color: _muted),
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) => _PointRow(
                            key: ValueKey(
                                'companion-point-${visible[index].fragment.id}'),
                            point: visible[index],
                            isTarget:
                                visible[index].fragment.id == widget.targetId,
                            automatic: widget.automatic,
                            hasLocation: widget.hasLocation,
                            onTap: () => Navigator.of(context).pop(
                              CompanionPointChoice.point(
                                  visible[index].fragment.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!compact) _foot(),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _top() => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: Text('ALONG THE WAY / 沿途地点',
                  style:
                      _type(9, color: const Color(0xFF8A7760), spacing: 1.2)),
            ),
            IconButton(
              key: const ValueKey('companion-point-close'),
              tooltip: '关闭地点选择',
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const CustomPaint(
                size: Size(18, 18),
                painter: _PickerIconPainter(close: true),
              ),
            ),
          ],
        ),
      );

  Widget _introduction(bool small) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, bottom: 8),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: '选一处，\n'),
                const TextSpan(text: '慢慢靠近。', style: TextStyle(color: _red)),
              ]),
              style: _type(small ? 30 : 32,
                  serif: true,
                  weight: FontWeight.w500,
                  height: 1.45,
                  spacing: -1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Text('${widget.routeTitle} · ${widget.points.length} 处地点',
                style: _type(10, color: _muted)),
          ),
          Semantics(
            button: true,
            selected: widget.automatic,
            child: InkWell(
              key: const ValueKey('companion-point-auto'),
              onTap: () => Navigator.of(context)
                  .pop(const CompanionPointChoice.automatic()),
              child: Container(
                constraints: const BoxConstraints(minHeight: 76),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: manualInk),
                    bottom: BorderSide(color: _line),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('随脚步，自动发现',
                              style: _type(19,
                                  serif: true,
                                  height: 1.5,
                                  weight: FontWeight.w500,
                                  spacing: -.5)),
                          const SizedBox(height: 4),
                          Text('优先关注最近的未探索地点', style: _type(10, color: _muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 19,
                      height: 19,
                      margin: const EdgeInsets.only(right: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              widget.automatic ? _red : const Color(0xFF7A7D6C),
                        ),
                      ),
                      child: widget.automatic
                          ? Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: _red),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _searchField() => Container(
        margin: const EdgeInsets.only(top: 12),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _line))),
        child: Row(
          children: [
            const CustomPaint(
              size: Size(16, 16),
              painter: _PickerIconPainter(close: false),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Semantics(
                label: '搜索沿途地点',
                child: TextField(
                  key: const ValueKey('companion-point-search'),
                  controller: _search,
                  onChanged: (_) => _refreshList(),
                  style: _type(16),
                  cursorColor: _red,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: '找一个地点',
                    hintStyle: _type(16, color: const Color(0xFF939384)),
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _filters(bool small) => Container(
        constraints: const BoxConstraints(minHeight: 53),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: manualInk))),
        child: Row(
          children: [
            for (final filter in _PointFilter.values) ...[
              if (filter != _PointFilter.all) SizedBox(width: small ? 22 : 25),
              Flexible(
                child: _FilterButton(
                  key: ValueKey('companion-point-filter-${filter.name}'),
                  label: switch (filter) {
                    _PointFilter.all => '全部',
                    _PointFilter.unexplored => '未探索',
                    _PointFilter.heard => '已听过',
                  },
                  count: widget.points
                      .where((point) => switch (filter) {
                            _PointFilter.all => true,
                            _PointFilter.unexplored => _isUnexplored(point),
                            _PointFilter.heard =>
                              point.status == NearbyStoryPointStatus.heard,
                          })
                      .length,
                  selected: _filter == filter,
                  onTap: () {
                    _filter = filter;
                    _refreshList();
                  },
                ),
              ),
            ],
          ],
        ),
      );

  Widget _foot() => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(bottom: 9),
        decoration:
            const BoxDecoration(border: Border(top: BorderSide(color: _line))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${_orderedByDistance ? '按距离排列' : '按路线顺序排列'} · '
                '${widget.hasLocation ? '直线约距' : '等待定位'}',
                style: _type(9, color: _muted),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text('选择地点后继续随行',
                  textAlign: TextAlign.right, style: _type(9, color: _muted)),
            ),
          ],
        ),
      );
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.point,
    required this.isTarget,
    required this.automatic,
    required this.hasLocation,
    required this.onTap,
    super.key,
  });

  final NearbyStoryPoint point;
  final bool isTarget;
  final bool automatic;
  final bool hasLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fragment = point.fragment;
    final distance = hasLocation ? point.distanceMeters : null;
    final known = distance != null && distance.isFinite && distance >= 0;
    final value = !known
        ? '—'
        : distance >= 1000
            ? (distance / 1000).toStringAsFixed(1)
            : distance.round().toString();
    final unit = !known
        ? '距离待定'
        : distance >= 1000
            ? '公里'
            : '米';
    final status = switch (point.status) {
      NearbyStoryPointStatus.heard => '已听过',
      NearbyStoryPointStatus.triggered => '已探索',
      _ => '未探索',
    };
    final caption = fragment.safePreview.trim();
    final meta = isTarget
        ? automatic
            ? '自动发现的下一处'
            : '✓ 当前距离目标'
        : caption.isEmpty || caption == fragment.publicPlaceName
            ? status
            : '$status · $caption';

    return Semantics(
      button: true,
      selected: isTarget && !automatic,
      label: '${fragment.publicPlaceName}，'
          '${known ? '约$value$unit' : '距离未知'}，$status，设为距离目标',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 83),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line))),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: CustomPaint(
                  painter: isTarget ? const _TargetCirclePainter() : null,
                  child: Text(
                    fragment.position.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: _number(23,
                        color: isTarget ? _red : const Color(0xFF9A9684),
                        height: 1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fragment.publicPlaceName,
                        style: _type(18,
                            serif: true,
                            weight: FontWeight.w500,
                            height: 1.55,
                            spacing: -.5,
                            color: isTarget ? _red : manualInk)),
                    const SizedBox(height: 4),
                    Text(meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _type(9, color: isTarget ? _red : _muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: _number(21, height: 1.2)),
                    const SizedBox(height: 3),
                    Text(unit, style: _type(9, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              widthFactor: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: label),
                      const WidgetSpan(child: SizedBox(width: 4)),
                      TextSpan(
                          text: count.toString(),
                          style: _number(11, color: selected ? _red : _muted)),
                    ]),
                    style: _type(11, color: selected ? _red : _muted),
                  ),
                  if (selected)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Transform.rotate(
                        angle: -3 * math.pi / 180,
                        child: const SizedBox(
                          height: 1,
                          child: ColoredBox(color: _red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TargetCirclePainter extends CustomPainter {
  const _TargetCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-17 * math.pi / 180);
    canvas.drawOval(
      const Rect.fromLTWH(-18, -16, 36, 32),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x9CBC4432),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TargetCirclePainter oldDelegate) => false;
}

class _PickerIconPainter extends CustomPainter {
  const _PickerIconPainter({required this.close});
  final bool close;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = close ? manualInk : _muted
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (close) {
      canvas.drawLine(const Offset(18, 6), const Offset(6, 18), paint);
      canvas.drawLine(const Offset(6, 6), const Offset(18, 18), paint);
    } else {
      canvas.drawCircle(const Offset(11, 11), 8, paint);
      canvas.drawLine(const Offset(21, 21), const Offset(16.65, 16.65), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PickerIconPainter oldDelegate) =>
      oldDelegate.close != close;
}

bool _isUnexplored(NearbyStoryPoint point) =>
    point.status != NearbyStoryPointStatus.heard &&
    point.status != NearbyStoryPointStatus.triggered;

TextStyle _type(double size,
        {Color color = manualInk,
        double height = 1.6,
        bool serif = false,
        FontWeight weight = FontWeight.w400,
        double spacing = 0}) =>
    TextStyle(
      fontFamily: serif ? 'Noto Serif SC' : 'Noto Sans SC',
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
    );

TextStyle _number(double size,
        {Color color = manualInk, double height = 1.6}) =>
    TextStyle(
      fontFamily: 'Georgia',
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w400,
      color: color,
    );
