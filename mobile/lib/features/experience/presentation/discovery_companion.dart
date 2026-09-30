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
    required this.requestedRoute,
    required this.onRetryRequestedRoute,
    required this.onSelectRoute,
    required this.onStart,
    required this.starting,
  });

  final DiscoveryState state;
  final ActiveTourState activeTour;
  final ValueChanged<RouteExperience> onOpen;
  final String? selectedRouteId;
  final AsyncValue<RouteExperience>? requestedRoute;
  final VoidCallback onRetryRequestedRoute;
  final ValueChanged<RouteExperience> onSelectRoute;
  final ValueChanged<RouteExperience> onStart;
  final bool starting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handoff = requestedRoute?.asData?.value;
    final routes = <String, RouteExperience>{
      for (final route in state.catalog.routes)
        if (_supportsCompanion(route)) route.id: route,
      if (handoff != null && _supportsCompanion(handoff)) handoff.id: handoff,
    }.values.toList(growable: false);
    final selected = activeTour.route;
    final horizontal = MediaQuery.sizeOf(context).width <= 360 ? 20.0 : 23.0;
    final running = _companionRunning(activeTour);
    final signalActive =
        running && _companionPhase(activeTour) != _CompanionPhase.preparing;
    final selectedRoute = running && selected != null
        ? selected
        : selectedRouteId != null
            ? routes.where((route) => route.id == selectedRouteId).firstOrNull
            : requestedRoute != null
                ? handoff
                : routes.firstOrNull;
    final orderedRoutes = <RouteExperience>[
      if (selectedRoute != null && _supportsCompanion(selectedRoute))
        selectedRoute,
      ...routes.where((route) => route.id != selectedRoute?.id),
    ];
    final visibleRoutes =
        orderedRoutes.length > 4 ? orderedRoutes.sublist(0, 4) : orderedRoutes;
    final awaitingRequestedRoute =
        requestedRoute != null && selectedRouteId == null && !running;
    return CustomScrollView(
      key: const PageStorageKey('companion-screen'),
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
                Text('把屏幕退到身后',
                    style: discoverySans(10,
                        color: AppColors.textMuted, spacing: 1.1)),
                const SizedBox(height: 10),
                const _CompanionTitle(),
                const SizedBox(height: 14),
                Text(
                  '你走近一处，城市才打开一段。\n每一次播放，都由你决定。',
                  style: discoverySans(12,
                      height: 1.9, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                _CompanionSignalWidget(
                  active: signalActive,
                  state: activeTour,
                  horizontal: horizontal,
                ),
                _CompanionStateSection(
                  state: activeTour,
                  selected: selectedRoute,
                  starting: starting,
                  onStart: () {
                    if (selectedRoute != null) onStart(selectedRoute);
                  },
                  onPause: () => ref
                      .read(activeTourControllerProvider.notifier)
                      .pauseTour(),
                  onResume: () => ref
                      .read(activeTourControllerProvider.notifier)
                      .resumeTour(resumeAudio: false),
                  onTogglePlayback: () => ref
                      .read(activeTourControllerProvider.notifier)
                      .togglePlayback(),
                  onStop: () => ref
                      .read(activeTourControllerProvider.notifier)
                      .stopTour(),
                  onDemo: () => ref
                      .read(activeTourControllerProvider.notifier)
                      .triggerNextDemo(autoPlay: false),
                ),
                if (awaitingRequestedRoute && handoff == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: requestedRoute!.hasError
                        ? Row(
                            children: [
                              Expanded(
                                child: Text('这条路线暂时未能载入。',
                                    style: discoverySans(11,
                                        color: AppColors.textMuted)),
                              ),
                              _CompanionTextButton(
                                icon: DiscoveryMark.arrowRight,
                                label: '重新载入',
                                onTap: onRetryRequestedRoute,
                              ),
                            ],
                          )
                        : Text('正在带来你选好的那条路…',
                            style:
                                discoverySans(11, color: AppColors.textMuted)),
                  ),
                if (selectedRoute != null && !_supportsCompanion(selectedRoute))
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Text('这条路线暂未开放定位随行，可以先翻阅目录。',
                        style: discoverySans(11,
                            height: 1.8, color: AppColors.textMuted)),
                  ),
                if (selectedRoute != null && _supportsCompanion(selectedRoute))
                  CompanionWalkSettingsEntry(
                    route: selectedRoute,
                    enabled: !running && !starting,
                  ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('01 / CHOOSE A WALK',
                        style: discoverySans(9,
                            color: AppColors.textMuted, spacing: 1.1)),
                    Text(
                        '${orderedRoutes.length.toString().padLeft(2, '0')} 条可随行',
                        style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 11),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                          text: '先选一条，\n',
                          style:
                              discoverySerif(28, height: 1.45, spacing: -1.7)),
                      TextSpan(
                          text: '再让城市靠近。',
                          style: discoverySerif(28,
                              height: 1.45,
                              spacing: -1.7,
                              color: AppColors.terracotta)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (orderedRoutes.isEmpty)
                  Text('当前城市还没有可随行的路线。', style: discoverySerif(22))
                else
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Column(
                      children: visibleRoutes
                          .asMap()
                          .entries
                          .map(
                            (entry) => _CompanionRouteTile(
                              index: entry.key,
                              route: entry.value,
                              city: entry.value.cityName.isNotEmpty
                                  ? entry.value.cityName
                                  : state.city?.name ?? '',
                              selected: selectedRoute?.id == entry.value.id,
                              enabled: !running && !starting,
                              onSelect: onSelectRoute,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                if (orderedRoutes.length > 4)
                  DiscoveryTouch(
                    key: const ValueKey('companion-all-routes'),
                    label: '选择其他路线，共 ${orderedRoutes.length} 条',
                    onTap: running || starting
                        ? null
                        : () async {
                            final route =
                                await showModalBottomSheet<RouteExperience>(
                              context: context,
                              useRootNavigator: true,
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: AppColors.paper,
                              builder: (_) => _CompanionRoutePicker(
                                routes: orderedRoutes,
                                selectedRouteId: selectedRoute?.id,
                              ),
                            );
                            if (route != null && context.mounted) {
                              onSelectRoute(route);
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('选择其他路线 · 共 ${orderedRoutes.length} 条',
                                style: discoverySans(11,
                                    color: AppColors.terracotta)),
                          ),
                          const DiscoveryIcon(DiscoveryMark.arrowUpRight,
                              color: AppColors.terracotta, size: 17),
                        ],
                      ),
                    ),
                  ),
                if (selectedRoute != null) ...[
                  const SizedBox(height: 2),
                  DiscoveryTouch(
                    label: '查看${selectedRoute.title}的路线目录',
                    onTap: () => onOpen(selectedRoute),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 53),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AppColors.terracotta))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('先看看这条路线的目录',
                              style: discoverySerif(14,
                                  color: AppColors.terracotta)),
                          const DiscoveryIcon(DiscoveryMark.arrowUpRight,
                              color: AppColors.terracotta, size: 17),
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

bool _supportsCompanion(RouteExperience route) =>
    route.audioTour?.fragments.isNotEmpty ?? false;

class _CompanionRoutePicker extends StatefulWidget {
  const _CompanionRoutePicker({
    required this.routes,
    required this.selectedRouteId,
  });

  final List<RouteExperience> routes;
  final String? selectedRouteId;

  @override
  State<_CompanionRoutePicker> createState() => _CompanionRoutePickerState();
}

class _CompanionRoutePickerState extends State<_CompanionRoutePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final routes = widget.routes
        .where((route) => '${route.title}${route.cityName}${route.theme}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList(growable: false);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              23, 16, 23, MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('CHOOSE A WALK',
                        style: discoverySans(9,
                            color: AppColors.textMuted, spacing: 1.1)),
                  ),
                  _DiscoveryIconButton(
                    mark: DiscoveryMark.close,
                    label: '关闭路线选择',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text('把哪条路，\n带在身边。',
                  style: discoverySerif(33, height: 1.35, spacing: -1.5)),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('companion-route-search'),
                onChanged: (value) => setState(() => _query = value.trim()),
                style: discoverySans(13),
                decoration: const InputDecoration(
                  hintText: '搜索路线、城市或主题',
                  border: UnderlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
              const SizedBox(height: 18),
              if (routes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('暂时没有找到这条路，换个词试试。',
                      style: discoverySans(12, color: AppColors.textMuted)),
                ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('companion-route-picker-list'),
                  itemCount: routes.length,
                  itemBuilder: (context, index) => _CompanionRouteTile(
                    index: index,
                    route: routes[index],
                    city: routes[index].cityName,
                    selected: routes[index].id == widget.selectedRouteId,
                    enabled: true,
                    onSelect: (route) => Navigator.pop(context, route),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                    style: discoverySans(10,
                        color: AppColors.textMuted, spacing: .7),
                  ),
                  TextSpan(
                    text: '  ·  SOUND WALK',
                    style: discoverySans(10,
                        color: const Color(0xff8d7b67), spacing: .7),
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
              Text('让位置，',
                  style: discoverySerif(47, height: 1.27, spacing: -2.4)),
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
                    style: discoverySerif(47,
                        height: 1.27,
                        spacing: -2.4,
                        color: AppColors.terracotta),
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
                  border: Border.all(
                      color: AppColors.terracotta.withValues(alpha: .5)),
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

bool _companionRunning(ActiveTourState state) =>
    state.session != null &&
    state.status != 'idle' &&
    state.status != 'stopped';

enum _CompanionPhase { idle, preparing, monitoring, nearby, playing, paused }

_CompanionPhase _companionPhase(ActiveTourState state) {
  if (!_companionRunning(state)) return _CompanionPhase.idle;
  if (state.isBusy || state.status == 'preparing') {
    return _CompanionPhase.preparing;
  }
  if (state.status == 'paused') return _CompanionPhase.paused;
  final nearby = _companionHasNearbyStory(state);
  if (state.isPlaying) return _CompanionPhase.playing;
  if (nearby && state.current != null) return _CompanionPhase.nearby;
  return _CompanionPhase.monitoring;
}

bool _companionHasNearbyStory(ActiveTourState state) {
  final currentId = state.current?.id;
  if (currentId == null) return false;
  final point = state.nearbyStoryPoints
      .where((item) => item.fragment.id == currentId)
      .firstOrNull;
  if (point == null || state.current?.id != point.fragment.id) return false;
  final status = point.status.name;
  if (status == 'triggered' &&
      state.locationMode == TourLocationMode.real &&
      state.latestLocationSample == null) {
    return false;
  }
  return status == 'approaching' ||
      status == 'inRange' ||
      status == 'triggered';
}

class _CompanionStateSection extends StatelessWidget {
  const _CompanionStateSection(
      {required this.state,
      required this.selected,
      required this.starting,
      required this.onStart,
      required this.onPause,
      required this.onResume,
      required this.onTogglePlayback,
      required this.onStop,
      required this.onDemo});
  final ActiveTourState state;
  final RouteExperience? selected;
  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onTogglePlayback;
  final VoidCallback onStop;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final phase = starting ? _CompanionPhase.preparing : _companionPhase(state);
    final copy = switch (phase) {
      _CompanionPhase.idle => (
          'READY WHEN YOU ARE',
          '选择一条路线，\n让位置替你翻页。',
          '进入随行不会请求定位。准备好了，再由你开启这一段城市声音。'
        ),
      _CompanionPhase.preparing => (
          'PREPARING THE WALK',
          '正在准备\n沿途讲述。',
          '把声音和文字留在手机里，走到现场也能从容继续。'
        ),
      _CompanionPhase.monitoring => state.status == 'permission_limited'
          ? (
              'LOCATION NEEDS PERMISSION',
              '让位置，\n找到你。',
              '定位许可尚未打开。允许后，靠近线索时会先提醒你，声音不会突然闯进来。'
            )
          : (
              'LISTENING FOR THE CITY',
              '沿着城市，\n慢慢走。',
              '定位正常。靠近线索时会先提醒你，声音不会突然闯进来。'
            ),
      _CompanionPhase.nearby => (
          'A STORY IS NEAR',
          '附近有一段\n声音。',
          state.locationMessage ?? '靠近故事点时，准备好了就点击播放。'
        ),
      _CompanionPhase.playing => (
          'NOW PLAYING',
          state.current?.title ?? '这一段城市，\n正在被听见。',
          '正在讲述。你可以随时暂停，回到眼前。'
        ),
      _CompanionPhase.paused => (
          'THE WALK IS PAUSED',
          '先把这一页，\n留在这里。',
          '随行已暂停。线索和进度都在，回来时继续寻找。'
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 25, 0, 28),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(copy.$1,
            style: discoverySans(9, color: AppColors.textMuted, spacing: 1.1)),
        const SizedBox(height: 11),
        Text(copy.$2, style: discoverySerif(29, height: 1.42, spacing: -1.7)),
        const SizedBox(height: 10),
        Text(copy.$3,
            style: discoverySans(11, height: 1.8, color: AppColors.textMuted)),
        if (phase == _CompanionPhase.idle && selected != null) ...[
          const SizedBox(height: 10),
          Text('本次随行 · ${selected!.title}',
              key: const ValueKey('companion-selected-route'),
              style:
                  discoverySans(11, height: 1.8, color: AppColors.terracotta)),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(state.errorMessage!,
              style:
                  discoverySans(11, height: 1.8, color: AppColors.terracotta)),
        ],
        const SizedBox(height: 18),
        Wrap(
            spacing: 10,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CompanionPrimaryButton(
                  phase: phase,
                  retryLocation: state.status == 'permission_limited',
                  enabled: phase != _CompanionPhase.preparing &&
                      (phase != _CompanionPhase.idle ||
                          (selected != null && _supportsCompanion(selected!))),
                  onStart: onStart,
                  onPause: onPause,
                  onResume: onResume,
                  onTogglePlayback: onTogglePlayback),
              if (phase == _CompanionPhase.monitoring &&
                  state.locationMode == TourLocationMode.simulated)
                _CompanionTextButton(
                    icon: DiscoveryMark.pin, label: '模拟靠近一处线索', onTap: onDemo),
              if (phase == _CompanionPhase.nearby)
                _CompanionTextButton(
                    icon: DiscoveryMark.arrowLeft,
                    label: '继续寻找',
                    onTap: onResume),
              if (phase != _CompanionPhase.idle &&
                  phase != _CompanionPhase.preparing)
                _CompanionTextButton(
                    icon: DiscoveryMark.check,
                    label: '结束本次随行',
                    onTap: onStop,
                    muted: true),
            ]),
      ]),
    );
  }
}

class _CompanionPrimaryButton extends StatelessWidget {
  const _CompanionPrimaryButton(
      {required this.phase,
      required this.retryLocation,
      required this.enabled,
      required this.onStart,
      required this.onPause,
      required this.onResume,
      required this.onTogglePlayback});
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
    final icon = switch (phase) {
      _CompanionPhase.idle => DiscoveryMark.radio,
      _CompanionPhase.monitoring => DiscoveryMark.pause,
      _CompanionPhase.nearby => DiscoveryMark.play,
      _CompanionPhase.playing => DiscoveryMark.pause,
      _CompanionPhase.paused => DiscoveryMark.play,
      _CompanionPhase.preparing => DiscoveryMark.radio,
    };
    final width = MediaQuery.sizeOf(context).width <= 360 ? 195.0 : 205.0;
    return DiscoveryTouch(
      key: const ValueKey('companion-primary'),
      label: label,
      onTap: enabled
          ? () {
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
                  onPause();
                  break;
                case _CompanionPhase.paused:
                  onResume();
                  break;
                case _CompanionPhase.preparing:
                  break;
              }
            }
          : null,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 51),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: enabled ? 1 : .55),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (phase == _CompanionPhase.preparing)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: AppColors.lime,
                      strokeWidth: 1.2,
                    ),
                  )
                else
                  DiscoveryIcon(icon, size: 17, color: AppColors.paper),
                const SizedBox(width: 8),
                Text(label, style: discoverySans(12, color: AppColors.paper)),
              ],
            ),
            if (phase == _CompanionPhase.idle ||
                phase == _CompanionPhase.nearby)
              const DiscoveryIcon(
                DiscoveryMark.arrowRight,
                size: 18,
                color: AppColors.paper,
              ),
          ],
        ),
      ),
    );
  }
}

