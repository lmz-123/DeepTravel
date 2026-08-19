import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';

class RouteCanvas extends StatelessWidget {
  const RouteCanvas({
    required this.stops,
    super.key,
    this.currentPosition,
    this.height = 220,
  });

  final List<ExperienceStop> stops;
  final int? currentPosition;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '路线示意图，共 ${stops.length} 个站点',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9E4D8),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter:
              _RoutePainter(stops: stops, currentPosition: currentPosition),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.stops, required this.currentPosition});

  final List<ExperienceStop> stops;
  final int? currentPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = AppColors.ink.withValues(alpha: 0.035);
    for (var i = -2; i < 7; i++) {
      canvas.drawLine(
        Offset(i * 58.0, 0),
        Offset(i * 58.0 + 150, size.height),
        background..strokeWidth = i.isEven ? 12 : 5,
      );
    }
    if (stops.isEmpty) return;
    final minLat = stops.map((s) => s.latitude).reduce(math.min);
    final maxLat = stops.map((s) => s.latitude).reduce(math.max);
    final minLng = stops.map((s) => s.longitude).reduce(math.min);
    final maxLng = stops.map((s) => s.longitude).reduce(math.max);
    const padding = 34.0;
    Offset point(ExperienceStop stop) {
      final x = padding +
          ((stop.longitude - minLng) / math.max(maxLng - minLng, 0.00001)) *
              (size.width - padding * 2);
      final y = size.height -
          padding -
          ((stop.latitude - minLat) / math.max(maxLat - minLat, 0.00001)) *
              (size.height - padding * 2);
      return Offset(x, y);
    }

    final routePath = Path()
      ..moveTo(point(stops.first).dx, point(stops.first).dy);
    for (final stop in stops.skip(1)) {
      final p = point(stop);
      routePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      routePath,
      Paint()
        ..color = AppColors.terracotta.withValues(alpha: 0.78)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    for (final stop in stops) {
      final p = point(stop);
      final isCurrent = currentPosition == stop.position;
      canvas.drawCircle(
        p,
        isCurrent ? 11 : 8,
        Paint()..color = isCurrent ? AppColors.terracotta : AppColors.ink,
      );
      canvas.drawCircle(p, isCurrent ? 5 : 3, Paint()..color = AppColors.paper);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.stops != stops;
  }
}
