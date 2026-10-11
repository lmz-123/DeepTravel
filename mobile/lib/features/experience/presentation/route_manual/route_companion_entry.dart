import 'package:flutter/material.dart';

import 'manual_visuals.dart';

/// A page annotation between the directory action and the cover photograph.
/// Navigation only: location and playback are started on the companion page.
class RouteCompanionEntry extends StatefulWidget {
  const RouteCompanionEntry({
    required this.routeName,
    required this.onTap,
    super.key,
  });

  final String routeName;
  final VoidCallback onTap;

  @override
  State<RouteCompanionEntry> createState() => _RouteCompanionEntryState();
}

class _RouteCompanionEntryState extends State<RouteCompanionEntry> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 375;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    const accent = Color(0xFFBC4432);
    return Semantics(
      button: true,
      label: '去随行，预选${widget.routeName}，定位发现，到点提醒',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _highlighted = value),
          onHighlightChanged: (value) => setState(() => _highlighted = value),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text.rich(
                            TextSpan(children: const [
                              TextSpan(text: '边走边发现'),
                            ]),
                            style: manualType(
                              narrow ? 20 : 21,
                              serif: true,
                              weight: FontWeight.w500,
                              spacing: -.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '去随行',
                                  style: manualType(
                                    narrow ? 14 : 15,
                                    serif: true,
                                    weight: FontWeight.w500,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TweenAnimationBuilder<Offset>(
                                  tween: Tween(
                                    begin: Offset.zero,
                                    end: _highlighted
                                        ? const Offset(3, -3)
                                        : Offset.zero,
                                  ),
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  builder: (context, offset, child) =>
                                      Transform.translate(
                                    offset: offset,
                                    child: child,
                                  ),
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CustomPaint(painter: _EntryArrow()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: -4,
                          bottom: 3,
                          child: IgnorePointer(
                            child: SizedBox(
                              width: 83,
                              height: 12,
                              child: CustomPaint(painter: _PencilUnderline()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PencilUnderline extends CustomPainter {
  const _PencilUnderline();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 85, size.height / 12);
    canvas.drawPath(
      Path()
        ..moveTo(2, 8)
        ..cubicTo(25, 3, 56, 3, 81, 5)
        ..moveTo(15, 10)
        ..relativeCubicTo(20, -3, 42, -4, 59, -3),
      Paint()
        ..color = const Color(0xA3BC4432)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(covariant _PencilUnderline oldDelegate) => false;
}

class _EntryArrow extends CustomPainter {
  const _EntryArrow();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(5, 19)
        ..lineTo(19, 5)
        ..moveTo(6, 5)
        ..lineTo(19, 5)
        ..lineTo(19, 18),
      Paint()
        ..color = const Color(0xFFBC4432)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EntryArrow oldDelegate) => false;
}

/// Compact variant for the travel wallet, using the same editorial marks.
class NotePublishAction extends StatelessWidget {
  const NotePublishAction({super.key, this.onTap, this.publishing = false});
  final VoidCallback? onTap;
  final bool publishing;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: onTap != null,
      liveRegion: publishing,
      label: publishing ? '发布中' : '发布见闻',
      child: InkWell(
          onTap: onTap,
          child: Opacity(
              opacity: onTap == null && !publishing ? .4 : 1,
              child: SizedBox(
                  width: publishing ? 100 : 80,
                  height: 49,
                  child: Stack(children: [
                    Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(publishing ? '发布中' : '发布',
                          style: manualType(16,
                              serif: true, color: const Color(0xffbc4432))),
                      const SizedBox(width: 9),
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: publishing
                              ? const CircularProgressIndicator(
                                  strokeWidth: 1.4, color: Color(0xffbc4432))
                              : const CustomPaint(painter: _EntryArrow())),
                    ])),
                    const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                            height: 12,
                            child: CustomPaint(painter: _PencilUnderline()))),
                  ])))));
}

class RouteCompanionLink extends StatelessWidget {
  const RouteCompanionLink({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
            width: 89,
            height: 49,
            child: Stack(children: [
              Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('去随行',
                    style: manualType(15,
                        serif: true,
                        weight: FontWeight.w500,
                        color: const Color(0xffbc4432))),
                const SizedBox(width: 8),
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(painter: _EntryArrow()))
              ])),
              const Positioned(
                  left: 0,
                  bottom: 0,
                  child: SizedBox(
                      width: 83,
                      height: 12,
                      child: CustomPaint(painter: _PencilUnderline()))),
            ])),
      );
}