class _CompanionTextButton extends StatelessWidget {
  const _CompanionTextButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.muted = false});
  final DiscoveryMark icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
      label: label,
      onTap: onTap,
      child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            DiscoveryIcon(icon,
                size: 15,
                color: muted ? AppColors.textMuted : AppColors.terracotta),
            const SizedBox(width: 5),
            Text(label,
                style: discoverySans(10,
                    color: muted ? AppColors.textMuted : AppColors.terracotta))
          ])));
}

class _CompanionNote extends StatelessWidget {
  const _CompanionNote();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      color: AppColors.lime.withValues(alpha: .48),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DiscoveryIcon(DiscoveryMark.headphones,
            size: 15, color: AppColors.moss),
        const SizedBox(width: 10),
        Expanded(
            child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '声音不会突然播放。\n',
              style: discoverySans(10,
                  color: AppColors.moss,
                  weight: FontWeight.w600,
                  height: 1.75)),
          TextSpan(
              text: '默认先提醒你，再由你点击播放。',
              style: discoverySans(10, color: AppColors.moss, height: 1.75))
        ])))
      ]));
}

/// A full-bleed field signal matching the editorial companion page. It
/// communicates whether the companion is actually receiving a usable position
/// without inventing a distance.
class _CompanionSignalWidget extends StatefulWidget {
  const _CompanionSignalWidget(
      {required this.active, required this.state, required this.horizontal});

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
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  ActiveTourState get state => widget.state;
  bool get active => widget.active;

