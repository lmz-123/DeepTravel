part of 'discovery_page.dart';

const _distanceRed = Color(0xFFBC4432);
const _distanceMuted = Color(0xFF76796C);
const _distanceRule = Color(0x2F252824);

TextStyle _companionSans(
  double size, {
  Color color = const Color(0xFF77796E),
  FontWeight weight = FontWeight.w400,
  double height = 1.6,
  double spacing = 0,
}) =>
    TextStyle(
      fontFamily: 'Noto Sans SC',
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
    );

class _CompanionDistancePanel extends ConsumerStatefulWidget {
  const _CompanionDistancePanel({
    required this.route,
    required this.activeTour,
    required this.signalActive,
    required this.horizontal,
    this.onStart,
    this.onStop,
    this.starting = false,
  });

  final RouteExperience route;
  final ActiveTourState activeTour;
  final bool signalActive;
  final double horizontal;
  final VoidCallback? onStart, onStop;
  final bool starting;

  @override
  ConsumerState<_CompanionDistancePanel> createState() =>
      _CompanionDistancePanelState();
}

class _CompanionDistancePanelState
    extends ConsumerState<_CompanionDistancePanel> {
  bool _opening = false;
  bool _highlighted = false;

  Future<void> _choosePoint() async {
    if (_opening) return;
    final slug = widget.route.slug;
    final account = ref.read(currentUserIdProvider);
    final sessionId = widget.activeTour.session?.id;
    final initial = ref.read(companionDistanceControllerProvider(slug));
    if (initial.points.isEmpty) return;
    _opening = true;
    try {
      final title = widget.route.title;
      final choice = await Navigator.of(context, rootNavigator: true).push(
        _CompanionPointRoute(
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
          builder: (_) => Consumer(builder: (context, ref, _) {
            final distance =
                ref.watch(companionDistanceControllerProvider(slug));
            return CompanionPointPicker(
              routeTitle: title,
              points: distance.points,
              targetId: distance.target?.fragment.id,
              automatic: distance.mode == CompanionDistanceMode.automatic,
              hasLocation: distance.hasLocation,
            );
          }),
        ),
      );
      if (choice == null ||
          !mounted ||
          widget.route.slug != slug ||
          ref.read(currentUserIdProvider) != account ||
          widget.activeTour.session?.id != sessionId) {
        return;
      }
      final controller =
          ref.read(companionDistanceControllerProvider(slug).notifier);
      if (choice.fragmentId == null) {
        controller.useAutomatic();
        _notice('已恢复自动发现');
      } else {
        final point = ref
            .read(companionDistanceControllerProvider(slug))
            .points
            .where((point) => point.fragment.id == choice.fragmentId)
            .firstOrNull;
        if (point == null) return;
        controller.selectPoint(point.fragment.id);
        _notice('已关注${point.fragment.publicPlaceName} · '
            '${widget.activeTour.isPlaying ? '当前讲述继续播放' : '继续随行'}');
      }
    } finally {
      _opening = false;
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message,
            style: _companionSans(11, color: AppColors.paper)
                .copyWith(fontFamily: 'Noto Sans SC')),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        margin:
            EdgeInsets.fromLTRB(widget.horizontal, 0, widget.horizontal, 94),
        duration: const Duration(milliseconds: 2200),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = companionDistanceControllerProvider(widget.route.slug);
    final distance = ref.watch(provider);
    final manual = distance.mode == CompanionDistanceMode.manual;
    final point = distance.target;
    final narrow = MediaQuery.sizeOf(context).width <= 375;
    final canChoose = distance.points.isNotEmpty;
    final heading = point?.fragment.publicPlaceName ??
        (distance.isLoading
            ? '正在载入地点'
            : distance.error != null
                ? '地点暂未载入'
                : distance.points.isEmpty
                    ? '等待沿途地点'
                    : '等待位置');
    final modeLabel = manual
        ? '手动选定'
        : distance.allExplored
            ? '自动发现 · 附近地点'
            : '自动发现 · 最近未探索';
    final note = !widget.signalActive
        ? ''
        : distance.isPaused
            ? '随行暂停 · 距离暂不更新'
            : !distance.hasLocation
                ? widget.activeTour.locationMode == TourLocationMode.simulated
                    ? '模拟预览 · 实地行走时显示距离'
                    : distance.locationIssue == '定位精度不足'
                        ? '定位精度不足 · 点右上角重新定位'
                        : '定位恢复后更新距离'
                : manual
                    ? ''
                    : distance.isApproximate
                        ? '位置仍在校准 · 仅供估算'
                        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CompanionSignalWidget(
          active: widget.signalActive,
          state: widget.activeTour,
          horizontal: widget.horizontal,
          distance: distance,
          onStart: widget.onStart,
          onStop: widget.onStop,
          starting: widget.starting,
          onRetry: widget.signalActive &&
                  !distance.isPaused &&
                  !distance.hasLocation &&
                  widget.activeTour.locationMode == TourLocationMode.real
              ? () => ref
                  .read(activeTourControllerProvider.notifier)
                  .retryLocation()
              : null,
        ),
        Semantics(
          button: true,
          enabled: canChoose || distance.error != null,
          label: '$modeLabel，${point == null ? '' : '距'}$heading，'
              '${_distanceDescription(point?.distanceMeters)}，换一处地点',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('companion-distance-target'),
              onTap: canChoose
                  ? _choosePoint
                  : distance.error != null
                      ? () => ref.invalidate(
                          offlineAwareRouteProvider(widget.route.slug))
                      : null,
              splashFactory: NoSplash.splashFactory,
              onHover: (value) => setState(() => _highlighted = value),
              onHighlightChanged: (value) =>
                  setState(() => _highlighted = value),
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 97),
                  padding: const EdgeInsets.only(top: 17, bottom: 15),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _distanceRule))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      '${widget.route.title} · ${widget.signalActive ? '正在随行' : '本次随行'}',
                                      key: const ValueKey(
                                          'companion-selected-route'),
                                      style: _companionSans(10,
                                          color: _distanceMuted))),
                              Text(modeLabel,
                                  style: _companionSans(9,
                                      color: _distanceMuted, spacing: .7))
                            ]),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(point == null ? '·' : '距',
                                    style: _companionSans(12,
                                        color: _distanceMuted)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(heading,
                                      key: const ValueKey(
                                          'companion-distance-place'),
                                      style: discoverySerif(narrow ? 25 : 27,
                                          height: 1.45, spacing: -.9)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _DistanceChangeMark(
                        label: distance.error != null && !canChoose
                            ? '重新载入'
                            : '换一处',
                        enabled: canChoose || distance.error != null,
                        highlighted: _highlighted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (note.isNotEmpty || manual)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: manual ? 44 : 39),
            child: Row(
              children: [
                Expanded(
                    child: Text(note,
                        style: _companionSans(10, color: _distanceMuted))),
                if (manual) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    key: const ValueKey('companion-distance-automatic'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      foregroundColor: _distanceRed,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      ref.read(provider.notifier).useAutomatic();
                      _notice('已恢复自动发现');
                    },
                    child: Text('恢复自动发现 ↗',
                        style: _companionSans(11, color: _distanceRed)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The paper index rises a small distance and fades in, as in the approved
/// design. A full-height Material sheet slide would change the visual rhythm.
class _CompanionPointRoute extends PopupRoute<CompanionPointChoice> {
  _CompanionPointRoute({
    required this.builder,
    required this.reducedMotion,
    required this.label,
  });
  final WidgetBuilder builder;
  final bool reducedMotion;
  final String label;

  @override
  bool get barrierDismissible => true;
  @override
  Color get barrierColor => const Color(0x60252824);
  @override
  String get barrierLabel => label;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reducedMotion ? 0 : 360);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reducedMotion ? 0 : 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final top = math.max(
        screen.width <= 375 ? 44.0 : 57.0, MediaQuery.paddingOf(context).top);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          height: screen.height - top,
          decoration: const BoxDecoration(
            color: AppColors.paper,
            border: Border(top: BorderSide(color: Color(0x77252824))),
            boxShadow: [
              BoxShadow(
                offset: Offset(0, -15),
                blurRadius: 50,
                color: Color(0x25252824),
              )
            ],
          ),
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (reducedMotion) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = const Cubic(.2, .8, .2, 1).transform(animation.value);
        return Opacity(
          opacity: .2 + .8 * progress,
          child: Transform.translate(
              offset: Offset(0, 38 * (1 - progress)), child: child),
        );
      },
    );
  }
}

String _distanceDescription(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) return '等待定位';
  return meters < 1000
      ? '约${meters.round()}米'
      : '约${(meters / 1000).toStringAsFixed(1)}公里';
}

