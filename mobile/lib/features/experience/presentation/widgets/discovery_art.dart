import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

TextStyle discoverySerif(
  double size, {
  Color color = AppColors.ink,
  FontWeight weight = FontWeight.w500,
  double height = 1.5,
  double spacing = 0,
}) =>
    TextStyle(
      fontFamily: 'Noto Serif SC',
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color,
    );

TextStyle discoverySans(
  double size, {
  Color color = const Color(0xff77796e),
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  double spacing = 0,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color,
    );

/// The same outlined marks used by the approved paper prototype. Keeping these
/// paths local avoids platform-dependent Material icon silhouettes.
enum DiscoveryMark {
  book,
  bookmark,
  search,
  arrowUpRight,
  arrowLeft,
  arrowRight,
  arrowDown,
  down,
  close,
  check,
  pin,
  radio,
  play,
  pause,
  sliders,
  headphones,
}

class DiscoveryIcon extends StatelessWidget {
  const DiscoveryIcon(
    this.mark, {
    super.key,
    this.size = 20,
    this.color = AppColors.ink,
    this.filled = false,
    this.stroke = 1.5,
  });
  final DiscoveryMark mark;
  final double size;
  final Color color;
  final bool filled;
  final double stroke;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child:
              CustomPaint(painter: _MarkPainter(mark, color, filled, stroke)),
        ),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark, this.color, this.filled, this.stroke);
  final DiscoveryMark mark;
  final Color color;
  final bool filled;
  final double stroke;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (mark) {
      case DiscoveryMark.book:
        path.moveTo(12, 7);
        path.cubicTo(8, 4, 4, 4, 2, 5);
        path.lineTo(2, 20);
        path.cubicTo(5, 18, 9, 19, 12, 21);
        path.cubicTo(15, 19, 19, 18, 22, 20);
        path.lineTo(22, 5);
        path.cubicTo(19, 4, 15, 4, 12, 7);
        path.lineTo(12, 21);
      case DiscoveryMark.bookmark:
        path.moveTo(19, 21);
        path.lineTo(12, 17);
        path.lineTo(5, 21);
        path.lineTo(5, 5);
        path.quadraticBezierTo(5, 3, 7, 3);
        path.lineTo(17, 3);
        path.quadraticBezierTo(19, 3, 19, 5);
        path.close();
        if (filled) canvas.drawPath(path, Paint()..color = color);
      case DiscoveryMark.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 7.5, pen);
        path.moveTo(16, 16);
        path.lineTo(21, 21);
      case DiscoveryMark.arrowUpRight:
        path.moveTo(7, 17);
        path.lineTo(17, 7);
        path.moveTo(7, 7);
        path.lineTo(17, 7);
        path.lineTo(17, 17);
      case DiscoveryMark.arrowLeft:
        path.moveTo(19, 12);
        path.lineTo(5, 12);
        path.moveTo(12, 5);
        path.lineTo(5, 12);
        path.lineTo(12, 19);
      case DiscoveryMark.arrowRight:
        path.moveTo(5, 12);
        path.lineTo(19, 12);
        path.moveTo(12, 5);
        path.lineTo(19, 12);
        path.lineTo(12, 19);
      case DiscoveryMark.arrowDown:
        path.moveTo(12, 5);
        path.lineTo(12, 19);
        path.moveTo(5, 12);
        path.lineTo(12, 19);
        path.lineTo(19, 12);
      case DiscoveryMark.down:
        path.moveTo(6, 9);
        path.lineTo(12, 15);
        path.lineTo(18, 9);
      case DiscoveryMark.close:
        path.moveTo(6, 6);
        path.lineTo(18, 18);
        path.moveTo(18, 6);
        path.lineTo(6, 18);
      case DiscoveryMark.check:
        path.moveTo(4, 12);
        path.lineTo(9, 17);
        path.lineTo(20, 6);
      case DiscoveryMark.pin:
        path.moveTo(20, 10);
        path.cubicTo(20, 16, 12, 22, 12, 22);
        path.cubicTo(12, 22, 4, 16, 4, 10);
        path.arcToPoint(const Offset(20, 10), radius: const Radius.circular(8));
        canvas.drawCircle(const Offset(12, 10), 2.5, pen);
      case DiscoveryMark.radio:
        canvas.drawCircle(const Offset(12, 12), 2.2, pen);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 7),
          math.pi * 1.15,
          math.pi * .7,
          false,
          pen,
        );
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 10),
          math.pi * 1.18,
          math.pi * .64,
          false,
          pen,
        );
      case DiscoveryMark.play:
        path.moveTo(8, 5);
        path.lineTo(19, 12);
        path.lineTo(8, 19);
        path.close();
        if (filled) canvas.drawPath(path, Paint()..color = color);
      case DiscoveryMark.pause:
        path.moveTo(8, 5);
        path.lineTo(8, 19);
        path.moveTo(16, 5);
        path.lineTo(16, 19);
      case DiscoveryMark.sliders:
        path.moveTo(3, 6);
        path.lineTo(7, 6);
        path.moveTo(11, 6);
        path.lineTo(21, 6);
        path.moveTo(3, 12);
        path.lineTo(13, 12);
        path.moveTo(17, 12);
        path.lineTo(21, 12);
        path.moveTo(3, 18);
        path.lineTo(5, 18);
        path.moveTo(9, 18);
        path.lineTo(21, 18);
        for (final offset in [
          const Offset(9, 6),
          const Offset(15, 12),
          const Offset(7, 18),
        ]) {
          canvas.drawCircle(offset, 2, pen);
        }
      case DiscoveryMark.headphones:
        path.moveTo(3, 14);
        path.lineTo(3, 11);
        path.arcToPoint(const Offset(21, 11), radius: const Radius.circular(9));
        path.lineTo(21, 14);
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 12, 4, 9),
            const Radius.circular(2),
          ),
        );
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(17, 12, 4, 9),
            const Radius.circular(2),
          ),
        );
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark ||
      old.color != color ||
      old.filled != filled ||
      old.stroke != stroke;
}

