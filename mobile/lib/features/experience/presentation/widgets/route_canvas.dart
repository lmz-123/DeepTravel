import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/tour_runtime.dart';

@immutable
class RouteCanvasPoint {
  const RouteCanvasPoint({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.triggerRadiusM,
    this.enabled = true,
    this.semanticsLabel,
    this.tooltip,
    this.markerColor,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final double triggerRadiusM;
  final bool enabled;
  final String? semanticsLabel;
  final String? tooltip;
  final Color? markerColor;
}

/// Resolves the spatial data shown by [RouteCanvas] from the route payload.
///
/// Audio-tour trigger regions are authoritative because they are also used by
/// the unlock engine. Legacy stops remain as a compatibility fallback.
List<RouteCanvasPoint> routeCanvasPointsFor(RouteExperience route) {
  final fragments = route.audioTour?.fragments ?? const [];
  if (fragments.isNotEmpty) {
    return fragments.map((fragment) {
      final title = fragment.title?.trim();
      final preview = fragment.safePreview.trim();
      return RouteCanvasPoint(
        id: fragment.id,
        label: title?.isNotEmpty == true
            ? title!
            : preview.isNotEmpty
                ? preview
                : '故事节点',
        latitude: fragment.triggerRegion.latitude,
        longitude: fragment.triggerRegion.longitude,
        triggerRadiusM: fragment.triggerRegion.entryRadiusM.toDouble(),
      );
    }).toList(growable: false);
  }
  return route.stops
      .map(
        (stop) => RouteCanvasPoint(
          id: stop.id,
          label: stop.title,
          latitude: stop.latitude,
          longitude: stop.longitude,
          triggerRadiusM: 50,
        ),
      )
      .toList(growable: false);
}

@immutable
class RouteCanvasProjection {
  const RouteCanvasProjection._({
    required this.size,
    required this.latitudeOrigin,
    required this.longitudeOrigin,
    required this.longitudeMetersPerDegree,
    required this.localCenter,
    required this.pixelsPerMeter,
    required this.edgePadding,
  });

  factory RouteCanvasProjection.fromPoints(
    List<RouteCanvasPoint> points,
    Size size, {
    double edgePadding = 24,
  }) {
    if (points.isEmpty || size.isEmpty) {
      return RouteCanvasProjection._(
        size: size,
        latitudeOrigin: 0,
        longitudeOrigin: 0,
        longitudeMetersPerDegree: 111320,
        localCenter: Offset.zero,
        pixelsPerMeter: 1,
        edgePadding: edgePadding,
      );
    }

    final latitudeOrigin = points
            .map((point) => point.latitude)
            .reduce((value, next) => value + next) /
        points.length;
    final longitudeOrigin = points
            .map((point) => point.longitude)
            .reduce((value, next) => value + next) /
        points.length;
    final longitudeMetersPerDegree =
        111320 * math.cos(latitudeOrigin * math.pi / 180);
    final local = points
        .map(
          (point) => Offset(
            (point.longitude - longitudeOrigin) * longitudeMetersPerDegree,
            (point.latitude - latitudeOrigin) * 110540,
          ),
        )
        .toList(growable: false);
    final minX = local.map((point) => point.dx).reduce(math.min);
    final maxX = local.map((point) => point.dx).reduce(math.max);
    final minY = local.map((point) => point.dy).reduce(math.min);
    final maxY = local.map((point) => point.dy).reduce(math.max);
    final largestRadius =
        points.map((point) => point.triggerRadiusM).fold<double>(0, math.max);
    final spanX = math.max(maxX - minX + largestRadius * 2, 100);
    final spanY = math.max(maxY - minY + largestRadius * 2, 100);
    final availableWidth = math.max(size.width - edgePadding * 2, 1);
    final availableHeight = math.max(size.height - edgePadding * 2, 1);
    final pixelsPerMeter =
        math.min(availableWidth / spanX, availableHeight / spanY);

    return RouteCanvasProjection._(
      size: size,
      latitudeOrigin: latitudeOrigin,
      longitudeOrigin: longitudeOrigin,
      longitudeMetersPerDegree: longitudeMetersPerDegree,
      localCenter: Offset((minX + maxX) / 2, (minY + maxY) / 2),
      pixelsPerMeter: pixelsPerMeter,
      edgePadding: edgePadding,
    );
  }

  final Size size;
  final double latitudeOrigin;
  final double longitudeOrigin;
  final double longitudeMetersPerDegree;
  final Offset localCenter;
  final double pixelsPerMeter;
  final double edgePadding;

  Offset project(
    double latitude,
    double longitude, {
    bool clampToCanvas = false,
  }) {
    final local = Offset(
      (longitude - longitudeOrigin) * longitudeMetersPerDegree,
      (latitude - latitudeOrigin) * 110540,
    );
    var result = Offset(
      size.width / 2 + (local.dx - localCenter.dx) * pixelsPerMeter,
      size.height / 2 - (local.dy - localCenter.dy) * pixelsPerMeter,
    );
    if (clampToCanvas) {
      result = Offset(
        result.dx.clamp(edgePadding / 2, size.width - edgePadding / 2),
        result.dy.clamp(edgePadding / 2, size.height - edgePadding / 2),
      );
    }
    return result;
  }

  double radiusPixels(double meters) => meters * pixelsPerMeter;
}

class RouteCanvas extends StatefulWidget {
  const RouteCanvas({
    required this.points,
    super.key,
    this.userLocation,
    this.height = 300,
    this.selectedPointId,
    this.nodeKeyPrefix = 'route-canvas-node-',
    this.nodeDotKeyPrefix,
    this.onPointSelected,
  });

  final List<RouteCanvasPoint> points;
  final LocationSample? userLocation;
  final double? height;
  final String? selectedPointId;
  final String nodeKeyPrefix;
  final String? nodeDotKeyPrefix;
  final ValueChanged<RouteCanvasPoint>? onPointSelected;

  @override
  State<RouteCanvas> createState() => _RouteCanvasState();
}

class _RouteCanvasState extends State<RouteCanvas> {
  String? _selectedPointId;

  @override
  void initState() {
    super.initState();
    _selectedPointId = widget.selectedPointId ?? widget.points.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant RouteCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPointId != oldWidget.selectedPointId &&
        widget.points.any((point) => point.id == widget.selectedPointId)) {
      _selectedPointId = widget.selectedPointId;
    }
    if (!widget.points.any((point) => point.id == _selectedPointId)) {
      _selectedPointId =
          widget.selectedPointId ?? widget.points.firstOrNull?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '节点分布，共 ${widget.points.length} 个节点',
      child: Container(
        key: const ValueKey('route-spatial-canvas'),
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .09),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 17, 3),
              child: Text(
                '节点分布',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _buildSpatialStage(
                  context,
                  Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpatialStage(BuildContext context, Size size) {
    final projection = RouteCanvasProjection.fromPoints(widget.points, size);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final location = widget.userLocation;
    final userPoint = location == null
        ? null
        : projection.project(
            location.latitude,
            location.longitude,
            clampToCanvas: true,
          );

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _SpatialBackgroundPainter(
              points: widget.points,
              projection: projection,
              selectedPointId: _selectedPointId,
            ),
          ),
        ),
        for (final point in widget.points)
          _NodeLabel(
            point: point,
            position: projection.project(point.latitude, point.longitude),
            canvasSize: size,
          ),
        for (final point in widget.points)
          _NodeButton(
            point: point,
            position: projection.project(point.latitude, point.longitude),
            selected: point.id == _selectedPointId,
            nodeKey: ValueKey('${widget.nodeKeyPrefix}${point.id}'),
            dotKey: widget.nodeDotKeyPrefix == null
                ? null
                : ValueKey('${widget.nodeDotKeyPrefix}${point.id}'),
            onTap: point.enabled
                ? () {
                    setState(() => _selectedPointId = point.id);
                    widget.onPointSelected?.call(point);
                  }
                : null,
          ),
        if (location != null && userPoint != null)
          _AnimatedUserLocation(
            location: location,
            position: userPoint,
            accuracyRadius:
                projection.radiusPixels(location.accuracyM).clamp(12, 70),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 1400),
          ),
      ],
    );
  }
}

