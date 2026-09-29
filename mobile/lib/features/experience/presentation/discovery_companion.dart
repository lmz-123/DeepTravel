part of 'discovery_page.dart';

/// The location experience has its own first-class destination. It explains
/// the mode before asking for permission; entering this tab never starts GPS or
/// audio by itself.
class _DiscoveryCompanion extends ConsumerWidget {
  const _DiscoveryCompanion({
    required this.state,
    required this.activeTour,
    required this.onOpen,
    required this.selectedRouteId,
    required this.onSelectRoute,
    required this.onStart,
  });

  final DiscoveryState state;
  final ActiveTourState activeTour;
  final ValueChanged<RouteExperience> onOpen;
  final String? selectedRouteId;
  final ValueChanged<RouteExperience> onSelectRoute;
  final ValueChanged<RouteExperience> onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Modern routes expose their playable nodes as audio-tour fragments and
    // may have no legacy `stops` at all. Keep both content contracts visible
    // here so the companion tab does not look empty after publishing a route
    // through the current admin flow.
    final routes = state.catalog.routes
        .where(
          (route) =>
              route.stops.isNotEmpty ||
              (route.audioTour?.fragments.isNotEmpty ?? false),
        )
        .take(4)
        .toList(growable: false);
    final selected = activeTour.route;
    final horizontal = MediaQuery.sizeOf(context).width <= 360 ? 20.0 : 23.0;
    final running = _companionRunning(activeTour);
    final selectedRoute = running && selected != null
        ? selected
        : routes.where((route) => route.id == selectedRouteId).firstOrNull ??
            (routes.isEmpty ? null : routes.first);
    return CustomScrollView(
      key: const PageStorageKey('companion-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: const _DiscoveryHeader(),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 150),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CompanionFolio(),
                const SizedBox(height: 22),
                Text('把屏幕退到身后', style: discoverySans(10, color: AppColors.textMuted, spacing: 1.1)),
                const SizedBox(height: 10),
                const _CompanionTitle(),
                const SizedBox(height: 14),
                Text(
                  '你走近一处，城市才打开一段。\n每一次播放，都由你决定。',
                  style: discoverySans(12, height: 1.9, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                _CompanionSignalWidget(
                  active: running,
                  state: activeTour,
                  horizontal: horizontal,
                ),
                _CompanionStateSection(
                  state: activeTour,
                  selected: selectedRoute,
                  onStart: () {
                    if (selectedRoute != null) onStart(selectedRoute);
                  },
                  onPause: () => ref.read(activeTourControllerProvider.notifier).pauseTour(),
                  onResume: () => ref.read(activeTourControllerProvider.notifier).resumeTour(),
                  onTogglePlayback: () => ref.read(activeTourControllerProvider.notifier).togglePlayback(),
                  onStop: () => ref.read(activeTourControllerProvider.notifier).stopTour(),
                  onDemo: () => ref.read(activeTourControllerProvider.notifier).triggerNextDemo(),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('01 / CHOOSE A WALK', style: discoverySans(9, color: AppColors.textMuted, spacing: 1.1)),
                    Text('${routes.length.toString().padLeft(2, '0')} 条可随行', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 11),
                Text('先选一条，\n再让城市靠近。', style: discoverySerif(28, height: 1.45, spacing: -1.7)),
                const SizedBox(height: 18),
                if (routes.isEmpty)
                  Text('当前城市还没有可随行的路线。', style: discoverySerif(22))
                else
                  ...routes.asMap().entries.map((entry) => _CompanionRouteTile(
                        index: entry.key,
                        route: entry.value,
                        city: state.city?.name ?? entry.value.cityName,
                        selected: selectedRoute?.id == entry.value.id,
                        enabled: !running,
                        onSelect: onSelectRoute,
                      )),
                if (selectedRoute != null) ...[
                  const SizedBox(height: 2),
                  DiscoveryTouch(
                    label: '查看${selectedRoute.title}的路线目录',
                    onTap: () => onOpen(selectedRoute),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 53),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.terracotta))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('先看看这条路线的目录', style: discoverySerif(14, color: AppColors.terracotta)),
                          const DiscoveryIcon(DiscoveryMark.arrowUpRight, color: AppColors.terracotta, size: 17),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 27),
                const _CompanionNote(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompanionFolio extends StatelessWidget {
  const _CompanionFolio();

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '随行',
                    style: discoverySans(10, color: AppColors.textMuted, spacing: .7),
                  ),
                  TextSpan(
                    text: '  ·  SOUND WALK',
                    style: discoverySans(10, color: const Color(0xff8d7b67), spacing: .7),
                  ),
                ],
              ),
            ),
            const Text(
              '03',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: AppColors.terracotta,
              ),
            ),
          ],
        ),
      );
}

