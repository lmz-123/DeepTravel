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
    required this.onDistanceRoute,
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
  final ValueChanged<String?> onDistanceRoute;
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
    final horizontal = MediaQuery.sizeOf(context).width <= 375 ? 20.0 : 23.0;
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
    onDistanceRoute(selectedRoute?.slug);
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
          child: _CompanionHeader(
              city: selectedRoute?.cityName.isNotEmpty == true
                  ? selectedRoute!.cityName
                  : state.city?.name),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 150),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CompanionFolio(),
                const SizedBox(height: 8),
                Text('把屏幕退到身后',
                    style: _companionSans(10,
                        color: AppColors.textMuted, spacing: 1.1)),
                const SizedBox(height: 10),
                const _CompanionTitle(),
                const SizedBox(height: 15),
                Text(
                  '你走近一处，城市才打开一段。',
                  style: _companionSans(11,
                      height: 1.9, color: const Color(0xFF81745F)),
                ),
                SizedBox(
                    height: MediaQuery.sizeOf(context).width <= 375 ? 20 : 24),
                if (selectedRoute != null && _supportsCompanion(selectedRoute))
                  _CompanionDistancePanel(
                    route: selectedRoute,
                    activeTour: activeTour,
                    signalActive: signalActive,
                    horizontal: horizontal,
                    starting: starting,
                    onStart: () => onStart(selectedRoute),
                    onStop: () => ref
                        .read(activeTourControllerProvider.notifier)
                        .stopTour(),
                  )
                else
                  _CompanionSignalWidget(
                    active: signalActive,
                    state: activeTour,
                    horizontal: horizontal,
                  ),
                if (selectedRoute != null && _supportsCompanion(selectedRoute))
                  _CommunityShareEntry(route: selectedRoute),
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
                                    style: _companionSans(11,
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
                                _companionSans(11, color: AppColors.textMuted)),
                  ),
                if (selectedRoute != null && !_supportsCompanion(selectedRoute))
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Text('这条路线暂未开放定位随行，可以先翻阅目录。',
                        style: _companionSans(11,
                            height: 1.8, color: AppColors.textMuted)),
                  ),
                const SizedBox(height: 120),
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
                        style: _companionSans(9,
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
                Text('选择路线', style: discoverySerif(24)),
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
                              onSelect: (route) {
                                _resetDistanceTarget(ref, selectedRoute, route);
                                onSelectRoute(route);
                              },
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
                              _resetDistanceTarget(ref, selectedRoute, route);
                              onSelectRoute(route);
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('选择其他路线 · 共 ${orderedRoutes.length} 条',
                                style: _companionSans(11,
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

void _resetDistanceTarget(
    WidgetRef ref, RouteExperience? previous, RouteExperience next) {
  if (previous?.id == next.id) return;
  if (previous != null) {
    ref
        .read(companionDistanceControllerProvider(previous.slug).notifier)
        .reset();
  }
  ref.read(companionDistanceControllerProvider(next.slug).notifier).reset();
}

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
                        style: _companionSans(9,
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
                style: _companionSans(13),
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
                      style: _companionSans(12, color: AppColors.textMuted)),
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
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).width <= 375 ? 52 : 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '',
                    style: _companionSans(10,
                        color: AppColors.textMuted, spacing: .7),
                  ),
                  TextSpan(
                    text: 'SOUND WALK',
                    style: _companionSans(10,
                        color: const Color(0xff8d7b67), spacing: .7),
                  ),
                ],
              ),
            ),
            const Text(
              '',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 19,
                fontStyle: FontStyle.italic,
                color: _distanceRed,
              ),
            ),
          ],
        ),
      );
}