class _DistanceChangeMark extends StatelessWidget {
  const _DistanceChangeMark(
      {required this.label, required this.enabled, required this.highlighted});
  final String label;
  final bool enabled;
  final bool highlighted;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: CustomPaint(
          painter: const _DistanceUnderline(),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: discoverySerif(13,
                    color: enabled ? _distanceRed : _distanceMuted)),
            const SizedBox(width: 8),
            TweenAnimationBuilder<Offset>(
              tween: Tween(
                  begin: Offset.zero,
                  end: highlighted ? const Offset(2, -2) : Offset.zero),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.ease,
              builder: (_, offset, child) =>
                  Transform.translate(offset: offset, child: child),
              child: DiscoveryIcon(DiscoveryMark.arrowUpRight,
                  size: 18,
                  stroke: 1.4,
                  color: enabled ? _distanceRed : _distanceMuted),
            ),
          ]),
        ),
      );
}

class _CompanionHeader extends StatelessWidget {
  const _CompanionHeader({this.city});
  final String? city;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width <= 375 ? 20 : 23),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            DiscoveryBrand(title: '随行', onTap: () => context.push('/profile')),
            if (city != null)
              Text(city!, style: _companionSans(11, color: _distanceMuted)),
          ]),
        ),
      );
}

class _CompanionListeningStrip extends StatelessWidget {
  const _CompanionListeningStrip({required this.state, required this.onPause});
  final ActiveTourState state;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('companion-current-listening'),
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: _distanceRule),
                bottom: BorderSide(color: _distanceRule))),
        child: Row(children: [
          SizedBox.square(
              dimension: 34,
              child: CustomPaint(painter: _DistanceRecordPainter())),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('正在听 · ${state.current?.publicPlaceName ?? '这一段城市'}',
                    style: _companionSans(11, color: AppColors.ink)),
              ])),
          Tooltip(
              message: '暂停讲述',
              child: DiscoveryTouch(
                key: const ValueKey('companion-primary'),
                label: '暂停讲述',
                onTap: onPause,
                child: const SizedBox.square(
                    dimension: 44,
                    child: Center(
                        child: DiscoveryIcon(DiscoveryMark.pause,
                            size: 18, stroke: 1.4))),
              )),
        ]),
      );
}

class _DistanceRecordPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width / 2, Paint()..color = AppColors.ink);
    final pen = Paint()
      ..color = const Color(0xFF626256)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    for (double radius = 7; radius < size.width / 2; radius += 3) {
      canvas.drawCircle(center, radius, pen);
    }
    canvas.drawCircle(center, 4.5, Paint()..color = AppColors.paper);
    canvas.drawCircle(center, 1.5, Paint()..color = _distanceRed);
  }

  @override
  bool shouldRepaint(_DistanceRecordPainter oldDelegate) => false;
}

class _DistanceUnderline extends CustomPainter {
  const _DistanceUnderline();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(-3, size.height - 9)
        ..quadraticBezierTo(size.width * .5, size.height - 14, size.width + 3,
            size.height - 12),
      Paint()
        ..color = const Color(0xA0BC4432)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DistanceUnderline oldDelegate) => false;
}