class _CompanionTitle extends StatelessWidget {
  const _CompanionTitle();

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('让位置，', style: discoverySerif(47, height: 1.27, spacing: -2.4)),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: -6,
                    bottom: 2,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: -.035,
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '替你翻页。',
                    style: discoverySerif(47, height: 1.27, spacing: -2.4, color: AppColors.terracotta),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 4,
            top: -4,
            child: Transform.rotate(
              angle: .14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.terracotta.withValues(alpha: .5)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'LISTEN\nWHEN YOU ARRIVE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 9,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                    color: Color(0xffa06b57),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

bool _companionRunning(ActiveTourState state) => state.session != null &&
    state.status != 'idle' && state.status != 'stopped';

enum _CompanionPhase { idle, preparing, monitoring, nearby, playing, paused }

_CompanionPhase _companionPhase(ActiveTourState state) {
  if (!_companionRunning(state)) return _CompanionPhase.idle;
  if (state.isBusy || state.status == 'preparing') return _CompanionPhase.preparing;
  if (state.status == 'paused') return _CompanionPhase.paused;
  final nearby = state.nearbyStoryPoints.any((point) {
    final status = point.status.name;
    return status == 'approaching' || status == 'inRange' || status == 'triggered' || status == 'heard';
  });
  if (state.isPlaying) return _CompanionPhase.playing;
  if (nearby && state.current != null) return _CompanionPhase.nearby;
  return _CompanionPhase.monitoring;
}

class _CompanionStateSection extends StatelessWidget {
  const _CompanionStateSection({required this.state, required this.selected, required this.onStart, required this.onPause, required this.onResume, required this.onTogglePlayback, required this.onStop, required this.onDemo});
  final ActiveTourState state;
  final RouteExperience? selected;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onTogglePlayback;
  final VoidCallback onStop;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final phase = _companionPhase(state);
    final copy = switch (phase) {
      _CompanionPhase.idle => ('READY WHEN YOU ARE', '选择一条路线，\n让位置替你翻页。', '进入随行不会请求定位。准备好了，再由你开启这一段城市声音。'),
      _CompanionPhase.preparing => ('PREPARING THE WALK', '正在准备\n沿途讲述。', '把声音和文字留在手机里，走到现场也能从容继续。'),
      _CompanionPhase.monitoring => state.status == 'permission_limited'
          ? ('LOCATION NEEDS PERMISSION', '让位置，\n找到你。', '定位许可尚未打开。允许后，靠近线索时会先提醒你，声音不会突然闯进来。')
          : ('LISTENING FOR THE CITY', '沿着城市，\n慢慢走。', '定位正常。靠近线索时会先提醒你，声音不会突然闯进来。'),
      _CompanionPhase.nearby => ('A STORY IS NEAR', '附近有一段\n声音。', state.locationMessage ?? '靠近故事点时，准备好了就点击播放。'),
      _CompanionPhase.playing => ('NOW PLAYING', state.current?.title ?? '这一段城市，\n正在被听见。', '正在讲述。你可以随时暂停，回到眼前。'),
      _CompanionPhase.paused => ('THE WALK IS PAUSED', '先把这一页，\n留在这里。', '随行已暂停。线索和进度都在，回来时继续寻找。'),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 25, 0, 28),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(copy.$1, style: discoverySans(9, color: AppColors.textMuted, spacing: 1.1)),
        const SizedBox(height: 11),
        Text(copy.$2, style: discoverySerif(29, height: 1.42, spacing: -1.7)),
        const SizedBox(height: 10),
        Text(copy.$3, style: discoverySans(11, height: 1.8, color: AppColors.textMuted)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _CompanionPrimaryButton(phase: phase, retryLocation: state.status == 'permission_limited', enabled: phase != _CompanionPhase.preparing && (phase != _CompanionPhase.idle || selected != null), onStart: onStart, onPause: onPause, onResume: onResume, onTogglePlayback: onTogglePlayback),
          if (phase == _CompanionPhase.monitoring && state.locationMode == TourLocationMode.simulated) _CompanionTextButton(icon: DiscoveryMark.pin, label: '模拟靠近一处线索', onTap: onDemo),
          if (phase == _CompanionPhase.nearby) _CompanionTextButton(icon: DiscoveryMark.arrowLeft, label: '继续寻找', onTap: onResume),
          if (phase != _CompanionPhase.idle && phase != _CompanionPhase.preparing) _CompanionTextButton(icon: DiscoveryMark.check, label: '结束本次随行', onTap: onStop, muted: true),
        ]),
      ]),
    );
  }
}