class _CompanionTitle extends StatelessWidget {
  const _CompanionTitle();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('让位置，',
                    style: discoverySerif(
                        MediaQuery.sizeOf(context).width <= 375 ? 43 : 47,
                        height: 1.27,
                        spacing: -2.4)),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: -14,
                      bottom: 1,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: -.035,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDAE779),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '替你翻页。',
                      style: discoverySerif(
                          MediaQuery.sizeOf(context).width <= 375 ? 43 : 47,
                          height: 1.27,
                          spacing: -2.4,
                          color: _distanceRed),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
  final VoidCallback onDemo;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final phase = starting ? _CompanionPhase.preparing : _companionPhase(state);
    if (phase == _CompanionPhase.idle ||
        phase == _CompanionPhase.preparing ||
        (phase == _CompanionPhase.monitoring &&
            state.status != 'permission_limited' &&
            state.status != 'recoverable_error')) {
      return state.errorMessage == null
          ? phase == _CompanionPhase.monitoring &&
                  state.locationMode == TourLocationMode.simulated
              ? _CompanionTextButton(
                  icon: DiscoveryMark.pin, label: '模拟靠近一处线索', onTap: onDemo)
              : const SizedBox.shrink()
          : Text(state.errorMessage!,
              style: _companionSans(11, color: AppColors.terracotta));
    }
    final copy = switch (phase) {
      _CompanionPhase.idle => ('READY WHEN YOU ARE', '选择一条路线，\n让位置替你翻页。', ''),
      _CompanionPhase.preparing => ('PREPARING THE WALK', '正在准备\n沿途讲述。', ''),
      _CompanionPhase.monitoring => (state.status == 'permission_limited' ||
              state.status == 'recoverable_error')
          ? (
              'LOCATION NEEDS PERMISSION',
              '让位置，\n找到你。',
              state.locationMessage ?? '定位尚未就绪，点按重新开启定位。'
            )
          : ('LISTENING FOR THE CITY', '沿着城市，慢慢走。', ''),
      _CompanionPhase.nearby => (
          'A STORY IS NEAR',
          '这一处，已经靠近。',
          state.current?.publicPlaceName ?? ''
        ),
      _CompanionPhase.playing => (
          'NOW PLAYING',
          state.current?.title ?? '这一段城市，\n正在被听见。',
          ''
        ),
      _CompanionPhase.paused => ('THE WALK IS PAUSED', '先把这一页，留在这里。', '随行已暂停'),
    };
    if (phase == _CompanionPhase.playing) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CompanionListeningStrip(state: state, onPause: onTogglePlayback),
        Row(children: [
          Flexible(
              child: _CompanionTextButton(
                  icon: DiscoveryMark.pause, label: '暂停随行', onTap: onPause)),
          const SizedBox(width: 12),
        ]),
      ]);
    }
    final compact =
        phase != _CompanionPhase.idle && phase != _CompanionPhase.preparing;
    return Container(
      padding: EdgeInsets.fromLTRB(0, compact ? 15 : 25, 0, compact ? 19 : 28),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _distanceRule))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!compact) ...[
          Text(copy.$1,
              style:
                  _companionSans(9, color: AppColors.textMuted, spacing: 1.1)),
          const SizedBox(height: 11),
        ],
        Text(copy.$2,
            style: discoverySerif(
                compact
                    ? MediaQuery.sizeOf(context).width <= 375
                        ? 23
                        : 25
                    : 29,
                height: compact ? 1.55 : 1.42,
                spacing: compact ? -.8 : -1.7)),
        if (copy.$3.isNotEmpty) ...[
          SizedBox(height: compact ? 5 : 10),
          Text(copy.$3,
              style: _companionSans(11, height: 1.9, color: _distanceMuted)),
        ],
        if (phase == _CompanionPhase.idle && selected != null) ...[
          const SizedBox(height: 10),
          Text('本次随行 · ${selected!.title}',
              key: const ValueKey('companion-selected-route'),
              style:
                  _companionSans(11, height: 1.8, color: AppColors.terracotta)),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(state.errorMessage!,
              style:
                  _companionSans(11, height: 1.8, color: AppColors.terracotta)),
        ],
        SizedBox(height: compact ? 15 : 18),
        Row(
          key: const ValueKey('companion-walk-actions'),
          children: [
            Flexible(
              child: _CompanionPrimaryButton(
                phase: phase,
                retryLocation: state.status == 'permission_limited' ||
                    state.status == 'recoverable_error',
                enabled: phase != _CompanionPhase.preparing &&
                    (phase != _CompanionPhase.idle ||
                        (selected != null && _supportsCompanion(selected!))),
                onStart: onStart,
                onPause: onPause,
                onResume: onResume,
                onTogglePlayback: onTogglePlayback,
              ),
            ),
            if (compact) ...[
              const SizedBox(width: 12),
            ],
          ],
        ),
        if (phase == _CompanionPhase.monitoring &&
            state.locationMode == TourLocationMode.simulated)
          _CompanionTextButton(
              icon: DiscoveryMark.pin, label: '模拟靠近一处线索', onTap: onDemo),
        if (phase == _CompanionPhase.nearby)
          _CompanionTextButton(
              icon: DiscoveryMark.arrowLeft, label: '继续寻找', onTap: onResume),
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
    const width = 174.0;
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
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: enabled ? 1 : .55),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(17),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  style: _companionSans(12, color: AppColors.paper)),
            ),
            const SizedBox(width: 25),
            if (phase == _CompanionPhase.preparing)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  color: AppColors.lime,
                  strokeWidth: 1.2,
                ),
              )
            else
              DiscoveryIcon(icon,
                  size: 18, stroke: 1.4, color: const Color(0xFFE1E8B4)),
          ],
        ),
      ),
    );
  }
}