class _NodeLabel extends StatelessWidget {
  const _NodeLabel({
    required this.point,
    required this.position,
    required this.canvasSize,
  });

  final RouteCanvasPoint point;
  final Offset position;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    const width = 96.0;
    const height = 26.0;
    late final double left;
    late final double top;
    if (position.dy < 48) {
      left = (position.dx - width / 2).clamp(3, canvasSize.width - width - 3);
      top = position.dy + 17;
    } else if (position.dy > canvasSize.height - 48) {
      left = (position.dx - width / 2).clamp(3, canvasSize.width - width - 3);
      top = position.dy - height - 17;
    } else if (position.dx < canvasSize.width / 2) {
      left = (position.dx + 18).clamp(3, canvasSize.width - width - 3);
      top = position.dy - height / 2;
    } else {
      left = (position.dx - width - 18).clamp(3, canvasSize.width - width - 3);
      top = position.dy - height / 2;
    }
    return Positioned(
      left: left,
      top: top.clamp(2, canvasSize.height - height - 2),
      width: width,
      height: height,
      child: IgnorePointer(
        child: Align(
          alignment: position.dx < canvasSize.width / 2
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Text(
            point.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

class _NodeButton extends StatelessWidget {
  const _NodeButton({
    required this.point,
    required this.position,
    required this.selected,
    required this.nodeKey,
    required this.dotKey,
    required this.onTap,
  });

  final RouteCanvasPoint point;
  final Offset position;
  final bool selected;
  final Key nodeKey;
  final Key? dotKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Positioned(
        left: position.dx - 24,
        top: position.dy - 24,
        width: 48,
        height: 48,
        child: Semantics(
          key: nodeKey,
          button: true,
          enabled: point.enabled,
          selected: selected,
          label: point.semanticsLabel ?? point.label,
          child: Tooltip(
            message: point.tooltip ?? point.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(
                child: AnimatedContainer(
                  key: dotKey,
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 28 : 24,
                  height: selected ? 28 : 24,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.terracotta
                        : point.enabled
                            ? point.markerColor ?? AppColors.white
                            : AppColors.ink.withValues(alpha: .16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.terracotta
                          : point.enabled
                              ? AppColors.ink
                              : AppColors.ink.withValues(alpha: .3),
                      width: 1.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: .13),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.white
                            : point.enabled
                                ? AppColors.ink
                                : AppColors.white.withValues(alpha: .7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _AnimatedUserLocation extends StatelessWidget {
  const _AnimatedUserLocation({
    required this.location,
    required this.position,
    required this.accuracyRadius,
    required this.duration,
  });

  static const _blue = Color(0xFF2878C8);

  final LocationSample location;
  final Offset position;
  final double accuracyRadius;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final diameter = accuracyRadius * 2;
    return AnimatedPositioned(
      key: const ValueKey('route-canvas-user-motion'),
      duration: duration,
      curve: Curves.easeOutCubic,
      left: position.dx - accuracyRadius,
      top: position.dy - accuracyRadius,
      width: diameter,
      height: diameter,
      child: Semantics(
        key: const ValueKey('route-canvas-user-location'),
        label: '你的位置，定位精度约 ${location.accuracyM.round()} 米',
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: .13),
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withValues(alpha: .75)),
              ),
              child: const SizedBox.expand(),
            ),
            TweenAnimationBuilder<double>(
              key: ValueKey(location.recordedAt),
              tween: Tween(begin: 0, end: 1),
              duration: duration == Duration.zero
                  ? Duration.zero
                  : const Duration(milliseconds: 1100),
              builder: (context, value, _) => Opacity(
                opacity: 1 - value,
                child: Transform.scale(
                  scale: 1 + value * 1.6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _blue, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _blue, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              left: accuracyRadius + 10,
              top: accuracyRadius - 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '你',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpatialBackgroundPainter extends CustomPainter {
  const _SpatialBackgroundPainter({
    required this.points,
    required this.projection,
    required this.selectedPointId,
  });

  final List<RouteCanvasPoint> points;
  final RouteCanvasProjection projection;
  final String? selectedPointId;

  @override
  void paint(Canvas canvas, Size size) {
    final water = Path()
      ..moveTo(size.width * .72, size.height * .05)
      ..cubicTo(size.width * .94, size.height * .14, size.width * .88,
          size.height * .4, size.width * .76, size.height * .52)
      ..cubicTo(size.width * .61, size.height * .68, size.width * .78,
          size.height * .91, size.width * .55, size.height * .94)
      ..cubicTo(size.width * .42, size.height * .71, size.width * .61,
          size.height * .58, size.width * .6, size.height * .4)
      ..cubicTo(size.width * .58, size.height * .22, size.width * .57,
          size.height * .11, size.width * .72, size.height * .05)
      ..close();
    canvas.drawPath(
      water,
      Paint()..color = const Color(0xFF618491).withValues(alpha: .1),
    );

    final guidePaint = Paint()
      ..color = AppColors.ink.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .05, size.height * .17)
        ..cubicTo(size.width * .27, size.height * .08, size.width * .43,
            size.height * .22, size.width * .95, size.height * .13),
      guidePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .09, size.height * .87)
        ..cubicTo(size.width * .35, size.height * .65, size.width * .57,
            size.height * .96, size.width * .94, size.height * .72),
      guidePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .2, 0)
        ..cubicTo(size.width * .31, size.height * .35, size.width * .1,
            size.height * .62, size.width * .22, size.height),
      guidePaint,
    );

    for (final point in points) {
      final position = projection.project(point.latitude, point.longitude);
      final radius =
          projection.radiusPixels(point.triggerRadiusM).clamp(8, 82).toDouble();
      final selected = point.id == selectedPointId;
      canvas.drawCircle(
        position,
        radius,
        Paint()
          ..color = AppColors.terracotta.withValues(alpha: .13)
          ..style = PaintingStyle.fill,
      );
      if (selected) {
        canvas.drawCircle(
          position,
          radius,
          Paint()
            ..color = AppColors.terracotta
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpatialBackgroundPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.projection != projection ||
      oldDelegate.selectedPointId != selectedPointId;
}