class _CompanionPrimaryButton extends StatelessWidget {
  const _CompanionPrimaryButton({required this.phase, required this.retryLocation, required this.enabled, required this.onStart, required this.onPause, required this.onResume, required this.onTogglePlayback});
  final _CompanionPhase phase;
  final bool retryLocation;
  final bool enabled;
  final VoidCallback onStart, onPause, onResume, onTogglePlayback;
  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      _CompanionPhase.idle => '开启随行',
      _CompanionPhase.preparing => '准备中…',
      _CompanionPhase.monitoring => retryLocation ? '重新开启定位' : '暂停随行',
      _CompanionPhase.nearby => '播放这一段',
      _CompanionPhase.playing => '暂停讲述',
      _CompanionPhase.paused => '继续寻找',
    };
    final icon = phase == _CompanionPhase.idle
        ? DiscoveryMark.pin
        : (phase == _CompanionPhase.nearby || phase == _CompanionPhase.paused)
            ? DiscoveryMark.bookmark
            : DiscoveryMark.check;
    return DiscoveryTouch(
      label: label,
      onTap: enabled ? () {
        switch (phase) {
          case _CompanionPhase.idle:
            onStart();
            break;
          case _CompanionPhase.monitoring:
            if (retryLocation) {
              onResume();
            } else {
              onPause();
            }
            break;
          case _CompanionPhase.nearby:
            onTogglePlayback();
            break;
          case _CompanionPhase.playing:
            onTogglePlayback();
            break;
          case _CompanionPhase.paused:
            onResume();
            break;
          case _CompanionPhase.preparing:
            break;
        }
      } : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 51, minWidth: 205),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: enabled ? 1 : .55), borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(18), bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [DiscoveryIcon(icon, size: 17, color: AppColors.paper), const SizedBox(width: 8), Text(label, style: discoverySans(12, color: AppColors.paper))]),
          const DiscoveryIcon(DiscoveryMark.arrowRight, size: 18, color: AppColors.paper),
        ]),
      ),
    );
  }
}

class _CompanionTextButton extends StatelessWidget {
  const _CompanionTextButton({required this.icon, required this.label, required this.onTap, this.muted = false});
  final DiscoveryMark icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(label: label, onTap: onTap, child: Container(constraints: const BoxConstraints(minHeight: 44), padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [DiscoveryIcon(icon, size: 15, color: muted ? AppColors.textMuted : AppColors.terracotta), const SizedBox(width: 5), Text(label, style: discoverySans(10, color: muted ? AppColors.textMuted : AppColors.terracotta))])));
}

class _CompanionNote extends StatelessWidget {
  const _CompanionNote();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), color: AppColors.lime.withValues(alpha: .48), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const DiscoveryIcon(DiscoveryMark.headphones, size: 15, color: AppColors.moss), const SizedBox(width: 10), Expanded(child: Text.rich(TextSpan(children: [TextSpan(text: '声音不会突然播放。\n', style: discoverySans(10, color: AppColors.moss, weight: FontWeight.w600, height: 1.75)), TextSpan(text: '默认先提醒你，再由你点击播放。', style: discoverySans(10, color: AppColors.moss, height: 1.75))])))]));
}

/// A full-bleed field signal matching the editorial companion page. It
/// communicates whether the companion is actually receiving a usable position
/// without inventing a distance.
class _CompanionSignalWidget extends StatefulWidget {
  const _CompanionSignalWidget({required this.active, required this.state, required this.horizontal});

  final bool active;
  final ActiveTourState state;
  final double horizontal;

  @override
  State<_CompanionSignalWidget> createState() => _CompanionSignalWidgetState();
}