class _CompanionTextButton extends StatelessWidget {
  const _CompanionTextButton(
      {required this.icon, required this.label, required this.onTap});
  final DiscoveryMark icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DiscoveryTouch(
      label: label,
      onTap: onTap,
      child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            DiscoveryIcon(icon, size: 15, color: AppColors.terracotta),
            const SizedBox(width: 5),
            Text(label, style: _companionSans(10, color: AppColors.terracotta))
          ])));
}

/// A full-bleed field signal matching the editorial companion page. It
/// communicates whether the companion is actually receiving a usable position
/// without inventing a distance.
class _CompanionSignalWidget extends StatelessWidget {
  const _CompanionSignalWidget({
    required this.active,
    required this.state,
    required this.horizontal,
    this.distance,
    this.onRetry,
    this.onStart,
    this.onStop,
    this.starting = false,
  });

  final bool active;
  final ActiveTourState state;
  final double horizontal;
  final CompanionDistanceState? distance;
  final VoidCallback? onRetry, onStart, onStop;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final meters = distance?.target?.distanceMeters;
    final known = distance?.hasLocation == true &&
        meters != null &&
        meters.isFinite &&
        meters >= 0;
    final number = !known
        ? '—'
        : meters < 1000
            ? meters.round().toString()
            : (meters / 1000).toStringAsFixed(1);
    final unit = known
        ? meters >= 1000
            ? '约 · 公里'
            : '约 · 米'
        : active
            ? '等待定位'
            : '等你开启';
    final locationLabel = distance?.isPaused == true
        ? '随行已暂停'
        : active && state.locationMode == TourLocationMode.simulated
            ? '模拟定位'
            : active && distance?.hasLocation == true
                ? distance!.isApproximate
                    ? '位置估算'
                    : '定位正常'
                : active
                    ? distance?.locationIssue ?? '等待定位'
                    : starting
                        ? '正在准备'
                        : '未开启';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final fieldHeight = screenWidth <= 375 ? 164.0 : 178.0;
    return SizedBox(
      key: const ValueKey('companion-signal'),
      height: fieldHeight,
      child: OverflowBox(
        minWidth: screenWidth,
        maxWidth: screenWidth,
        minHeight: fieldHeight,
        maxHeight: fieldHeight,
        alignment: Alignment.center,
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8ECCD), AppColors.paper],
              stops: [0, .65],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(
                child: TweenAnimationBuilder<double>(
              tween: Tween(end: active ? 1.0 : 0.0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, progress, __) =>
                  CustomPaint(painter: _CompanionSignalPainter(progress)),
            )),
            if (!active &&
                !starting &&
                !_companionRunning(state) &&
                onStart != null)
              Center(
                  child: DiscoveryTouch(
                      key: const ValueKey('companion-start'),
                      label: '开启随行',
                      onTap: onStart,
                      child: Transform.rotate(
                          angle: -5 * math.pi / 180,
                          child: SizedBox(
                              width: 166,
                              height: 152,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('开启',
                                        style: _companionSans(10,
                                            color: const Color(0xff86745f),
                                            spacing: 5)),
                                    const SizedBox(height: 3),
                                    Text('随行',
                                        style: discoverySerif(31,
                                            color: _distanceRed, spacing: 3)),
                                    const SizedBox(height: 10),
                                    Container(
                                        width: 22,
                                        height: 1,
                                        color: const Color(0x80bc4432)),
                                  ])))))
            else
              Center(
                child: Transform.rotate(
                  angle: -5 * math.pi / 180,
                  child: Container(
                    width: 91,
                    height: 91,
                    decoration: BoxDecoration(
                      color: const Color(0xF0F5F0E7),
                      shape: BoxShape.circle,
                      border: Border.all(color: _distanceRed),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(number,
                            key: const ValueKey('companion-distance-number'),
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 35,
                              height: 1,
                              letterSpacing: -1.5,
                              fontStyle: FontStyle.italic,
                              color: _distanceRed,
                            )),
                        const SizedBox(height: 6),
                        Text(unit,
                            style: _companionSans(10,
                                color: const Color(0xFF86745F))),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: horizontal,
              top: 16,
              child: Semantics(
                button: onRetry != null,
                label: onRetry != null ? '$locationLabel，重新定位' : locationLabel,
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('companion-location-retry'),
                  onTap: onRetry,
                  child: SizedBox(
                      height: 44,
                      child: Align(
                          alignment: Alignment.topRight,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const DiscoveryIcon(DiscoveryMark.pin,
                                size: 12,
                                stroke: 1.4,
                                color: Color(0xFF65734E)),
                            const SizedBox(width: 5),
                            Text(
                                onRetry != null
                                    ? '$locationLabel ↻'
                                    : locationLabel,
                                style: _companionSans(9,
                                    color: const Color(0xFF65734E))),
                          ]))),
                ),
              ),
            ),
            if (_companionRunning(state) && onStop != null)
              Positioned(
                  right: horizontal,
                  bottom: 4,
                  child: DiscoveryTouch(
                      key: const ValueKey('companion-end'),
                      label: '停止随行',
                      onTap: onStop,
                      child: SizedBox(
                          height: 44,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('停止随行',
                                    style: discoverySerif(12,
                                        color: _distanceRed)),
                                const SizedBox(height: 6),
                                Container(
                                    width: 23, height: 1, color: _distanceRed),
                              ])))),
            Positioned(
              left: horizontal,
              bottom: 15,
              child: Text('A PLACE TO GET CLOSER',
                  style: _companionSans(8,
                      color: const Color(0xFF82775F), spacing: 1.2)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CompanionSignalPainter extends CustomPainter {
  const _CompanionSignalPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    void contour(double width, double height, double degrees, Color color) {
      canvas.save();
      canvas.rotate(degrees * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color,
      );
      canvas.restore();
    }

    contour(253, 260, -18, const Color(0x70C2CC95));
    contour(162, 115, 12 + 9 * progress, const Color(0x72BC4432));
    contour(119, 161, -18 - 9 * progress, const Color(0x4ABC4432));
  }

  @override
  bool shouldRepaint(_CompanionSignalPainter oldDelegate) =>
      progress != oldDelegate.progress;
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
                          style: _companionSans(9, color: AppColors.textMuted)),
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
                          style: _companionSans(9, color: AppColors.textMuted)),
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

class _CommunityShareEntry extends ConsumerWidget {
  const _CommunityShareEntry({required this.route});
  final RouteExperience route;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target =
        ref.watch(companionDistanceControllerProvider(route.slug)).target;
    if (target == null) return const SizedBox.shrink();
    return NoteButton(
        label: '留一则见闻',
        onTap: () => context.push(Uri(
            path: '/community/write',
            queryParameters: {'fragment': target.fragment.id}).toString()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(children: [
            Text('留一则见闻', style: noteSerif(16, color: noteRed)),
            const Spacer(),
            const DiscoveryIcon(DiscoveryMark.pen, size: 17, color: noteRed),
          ]),
        ));
  }
}
