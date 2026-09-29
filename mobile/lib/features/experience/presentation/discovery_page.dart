import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../application/nearby_story_points.dart';
import '../domain/city_story.dart';
import '../domain/models.dart';
import '../domain/tour_runtime.dart';
import 'active_tour_controller.dart';
import 'audio_ownership_controller.dart';
import 'discovery_controller.dart';
import 'experience_providers.dart';
import 'widgets/discovery_art.dart';
import 'widgets/traveler_bottom_navigation.dart';

part 'discovery_journal.dart';
part 'discovery_atlas.dart';
part 'discovery_shelf.dart';
part 'discovery_companion.dart';

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key, this.initialTab});
  final String? initialTab;
  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  var _coldStartPrepared = false;
  var _section = TravelerSection.journal;
  final _busyFavorites = <String>{};
  RouteExperience? _lastOpened;
  String? _companionRouteId;

  @override
  void initState() {
    super.initState();
    _section = _parseTab(widget.initialTab);
  }

  @override
  void didUpdateWidget(DiscoveryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _section = _parseTab(widget.initialTab);
    }
  }

  TravelerSection _parseTab(String? tab) => switch (tab) {
        'atlas' => TravelerSection.atlas,
        'shelf' => TravelerSection.shelf,
        'companion' => TravelerSection.companion,
        _ => TravelerSection.journal,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_coldStartPrepared) return;
    _coldStartPrepared = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareColdStart());
  }

  Future<void> _prepareColdStart() async {
    final controller = ref.read(discoveryControllerProvider.notifier);
    DiscoveryStartupAction action;
    try {
      action = await controller.prepareColdStart();
    } catch (_) {
      return;
    }
    if (!mounted || action != DiscoveryStartupAction.needsPurposeExplanation) {
      return;
    }
    final locate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('看看离你最近的见地', style: discoverySerif(23)),
        content: const Text(
          '见地会使用一次当前位置来识别首次展示的城市，并按距离排列附近景区。刷新或切换城市时会再次获取一次位置，不会持续追踪或保存你的行程轨迹。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('手动选择城市'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('允许定位'),
          ),
        ],
      ),
    );
    if (locate == true) {
      await controller.continueColdStart();
    } else {
      controller.declineColdStart();
    }
  }

  void _openRoute(RouteExperience route) {
    setState(() => _lastOpened = route);
    context.push('/route/${route.slug}');
  }

  Future<void> _startCompanion(RouteExperience route) async {
    final journey = ref.read(journeyControllerProvider.notifier);
    final journeyId = await journey.start(route);
    if (!mounted) return;
    final session = ref.read(journeyControllerProvider).session;
    if (journeyId == null || session == null) {
      _notice('这条随行暂时无法开始，请先打开路线查看详情。');
      return;
    }
    if (route.audioTour != null) {
      await ref
          .read(activeTourControllerProvider.notifier)
          .start(route, session);
      return;
    }
    context.go('/journey/$journeyId');
  }

  Future<void> _toggleFavorite(RouteExperience route) =>
      _toggleFavoriteId(route.id);
  Future<void> _toggleFavoriteId(String id) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _notice('登录后，把想去的地方放进书架。');
      return;
    }
    if (_busyFavorites.contains(id)) return;
    final selected = ref
            .read(travelerFavoritesProvider(userId))
            .value
            ?.any((item) => item.kind == 'route' && item.targetId == id) ??
        false;
    setState(() => _busyFavorites.add(id));
    try {
      final repository = ref.read(experienceRepositoryProvider);
      if (selected) {
        await repository.removeFavorite('route', id);
      } else {
        await repository.addFavorite('route', id);
      }
      ref.invalidate(travelerFavoritesProvider(userId));
      await ref.read(travelerFavoritesProvider(userId).future);
      if (mounted) _notice(selected ? '已从书架移出' : '已放进书架，留给下一次出发');
    } catch (_) {
      if (mounted) _notice('书架暂时无法更新，请稍后重试');
    } finally {
      if (mounted) setState(() => _busyFavorites.remove(id));
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: discoverySans(12, color: AppColors.paper),
          ),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(23, 0, 23, 100),
          duration: const Duration(milliseconds: 2400),
        ),
      );
  }

  Future<void> _chooseCity(DiscoveryState state) async {
    final slug = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6b20261e),
      builder: (_) => _DiscoveryCitySheet(state: state),
    );
    if (slug == null || slug == state.city?.slug || !mounted) return;
    await ref.read(discoveryControllerProvider.notifier).switchCity(slug);
  }

  Future<void> _refresh() async {
    await ref.read(discoveryControllerProvider.notifier).refreshDiscovery();
    ref.invalidate(_shelfCatalogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryControllerProvider);
    final state = discovery.asData?.value;
    final userId = ref.watch(currentUserIdProvider);
    final favoriteState =
        userId == null ? null : ref.watch(travelerFavoritesProvider(userId));
    final favorites = favoriteState?.value ?? const <TravelerFavorite>[];
    final saved = favorites
        .where((f) => f.kind == 'route')
        .map((f) => f.targetId)
        .toSet();
    final ownership = ref.watch(audioOwnershipProvider);
    final tour = ref.watch(activeTourControllerProvider);
    final hasTour = tour.session != null &&
        tour.route != null &&
        tour.status != 'stopped' &&
        tour.status != 'idle';
    final resumeTitle = ownership.isActive
        ? ownership.title
        : hasTour
            ? tour.route!.title
            : _lastOpened?.title;
    final bottom = MediaQuery.paddingOf(context)
        .bottom
        .clamp(15.0, double.infinity)
        .toDouble();
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: discovery.when(
              skipLoadingOnRefresh: true,
              loading: () => const _DiscoveryLoading(),
              error: (_, __) => _DiscoveryFailure(
                onRetry: () => ref.invalidate(discoveryControllerProvider),
              ),
              data: (state) => IndexedStack(
                index: switch (_section) {
                  TravelerSection.atlas => 1,
                  TravelerSection.shelf => 2,
                  TravelerSection.companion => 3,
                  _ => 0,
                },
                children: [
                  _DiscoveryJournal(
                    key: ValueKey('journal-${state.city?.slug}'),
                    state: state,
                    saved: saved,
                    busyFavorites: _busyFavorites,
                    onFavorite: _toggleFavorite,
                    onOpen: _openRoute,
                    onCity: () => _chooseCity(state),
                    onAtlas: () =>
                        setState(() => _section = TravelerSection.atlas),
                    onCompanion: () =>
                        setState(() => _section = TravelerSection.companion),
                    onRefresh: _refresh,
                  ),
                  _DiscoveryAtlas(
                    key: ValueKey('atlas-${state.city?.slug}'),
                    state: state,
                    saved: saved,
                    busyFavorites: _busyFavorites,
                    onFavorite: _toggleFavorite,
                    onOpen: _openRoute,
                    onCity: () => _chooseCity(state),
                    onRefresh: _refresh,
                  ),
                  _DiscoveryShelf(
                    favoritesLoading: favoriteState?.isLoading == true,
                    favoritesError: favoriteState?.hasError == true,
                    onRetryFavorites: () {
                      if (userId != null) {
                        ref.invalidate(travelerFavoritesProvider(userId));
                      }
                    },
                    favorites:
                        favorites.where((f) => f.kind == 'route').toList(),
                    state: state,
                    visible: _section == TravelerSection.shelf,
                    busyFavorites: _busyFavorites,
                    onRemove: _toggleFavoriteId,
                    onOpen: _openRoute,
                    onCity: () => _chooseCity(state),
                    onBrowse: () =>
                        setState(() => _section = TravelerSection.journal),
                  ),
                  _DiscoveryCompanion(
                    state: state,
                    activeTour: tour,
                    onOpen: _openRoute,
                    selectedRouteId: _companionRouteId,
                    onSelectRoute: (route) =>
                        setState(() => _companionRouteId = route.id),
                    onStart: _startCompanion,
                  ),
                ],
              ),
            ),
          ),
          if (resumeTitle != null)
            Positioned(
              left: 23,
              right: 23,
              bottom: bottom + 75,
              child: DiscoveryTouch(
                label: '继续查看$resumeTitle',
                onTap: () {
                  if (ownership.isActive) {
                    context.push(ownership.destination);
                  } else if (hasTour) {
                    context.push('/journey/${tour.session!.id}');
                  } else if (_lastOpened != null) {
                    _openRoute(_lastOpened!);
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 45),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      DiscoveryIcon(
                        ownership.isActive || hasTour
                            ? DiscoveryMark.headphones
                            : DiscoveryMark.book,
                        size: 17,
                        color: AppColors.paper,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resumeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: discoverySans(11, color: AppColors.paper),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '继续查看',
                        style: discoverySans(
                          10,
                          color: const Color(0xffdbe782),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const DiscoveryIcon(
                        DiscoveryMark.arrowUpRight,
                        size: 14,
                        color: Color(0xffdbe782),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TravelerBottomNavigation(
              active: _section,
              onSelected: (section) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _section = section);
              },
            ),
          ),
          if (state?.isLocating == true)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.terracotta,
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({this.city, this.onCity});
  final String? city;
  final VoidCallback? onCity;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 71,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width <= 360 ? 20 : 23,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DiscoveryBrand(onTap: () => context.push('/profile')),
              if (city != null)
                Tooltip(
                  message: '选择城市',
                  child: DiscoveryTouch(
                    label: '选择城市，当前$city',
                    onTap: onCity,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Text(
                            city!,
                            style: discoverySans(13, color: AppColors.ink),
                          ),
                          const SizedBox(width: 10),
                          const DiscoveryIcon(DiscoveryMark.down, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _DiscoveryCitySheet extends StatefulWidget {
  const _DiscoveryCitySheet({required this.state});
  final DiscoveryState state;
  @override
  State<_DiscoveryCitySheet> createState() => _DiscoveryCitySheetState();
}

class _DiscoveryCitySheetState extends State<_DiscoveryCitySheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final cities = widget.state.cities
        .where(
          (city) => '${city.name}${city.slug}${city.subtitle}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 18, 25, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '下一站，不必很远',
                      style: discoverySans(10, color: const Color(0xff8a7762)),
                    ),
                  ),
                  _DiscoveryIconButton(
                    mark: DiscoveryMark.close,
                    label: '关闭城市选择',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '去哪里\n'),
                      TextSpan(
                        text: '看一看？',
                        style: discoverySerif(
                          43,
                          height: 1.3,
                          color: AppColors.terracotta,
                        ),
                      ),
                    ],
                  ),
                  style: discoverySerif(43, height: 1.3),
                ),
              ),
              if (widget.state.cities.length > 6)
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    hintText: '搜索城市',
                    prefixIcon: Icon(Icons.search),
                    border: UnderlineInputBorder(),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cities.length,
                  itemBuilder: (context, index) {
                    final city = cities[index],
                        selected = city.slug == widget.state.city?.slug;
                    return DiscoveryTouch(
                      label: '选择${city.name}',
                      selected: selected,
                      tint: true,
                      onTap: () => Navigator.pop(context, city.slug),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 85),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x222d3026)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${index + 1}'.padLeft(2, '0'),
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontStyle: FontStyle.italic,
                                fontSize: 15,
                                color: Color(0xffa59780),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Text(
                              city.name,
                              style: discoverySerif(
                                27,
                                color: selected
                                    ? AppColors.terracotta
                                    : AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                city.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: discoverySans(
                                  10,
                                  color: const Color(0xff8e7b65),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            DiscoveryIcon(
                              selected
                                  ? DiscoveryMark.check
                                  : DiscoveryMark.arrowUpRight,
                              size: 22,
                              color: selected
                                  ? AppColors.terracotta
                                  : AppColors.ink,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (cities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text('还没有找到这座城市', style: discoverySerif(20)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryIconButton extends StatelessWidget {
  const _DiscoveryIconButton({
    required this.mark,
    required this.label,
    required this.onTap,
    this.selected,
    this.color = AppColors.ink,
    this.size = 20,
    this.filled = false,
  });
  final DiscoveryMark mark;
  final String label;
  final VoidCallback? onTap;
  final bool? selected;
  final Color color;
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: DiscoveryTouch(
          onTap: onTap,
          label: label,
          selected: selected,
          tint: true,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child:
                  DiscoveryIcon(mark, size: size, color: color, filled: filled),
            ),
          ),
        ),
      );
}

class _DiscoveryLoading extends StatelessWidget {
  const _DiscoveryLoading();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const _DiscoveryHeader(),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.terracotta,
                strokeWidth: 1.5,
              ),
            ),
          ),
        ],
      );
}

class _DiscoveryFailure extends StatelessWidget {
  const _DiscoveryFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const _DiscoveryHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '这一页，\n暂时没有翻开。',
                      style: discoverySerif(31),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Text('网络恢复后，再读一座城。', style: discoverySans(13)),
                    const SizedBox(height: 28),
                    DiscoveryPaperButton(label: '重新加载', onTap: onRetry),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}
