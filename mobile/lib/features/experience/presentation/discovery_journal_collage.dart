part of 'discovery_page.dart';

/// The approved photographic montage uses a 390 × 370 artboard. Keeping its
/// coordinates together makes the crop, print registration and type movement
/// scale as one composition on every phone width.
class _JournalCollageCover extends StatelessWidget {
  const _JournalCollageCover({
    required this.route,
    required this.nextRoute,
    required this.city,
    required this.progress,
    required this.direction,
    required this.onOpen,
  });

  final RouteExperience route;
  final RouteExperience? nextRoute;
  final CityExperience? city;
  final double progress;
  final int direction;
  final VoidCallback onOpen;

  static const _width = 390.0;
  static const _height = 370.0;

  @override
  Widget build(BuildContext context) {
    final p = nextRoute == null ? 0.0 : progress.clamp(0.0, 1.0);
    final sign = direction < 0 ? -1.0 : 1.0;
    final layers = [
      _JournalCollageLayer(
          route, _JournalCopy.forRoute(route, city), false, p, sign),
      if (p > 0 && nextRoute != null)
        _JournalCollageLayer(
            nextRoute!, _JournalCopy.forRoute(nextRoute!, city), true, p, sign),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      return Semantics(
        button: true,
        label: '打开${route.title}',
        onTap: p == 0 ? onOpen : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: p == 0 ? onOpen : null,
          child: ExcludeSemantics(
            child: SizedBox(
              width: width,
              height: width * _height / _width,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: _width,
                    height: _height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // This order is deliberate: both printed glyphs sit
                        // below both photographs, and all type remains above.
                        for (final layer in layers) _glyph(layer),
                        for (final layer in layers) _photo(layer),
                        for (final layer in layers) _note(layer),
                        for (final layer in layers) _caption(layer),
                        for (final layer in layers) _seal(layer),
                        for (final layer in layers) ..._title(layer),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _glyph(_JournalCollageLayer layer) => Positioned(
        left: -.04 * _width,
        top: 205,
        child: _position(
          opacity: layer.enter
              ? _collageInterval(.2, .92, layer.p)
              : 1 - _collageInterval(.05, .7, layer.p),
          x: layer.dir * layer.remaining * 24,
          y: layer.remaining * 10,
          degrees: -12 + layer.dir * layer.remaining * 5,
          origin: const Alignment(0, .4),
          child: Text(
            layer.copy.print,
            textScaler: TextScaler.noScaling,
            style: discoverySerif(
              174,
              weight: FontWeight.w900,
              height: 1,
              color: layer.copy.printColor,
            ),
          ),
        ),
      );

  Widget _photo(_JournalCollageLayer layer) {
    final energy = math.sin(math.pi * layer.p);
    final turn = _collageEase(layer.p);
    final arrival = _collageEase(_collageInterval(.06, .95, layer.p));
    final x = layer.enter
        ? layer.sign * 106 * (1 - arrival)
        : -layer.sign * 64 * turn;
    final y = (layer.enter ? -35 : 28) * energy;
    final angle = layer.sign * (layer.enter ? .045 : -.058) * energy;
    final scale = layer.enter ? .82 + .18 * arrival : 1 - .11 * energy;
    final opacity = layer.enter
        ? _collageInterval(0, .13, layer.p)
        : 1 - _collageInterval(.56, .97, layer.p);
    final matrix = Matrix4.identity()
      ..translateByDouble(223 + x, 233 + y, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-223, -233, 0, 1);
    Widget print = Transform(
      key: ValueKey('journal-photo-${layer.route.id}'),
      transform: matrix,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: layer.enter
              ? _JournalCollageMatPainter(layer.copy.town, 12 * energy, opacity)
              : null,
          child: ClipPath(
            clipper: _JournalCollagePhotoClipper(layer.copy.town),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 56,
                  top: 111,
                  width: 334,
                  height: 244,
                  child: Opacity(
                    opacity: opacity,
                    // Cache the toned photo independently of the animated
                    // opacity and paper mat, which repaint throughout a turn.
                    child: RepaintBoundary(
                      child:
                          _JournalCollagePhoto(source: layer.route.heroImage),
                    ),
                  ),
                ),
                Positioned(
                  left: 56,
                  top: 255,
                  width: 334,
                  height: 100,
                  child: Opacity(
                    opacity: opacity,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0012221a), Color(0x6612221a)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (layer.enter) {
      final open = _collageInterval(.02, .72, layer.p);
      final left = 60 + 330 * (1 - open);
      print = ClipRect(
        clipper: _JournalCollageCropClipper(layer.sign > 0
            ? Rect.fromLTWH(left, 95, 420 - left, 370)
            : Rect.fromLTWH(-30, 95, 90 + 330 * open, 370)),
        child: print,
      );
    }
    return Positioned.fill(child: print);
  }

  Widget _note(_JournalCollageLayer layer) => Positioned(
        left: 23,
        top: 168,
        height: .49 * _height,
        child: _position(
          opacity: layer.enter
              ? _collageInterval(.54, .92, layer.p)
              : 1 - _collageInterval(.02, .37, layer.p),
          y: layer.dir * layer.remaining * 16,
          child: _JournalVerticalNote(text: layer.copy.note),
        ),
      );

  Widget _caption(_JournalCollageLayer layer) => Positioned(
        left: 78,
        top: 316,
        width: .58 * _width,
        child: _position(
          opacity: layer.enter
              ? _collageInterval(.60, .95, layer.p)
              : 1 - _collageInterval(.04, .32, layer.p),
          x: layer.dir * layer.remaining * 12,
          child: Text(
            layer.copy.caption,
            textScaler: TextScaler.noScaling,
            maxLines: 3,
            overflow: TextOverflow.clip,
            style: discoverySans(
              10.998,
              color: const Color(0xfffff8ed),
              height: 1.7,
            ).copyWith(shadows: const [
              Shadow(
                color: Color(0x77000000),
                blurRadius: 5,
                offset: Offset(0, 1),
              ),
            ]),
          ),
        ),
      );

  Widget _seal(_JournalCollageLayer layer) => Positioned(
        right: 21,
        bottom: 0,
        child: _position(
          opacity: layer.enter
              ? _collageInterval(.52, .98, layer.p)
              : 1 - _collageInterval(.1, .47, layer.p),
          x: layer.dir * layer.remaining * 9,
          y: layer.remaining * 13,
          degrees: -7 + layer.dir * layer.remaining * 27,
          scale: .93 + .07 * (1 - layer.remaining),
          origin: Alignment.bottomCenter,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: layer.copy.sealColor,
              border: Border.all(color: AppColors.paper, width: 4.992),
            ),
            child: const Center(
              child: DiscoveryIcon(
                DiscoveryMark.arrowUpRight,
                size: 27,
                stroke: 1.4,
                color: Color(0xff3c4329),
              ),
            ),
          ),
        ),
      );

  List<Widget> _title(_JournalCollageLayer layer) {
    const fontSize = 60.06;
    const lineHeight = fontSize * 1.17;
    final style = discoverySerif(
      fontSize,
      weight: FontWeight.w700,
      height: 1.17,
      spacing: -4.017,
      color: layer.copy.color == AppColors.terracotta
          ? const Color(0xffcf4630)
          : layer.copy.color,
    );
    return List.generate(2, (line) {
      final first = line == 0;
      final alpha = layer.enter
          ? _collageInterval(first ? .32 : .47, first ? .8 : .98, layer.p)
          : 1 - _collageInterval(first ? 0 : .08, first ? .37 : .48, layer.p);
      final travel = layer.enter
          ? 1 - _collageEase(_collageInterval(first ? .22 : .36, 1, layer.p))
          : _collageEase(_collageInterval(first ? 0 : .08, .64, layer.p));
      final text = first ? layer.copy.first : layer.copy.second;
      return Positioned(
        left: .059 * _width + (first ? 0 : 40),
        top: 2 + line * lineHeight,
        // Let the second line keep its natural width. Measuring both titles
        // with new TextPainters each frame duplicated Flutter's text layout.
        width: first ? .95 * _width : null,
        height: lineHeight + (first ? 0 : 1.95),
        child: _position(
          transformKey: ValueKey('journal-title-${layer.route.id}-$line'),
          opacity: alpha,
          x: layer.dir * travel * (first ? 24 : 42),
          y: (layer.enter ? 1 : -1) * travel * (first ? 33 : 24),
          degrees: layer.dir * travel * (first ? .8 : 1.1),
          origin: Alignment.centerLeft,
          child: ClipRect(
            clipper: _JournalCollageTypeClipper(alpha, layer.enter),
            child: DecoratedBox(
              decoration: first
                  ? const BoxDecoration()
                  : const BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(23.01),
                      ),
                    ),
              child: Padding(
                padding: first
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(right: 12.09, bottom: 1.95),
                child: Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _position({
    required double opacity,
    required Widget child,
    Key? transformKey,
    double x = 0,
    double y = 0,
    double degrees = 0,
    double scale = 1,
    Alignment origin = Alignment.center,
  }) =>
      Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          key: transformKey,
          alignment: origin,
          transform: Matrix4.identity()
            ..translateByDouble(x, y, 0, 1)
            ..rotateZ(degrees * math.pi / 180)
            ..scaleByDouble(scale, scale, 1, 1),
          child: child,
        ),
      );
}

class _JournalCollageLayer {
  const _JournalCollageLayer(
      this.route, this.copy, this.enter, this.p, this.sign);
  final RouteExperience route;
  final _JournalCopy copy;
  final bool enter;
  final double p, sign;
  double get remaining => enter ? 1 - p : p;
  double get dir => enter ? sign : -sign;
}

double _collageInterval(double start, double end, double p) =>
    ((p - start) / (end - start)).clamp(0.0, 1.0);
double _collageEase(double p) => p * p * (3 - 2 * p);

Path _journalCollagePhotoPath(bool town) {
  return Path()
    ..addRRect(RRect.fromRectAndCorners(
      const Rect.fromLTWH(56, 111, 334, 244),
      topLeft: Radius.circular(town ? 2 : 105),
      topRight: Radius.circular(town ? 85 : 0),
      bottomRight: Radius.circular(town ? 3 : 39),
      bottomLeft: Radius.circular(town ? 35 : 0),
    ));
}

class _JournalCollagePhotoClipper extends CustomClipper<Path> {
  const _JournalCollagePhotoClipper(this.town);
  final bool town;
  @override
  Path getClip(Size size) => _journalCollagePhotoPath(town);
  @override
  bool shouldReclip(_JournalCollagePhotoClipper oldClipper) =>
      town != oldClipper.town;
}

class _JournalCollageMatPainter extends CustomPainter {
  const _JournalCollageMatPainter(this.town, this.stroke, this.opacity);
  final bool town;
  final double stroke, opacity;
  @override
  void paint(Canvas canvas, Size size) {
    if (stroke <= 0) return;
    final path = _journalCollagePhotoPath(town);
    canvas.drawPath(
        path, Paint()..color = AppColors.paper.withValues(alpha: opacity));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.paper.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_JournalCollageMatPainter oldDelegate) =>
      town != oldDelegate.town ||
      stroke != oldDelegate.stroke ||
      opacity != oldDelegate.opacity;
}

class _JournalCollageCropClipper extends CustomClipper<Rect> {
  const _JournalCollageCropClipper(this.rect);
  final Rect rect;
  @override
  Rect getClip(Size size) => rect;
  @override
  bool shouldReclip(_JournalCollageCropClipper oldClipper) =>
      rect != oldClipper.rect;
}

class _JournalCollageTypeClipper extends CustomClipper<Rect> {
  const _JournalCollageTypeClipper(this.alpha, this.enter);
  final double alpha;
  final bool enter;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
        0,
        enter ? size.height * (1 - alpha) : 0,
        size.width,
        size.height * alpha,
      );
  @override
  bool shouldReclip(_JournalCollageTypeClipper oldClipper) =>
      alpha != oldClipper.alpha || enter != oldClipper.enter;
}

class _JournalCollagePhoto extends StatelessWidget {
  const _JournalCollagePhoto({required this.source});
  final String source;
  @override
  Widget build(BuildContext context) => source.isEmpty
      ? _fallback()
      : Image.network(
          source,
          frameBuilder: (_, child, frame, __) => frame == null
              ? child
              : ColorFiltered(
                  colorFilter: discoveryPhotoTone(.8), child: child),
          width: 370,
          height: 320,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (_, child, loading) => loading == null
              ? child
              : const ColoredBox(color: Color(0xffe4e4d8)),
        );

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

/// Vertical CJK notes have a 10 px glyph and .22 em tracking. A line break per
/// character would use horizontal line-height as advance and stretch the note.
class _JournalVerticalNote extends StatelessWidget {
  const _JournalVerticalNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    const fontSize = 9.984;
    const advance = fontSize * 1.22;
    const columnHeight = 370 * .49;
    const capacity = 14;
    final characters = text.runes.map(String.fromCharCode).toList();
    final columns = <Widget>[];
    for (var start = 0; start < characters.length; start += capacity) {
      columns.add(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final character in characters.skip(start).take(capacity))
            SizedBox(
              width: fontSize * 1.6,
              height: advance,
              child: Center(
                child: Text(
                  switch (character) {
                    '，' => '︐',
                    '。' => '︒',
                    '、' => '︑',
                    '：' => '︓',
                    '；' => '︔',
                    '！' => '︕',
                    '？' => '︖',
                    _ => character,
                  },
                  textScaler: TextScaler.noScaling,
                  style: discoverySans(
                    fontSize,
                    height: 1,
                    color: const Color(0xff887962),
                  ),
                ),
              ),
            ),
        ],
      ));
    }
    return SizedBox(
      height: columnHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: columns,
      ),
    );
  }
}