class DiscoveryTouch extends StatefulWidget {
  const DiscoveryTouch({
    required this.child,
    required this.onTap,
    super.key,
    this.label,
    this.selected,
    this.tint = false,
    this.onLongPress,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? label;
  final bool? selected;
  final bool tint;
  @override
  State<DiscoveryTouch> createState() => _DiscoveryTouchState();
}

class _DiscoveryTouchState extends State<DiscoveryTouch> {
  bool _pressed = false;
  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      enabled: widget.onTap != null,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: widget.onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onTapDown: widget.onTap == null ? null : (_) => _set(true),
            onTapUp: (_) => _set(false),
            onTapCancel: () => _set(false),
            child: AnimatedContainer(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(
                0,
                _pressed && widget.tint && !reduced ? 1 : 0,
                0,
              ),
              decoration: BoxDecoration(
                color: _pressed && widget.tint
                    ? const Color(0x0a252824)
                    : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: AnimatedOpacity(
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 180),
                opacity: widget.onTap == null
                    ? .3
                    : _pressed && !widget.tint
                        ? .76
                        : 1,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoveryBrand extends StatelessWidget {
  const DiscoveryBrand({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        label: '打开个人档案',
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 33,
                height: 36,
                child: CustomPaint(painter: _BrandPainter()),
              ),
              const SizedBox(width: 7),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '见地',
                    style: discoverySerif(
                      24,
                      weight: FontWeight.w600,
                      height: 1,
                      spacing: .48,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'THE CITY, UNFOLDED',
                    style: discoverySans(
                      6,
                      spacing: .48,
                      height: 1,
                      color: const Color(0xff817764),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    final path = Path()
      ..moveTo(7, 29)
      ..cubicTo(-1, 18, 21, 0, 32, 11)
      ..cubicTo(43, 22, 15, 38, 8, 28)
      ..cubicTo(1, 18, 27, 10, 29, 23)
      ..cubicTo(31, 32, 21, 38, 17, 35);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.terracotta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BrandPainter old) => false;
}

class DiscoveryCircle extends StatelessWidget {
  const DiscoveryCircle({
    required this.child,
    this.color = AppColors.terracotta,
    this.angle = -.157,
    super.key,
  });
  final Widget child;
  final Color color;
  final double angle;
  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _CirclePainter(color, angle),
        child: child,
      );
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.color, this.angle);
  final Color color;
  final double angle;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      color != old.color || angle != old.angle;
}

class DiscoveryPhoto extends StatelessWidget {
  const DiscoveryPhoto({
    required this.source,
    this.alignment = Alignment.center,
    this.saturation = .82,
    super.key,
  });
  final String source;
  final Alignment alignment;
  final double saturation;
  @override
  Widget build(BuildContext context) {
    final image = source.isEmpty
        ? _fallback()
        : Image.network(
            source,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: alignment,
            errorBuilder: (_, __, ___) => _fallback(),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const ColoredBox(color: Color(0xffe4e4d8)),
          );
    final v = 1 - saturation, r = .213 * v, g = .715 * v, b = .072 * v;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        r + saturation,
        g,
        b,
        0,
        0,
        r,
        g + saturation,
        b,
        0,
        0,
        r,
        g,
        b + saturation,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: image,
    );
  }

  Widget _fallback() => const ColoredBox(
        color: Color(0xffe7e9d6),
        child: Center(
          child: DiscoveryIcon(
            DiscoveryMark.pin,
            size: 28,
            color: Color(0xff869273),
          ),
        ),
      );
}

class DiscoveryPaperButton extends StatelessWidget {
  const DiscoveryPaperButton({
    required this.label,
    required this.onTap,
    super.key,
    this.color = AppColors.ink,
    this.child,
  });
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Widget? child;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        label: label,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: discoverySans(14, color: AppColors.paper),
                ),
              ),
              child ??
                  const DiscoveryIcon(
                    DiscoveryMark.arrowUpRight,
                    color: AppColors.paper,
                    size: 19,
                  ),
            ],
          ),
        ),
      );
}

/// Retains the physical paper silhouette independently of photo dimensions.
class JournalPhotoClipper extends CustomClipper<Path> {
  const JournalPhotoClipper({this.town = false});
  final bool town;
  @override
  Path getClip(Size s) {
    final radius = math.min(town ? 145.0 : 165.0, s.width);
    final rounded = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & s,
          topLeft: Radius.circular(town ? 4 : radius),
          topRight: Radius.circular(town ? radius : 0),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
      );
    final fold = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height * .92)
      ..lineTo(s.width * .85, s.height)
      ..lineTo(0, s.height)
      ..close();
    return Path.combine(ui.PathOperation.intersect, rounded, fold);
  }

  @override
  bool shouldReclip(JournalPhotoClipper old) => town != old.town;
}
