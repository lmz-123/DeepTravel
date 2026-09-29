part of 'discovery_page.dart';

/// The location experience has its own first-class destination. It explains
/// the mode before asking for permission; entering this tab never starts GPS or
/// audio by itself.
class _DiscoveryCompanion extends StatelessWidget {
  const _DiscoveryCompanion({
    required this.state,
    required this.activeTour,
    required this.onOpen,
    required this.onCity,
  });

  final DiscoveryState state;
  final ActiveTourState activeTour;
  final ValueChanged<RouteExperience> onOpen;
  final VoidCallback onCity;

  bool get _running => activeTour.session != null &&
      activeTour.status != 'idle' && activeTour.status != 'stopped';

  @override
  Widget build(BuildContext context) {
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
    return CustomScrollView(
      key: const PageStorageKey('companion-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: _DiscoveryHeader(
            city: state.city?.name ?? '选择城市',
            onCity: onCity,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 11, horizontal, 150),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('随位置，\n听见一座城。', style: discoverySerif(42, height: 1.25)),
                const SizedBox(height: 12),
                Text(
                  '选择一条路线，开启随行。靠近故事点时，城市会在你愿意的时候发出声音。',
                  style: discoverySans(13, height: 1.8, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                if (_running && selected != null)
                  _CompanionRunningCard(state: activeTour, route: selected)
                else
                  _CompanionPromiseCard(),
                const SizedBox(height: 30),
                Text(
                  '选择一条路线开始',
                  style: discoverySans(10, color: AppColors.textMuted, spacing: 1),
                ),
                const SizedBox(height: 10),
                if (routes.isEmpty)
                  Text('当前城市还没有可随行的路线。', style: discoverySerif(22))
                else
                  ...routes.map(
                    (route) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _CompanionRouteTile(route: route, onOpen: onOpen),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompanionPromiseCard extends StatelessWidget {
  const _CompanionPromiseCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: DiscoveryIcon(
                  DiscoveryMark.pin,
                  size: 25,
                  color: AppColors.ink,
                  stroke: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('随行 · 到点发现，点击播放', style: discoverySerif(18, color: AppColors.paper)),
                  const SizedBox(height: 5),
                  Text(
                    '会先询问你的允许。进入路线后，再由你决定是否开启定位与声音。',
                    style: discoverySans(11, height: 1.65, color: AppColors.paper.withValues(alpha: .68)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CompanionRunningCard extends StatelessWidget {
  const _CompanionRunningCard({required this.state, required this.route});
  final ActiveTourState state;
  final RouteExperience route;

  @override
  Widget build(BuildContext context) {
    final paused = state.status == 'paused';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(30),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.terracotta.withValues(alpha: .22), offset: const Offset(5, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DiscoveryIcon(DiscoveryMark.pin, color: AppColors.lime, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text(route.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: discoverySerif(16, color: AppColors.paper))),
              Text(paused ? '已暂停' : '随行中', style: discoverySans(10, color: AppColors.lime)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            state.locationMessage ?? '正在寻找附近的历史线索',
            style: discoverySans(11, height: 1.7, color: AppColors.paper.withValues(alpha: .7)),
          ),
          const SizedBox(height: 13),
          Container(height: 2, color: AppColors.paper.withValues(alpha: .14)),
          const SizedBox(height: 10),
          Text(
            state.locationMode == TourLocationMode.simulated ? '模拟定位 · 不会读取真实位置' : '真实定位 · 锁屏后继续寻找',
            style: discoverySans(10, color: AppColors.paper.withValues(alpha: .52)),
          ),
        ],
      ),
    );
  }
}

class _CompanionRouteTile extends StatelessWidget {
  const _CompanionRouteTile({required this.route, required this.onOpen});
  final RouteExperience route;
  final ValueChanged<RouteExperience> onOpen;

  @override
  Widget build(BuildContext context) => DiscoveryTouch(
        label: '选择${route.title}开启随行',
        onTap: () => onOpen(route),
        child: Container(
          constraints: const BoxConstraints(minHeight: 77),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Text('${route.numberOfStops}'.padLeft(2, '0'), style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 18, color: AppColors.terracotta)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(route.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: discoverySerif(15, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('${route.durationMinutes} 分钟 · ${route.numberOfStops} 段声音', style: discoverySans(10, color: AppColors.textMuted)),
                ]),
              ),
              const DiscoveryIcon(DiscoveryMark.arrowUpRight, color: AppColors.terracotta, size: 20),
            ],
          ),
        ),
      );
}