class _CompanionSignalWidgetState extends State<_CompanionSignalWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  ActiveTourState get state => widget.state;
  bool get active => widget.active;

  NearbyStoryPoint? get _nearest => state.nearbyStoryPoints.firstOrNull;

  bool get _hasFreshPosition =>
      state.locationMode == TourLocationMode.real &&
      state.latestLocationSample != null;

  bool get _hasNearbyStory {
    final status = _nearest?.status.name;
    return status == 'approaching' ||
        status == 'inRange' ||
        status == 'triggered' ||
        status == 'heard';
  }

  String get _distance {
    // Simulated mode has no physical position. A null or unavailable sample
    // must stay visibly unknown instead of looking like a measured distance.
    if (!_hasFreshPosition) return '—';
    final value = _nearest?.distanceMeters;
    if (value == null || !value.isFinite) return '—';
    if (value < 1000) return '${value.round()} m';
    return '${(value / 1000).toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _hasFreshPosition ||
        (active && state.locationMode == TourLocationMode.simulated);
    final nearby = _hasNearbyStory;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) => Container(
        height: 192,
        margin: EdgeInsets.symmetric(horizontal: -widget.horizontal),
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffe9edcf), AppColors.paper],
            stops: [0, .6],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CompanionSignalPainter(
                  active: active,
                  connected: connected,
                  nearby: nearby,
                  breath: _breath.value,
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -.12,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: .91),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.terracotta),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_distance, style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontStyle: FontStyle.italic, color: AppColors.terracotta)),
                    const SizedBox(height: 2),
                    Text(active ? (_hasFreshPosition ? '距离' : '等待定位') : '等你开启', style: discoverySans(9, color: AppColors.textMuted)),
                  ]),
                ),
              ),
            ),
            Positioned(
              right: widget.horizontal,
              top: 20,
              child: Row(children: [
                const DiscoveryIcon(DiscoveryMark.pin, size: 14, color: AppColors.moss),
                const SizedBox(width: 5),
                Text(
                  active && state.locationMode == TourLocationMode.simulated
                      ? '模拟定位'
                      : active && connected
                          ? '定位正常'
                          : '尚未定位',
                  style: discoverySans(9, color: AppColors.moss),
                ),
              ]),
            ),
            Positioned(left: widget.horizontal, bottom: 18, child: Text(nearby ? 'NEARBY STORY' : 'YOUR NEXT LISTEN', style: discoverySans(8, color: AppColors.textMuted, spacing: 1.1))),
          ],
        ),
      ),
    );
  }
}

class _CompanionSignalPainter extends CustomPainter {
  const _CompanionSignalPainter({required this.active, required this.connected, required this.nearby, required this.breath});

  final bool active;
  final bool connected;
  final bool nearby;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = active ? breath : 0.0;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xffc6cf9b).withValues(alpha: .5);
    canvas.drawOval(Rect.fromCenter(center: center, width: 245, height: 245), ring);
    final back = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (nearby ? AppColors.moss : AppColors.terracotta).withValues(alpha: active ? .55 + pulse * .3 : .48);
    final backScale = active ? (.96 + pulse * .1) : 1.0;
    final backRect = Rect.fromCenter(
      center: center,
      width: (active ? 178 : 145) * backScale,
      height: (active ? 125 : 102) * backScale,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(.33);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(backRect, back);
    canvas.restore();
    final front = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.terracotta.withValues(alpha: nearby ? .7 : active ? .3 : .28);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.40);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(Rect.fromCenter(center: center, width: nearby ? 133 : 106, height: nearby ? 170 : 145), front);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompanionSignalPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.connected != connected || oldDelegate.nearby != nearby || oldDelegate.breath != breath;
}

class _CompanionRouteTile extends StatelessWidget {
  const _CompanionRouteTile({required this.index, required this.route, required this.city, required this.selected, required this.enabled, required this.onSelect});
  final int index;
  final RouteExperience route;
  final String city;
  final bool selected;
  final bool enabled;
  final ValueChanged<RouteExperience> onSelect;

  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        label: '选择${route.title}开启随行',
        onTap: enabled ? () => onSelect(route) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 85),
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xffe6eacb).withValues(alpha: .42) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('${index + 1}'.padLeft(2, '0'), style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: Color(0xffa9957e)))),
              const SizedBox(width: 10),
              SizedBox(
                width: 51,
                height: 58,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(index.isEven ? 29 : 3),
                    topRight: Radius.circular(index.isOdd ? 29 : 3),
                    bottomLeft: const Radius.circular(3),
                    bottomRight: const Radius.circular(3),
                  ),
                  child: route.heroImage.isEmpty
                      ? Container(color: AppColors.lime, child: const Center(child: DiscoveryIcon(DiscoveryMark.headphones, size: 18, color: AppColors.moss)))
                      : Image.network(route.heroImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.lime, child: const Center(child: DiscoveryIcon(DiscoveryMark.headphones, size: 18, color: AppColors.moss)))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$city / ${route.theme}', maxLines: 1, overflow: TextOverflow.ellipsis, style: discoverySans(9, color: AppColors.textMuted)),
                  const SizedBox(height: 3),
                  Text(route.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: discoverySerif(16, weight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(route.audioTour != null ? '声音导览 · ${route.numberOfStops} 段线索' : '现场文字 · 可随行阅读', maxLines: 1, overflow: TextOverflow.ellipsis, style: discoverySans(9, color: AppColors.textMuted)),
                ]),
              ),
              DiscoveryIcon(selected ? DiscoveryMark.pin : DiscoveryMark.arrowUpRight, color: selected ? AppColors.terracotta : AppColors.textMuted, size: 17),
            ],
          ),
        ),
      );
}