  NearbyStoryPoint? get _nearest => state.nearbyStoryPoints.firstOrNull;

  NearbyStoryPoint? get _displayPoint {
    final currentId = state.current?.id;
    return state.nearbyStoryPoints
            .where((item) => item.fragment.id == currentId)
            .firstOrNull ??
        _nearest;
  }

  bool get _hasFreshPosition =>
      state.locationMode == TourLocationMode.real &&
      state.latestLocationSample != null;

  bool get _hasNearbyStory {
    return _companionHasNearbyStory(state);
  }

  String get _distance {
    // Simulated mode has no physical position. A null or unavailable sample
    // must stay visibly unknown instead of looking like a measured distance.
    if (!_hasFreshPosition) return '—';
    final value = _displayPoint?.distanceMeters;
    if (value == null || !value.isFinite) return '—';
    if (value < 1000) return value.round().toString();
    return (value / 1000).toStringAsFixed(1);
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) => SizedBox(
        key: const ValueKey('companion-signal'),
        height: 192,
        child: OverflowBox(
          minWidth: screenWidth,
          maxWidth: screenWidth,
          minHeight: 192,
          maxHeight: 192,
          alignment: Alignment.center,
          child: Container(
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
                      playing: state.isPlaying,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _distance,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 24,
                              fontStyle: FontStyle.italic,
                              color: AppColors.terracotta,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active
                                ? (_hasFreshPosition
                                    ? (_displayPoint?.distanceMeters != null &&
                                            _displayPoint!.distanceMeters! >=
                                                1000
                                        ? '公里'
                                        : '米')
                                    : '等待定位')
                                : '等你开启',
                            style: discoverySans(9, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: widget.horizontal,
                  top: 20,
                  child: Row(
                    children: [
                      const DiscoveryIcon(
                        DiscoveryMark.pin,
                        size: 14,
                        color: AppColors.moss,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        active &&
                                state.locationMode == TourLocationMode.simulated
                            ? '模拟定位'
                            : active && connected
                                ? '定位正常'
                                : '尚未定位',
                        style: discoverySans(9, color: AppColors.moss),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: widget.horizontal,
                  bottom: 18,
                  child: Text(
                    nearby ? 'NEARBY STORY' : 'YOUR NEXT LISTEN',
                    style: discoverySans(
                      8,
                      color: AppColors.textMuted,
                      spacing: 1.1,
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
}

class _CompanionSignalPainter extends CustomPainter {
  const _CompanionSignalPainter(
      {required this.active,
      required this.connected,
      required this.nearby,
      required this.playing,
      required this.breath});

  final bool active;
  final bool connected;
  final bool nearby;
  final bool playing;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = active ? breath : 0.0;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xffc6cf9b).withValues(alpha: .5);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: 245, height: 245), ring);
    final back = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (playing ? AppColors.moss : AppColors.terracotta)
          .withValues(alpha: active ? .55 + pulse * .3 : .48);
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
      ..color = AppColors.terracotta.withValues(
          alpha: nearby
              ? .7
              : active
                  ? .3
                  : .28);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.40);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
        Rect.fromCenter(
            center: center,
            width: nearby ? 133 : 106,
            height: nearby ? 170 : 145),
        front);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompanionSignalPainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.connected != connected ||
      oldDelegate.nearby != nearby ||
      oldDelegate.playing != playing ||
      oldDelegate.breath != breath;
}

class _CompanionRouteTile extends StatelessWidget {
  const _CompanionRouteTile(
      {required this.index,
      required this.route,
      required this.city,
      required this.selected,
      required this.enabled,
      required this.onSelect});
  final int index;
  final RouteExperience route;
  final String city;
  final bool selected;
  final bool enabled;
  final ValueChanged<RouteExperience> onSelect;

  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        key: ValueKey('companion-route-${route.id}'),
        label: '选择${route.title}开启随行',
        selected: selected,
        onTap: enabled ? () => onSelect(route) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 85),
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0x6be6eacb), Colors.transparent],
                  )
                : null,
            border: const Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                  width: 24,
                  child: Text('${index + 1}'.padLeft(2, '0'),
                      style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: Color(0xffa9957e)))),
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
                      ? Container(
                          color: AppColors.lime,
                          child: const Center(
                              child: DiscoveryIcon(DiscoveryMark.headphones,
                                  size: 18, color: AppColors.moss)))
                      : Image.network(route.heroImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.lime,
                              child: const Center(
                                  child: DiscoveryIcon(DiscoveryMark.headphones,
                                      size: 18, color: AppColors.moss)))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$city / ${route.theme}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: discoverySans(9, color: AppColors.textMuted)),
                      const SizedBox(height: 3),
                      Text(route.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: discoverySerif(16,
                              weight: FontWeight.w500,
                              color: selected
                                  ? AppColors.terracotta
                                  : AppColors.ink)),
                      const SizedBox(height: 3),
                      Text(
                          route.audioTour != null
                              ? '声音导览 · ${route.numberOfStops} 段线索'
                              : '现场文字 · 可随行阅读',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: discoverySans(9, color: AppColors.textMuted)),
                    ]),
              ),
              DiscoveryIcon(
                  selected ? DiscoveryMark.pin : DiscoveryMark.arrowUpRight,
                  color: selected ? AppColors.terracotta : AppColors.textMuted,
                  size: 17),
            ],
          ),
        ),
      );
}
