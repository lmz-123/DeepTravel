import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../domain/discovery_location.dart';
import '../domain/city_story.dart';
import '../domain/models.dart';
import 'active_tour_controller.dart';
import 'discovery_controller.dart';
import 'experience_providers.dart';
import 'offline_package_controller.dart';
import 'traveler_shell.dart';
import 'widgets/rotating_tour_orb.dart';
import 'widgets/favorite_button.dart';

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  var _coldStartPrepared = false;

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
        title: const Text('看看离你最近的见地'),
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

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryControllerProvider);
    final archivedJourneys = ref.watch(archivedActiveJourneysProvider);
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(archivedActiveJourneysProvider);
                await ref
                    .read(discoveryControllerProvider.notifier)
                    .refreshDiscovery();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: discovery.maybeWhen(
                        data: (state) => _Header(state: state),
                        orElse: () => const _HeaderPlaceholder(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 34, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: FadeSlideIn(
                        child: Text(
                          '今天，慢一点\n看见城市的里层。',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: archivedJourneys.maybeWhen(
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _ArchivedJourneyCard(journey: items.first),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    key: const ValueKey('route-selection-section'),
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    sliver: SliverToBoxAdapter(
                      child: discovery.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: _RouteSkeleton(),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _ErrorCard(
                            onRetry: () => ref.invalidate(
                              discoveryControllerProvider,
                            ),
                          ),
                        ),
                        data: (state) {
                          if (state.cities.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: _EmptyCatalog(
                                title: '还没有开放的城市',
                                message: '新目的地发布后会出现在这里。',
                              ),
                            );
                          }
                          if (state.cards.isEmpty) {
                            return Column(
                              children: [
                                _LocationStatus(state: state),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: _EmptyCatalog(
                                    title: '这座城市还没有开放景区',
                                    message: '可以先切换城市，或稍后再来看看。',
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _LocationStatus(state: state),
                              _RouteCarousel(
                                key: ValueKey(
                                  '${state.city?.slug}-${state.revision}',
                                ),
                                cards: state.cards,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    key: const ValueKey('city-story-section'),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: discovery.maybeWhen(
                        data: (state) => _CityStoryModules(
                          home: state.storyHome,
                          onSwitchCity: (slug) => ref
                              .read(discoveryControllerProvider.notifier)
                              .switchCity(slug),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 38, 20, 48),
                    sliver: SliverToBoxAdapter(child: _ExperiencePromise()),
                  ),
                ],
              ),
            ),
          ),
          const RotatingTourOrbOverlay(),
        ],
      ),
    );
  }
}

class _CityStoryModules extends StatelessWidget {
  const _CityStoryModules({
    required this.home,
    required this.onSwitchCity,
  });

  final CityStoryHome home;
  final ValueChanged<String> onSwitchCity;

  @override
  Widget build(BuildContext context) {
    if (home.isEmpty &&
        home.emptyReason == null &&
        home.fallbackCities.isEmpty &&
        home.modules.isEmpty) {
      return const SizedBox.shrink();
    }
    if (home.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.paperDeep,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('城市故事', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(home.emptyReason ?? '这座城市的故事还在准备中。'),
              if (home.fallbackCities.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: home.fallbackCities
                      .map((city) => ActionChip(
                            label: Text('看看${city.name}'),
                            onPressed: () => onSwitchCity(city.slug),
                          ))
                      .toList(growable: false),
                ),
              ] else ...[
                const SizedBox(height: 10),
                const Text('可以使用右上角的城市选择器看看其他城市。'),
              ],
            ],
          ),
        ),
      );
    }
    final modules = home.modules
        .where((module) => module.items.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: modules.map((module) {
        final primary = module.primary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  module.title,
                  style: primary
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: primary ? 220 : 190,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: module.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => _CityStoryCardView(
                    card: module.items[index],
                    primary: primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _CityStoryCardView extends StatelessWidget {
  const _CityStoryCardView({required this.card, required this.primary});

  final CityStoryCard card;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${card.contentType}：${card.story.title}',
        child: SizedBox(
          width: primary ? 300 : 240,
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(26),
            child: InkWell(
              key: primary ? const ValueKey('home-random-story-action') : null,
              onTap: () => context.push('/story/${card.story.id}'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EditorialImage(source: card.story.coverImage),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xdd17201c)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          card.contentType,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          card.story.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppColors.white),
                        ),
                        if (card.themes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            card.themes.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: .75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ArchivedJourneyCard extends ConsumerWidget {
  const _ArchivedJourneyCard({required this.journey});

  final ResumableJourney journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FadeSlideIn(
      child: Material(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            final id = ref
                .read(journeyControllerProvider.notifier)
                .resume(journey.route, journey.session);
            context.go('/journey/$id');
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.moss),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('继续未完成的旧路线',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 3),
                      Text(journey.route.title,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPlaceholder extends StatelessWidget {
  const _HeaderPlaceholder();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          BrandMark(onPressed: () => TravelerShellScope.showDrawer(context)),
          const Spacer(),
          const SizedBox(width: 96, height: 36),
        ],
      );
}

class _Header extends ConsumerWidget {
  const _Header({required this.state});

  final DiscoveryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = state.city;
    final selectedSlug = selectedCity?.slug;
    final availableCities = state.cities;

    return Row(
      children: [
        BrandMark(onPressed: () => TravelerShellScope.showDrawer(context)),
        const Spacer(),
        if (selectedCity != null)
          FavoriteButton(kind: 'city', targetId: selectedCity.slug),
        Semantics(
          button: true,
          label: '选择城市，当前${selectedCity?.name ?? '未选择'}',
          child: Tooltip(
            message: '选择城市',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: availableCities.isEmpty
                    ? null
                    : () => showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _CitySelectionSheet(
                            cities: availableCities,
                            selectedSlug: selectedSlug,
                            onSelected: (slug) {
                              ref
                                  .read(discoveryControllerProvider.notifier)
                                  .switchCity(slug);
                            },
                          ),
                        ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.fromLTRB(12, 8, 9, 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        selectedCity?.name ?? '选择城市',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.expand_more_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CitySelectionSheet extends StatefulWidget {
  const _CitySelectionSheet({
    required this.cities,
    required this.selectedSlug,
    required this.onSelected,
  });

  final List<CityExperience> cities;
  final String? selectedSlug;
  final ValueChanged<String> onSelected;

  @override
  State<_CitySelectionSheet> createState() => _CitySelectionSheetState();
}

class _CitySelectionSheetState extends State<_CitySelectionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeCitySearch(_query);
    final filtered = widget.cities.where((city) {
      if (normalized.isEmpty) return true;
      return _normalizeCitySearch('${city.name} ${city.subtitle} ${city.slug}')
          .contains(normalized);
    }).toList(growable: false);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return FractionallySizedBox(
      heightFactor: .82,
      child: Material(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '关闭城市选择',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('下一站，想去哪里？',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 5),
                Text('城市和路线都由后台发布，新的目的地会自动来到这里。',
                    style: Theme.of(context).textTheme.bodySmall),
                if (widget.cities.length >= 8) ...[
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: false,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: '搜城市或它的气质…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('没有找到这座城市，换个关键词试试。'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 1100
                          ? 3
                          : MediaQuery.sizeOf(context).width >= 700
                              ? 2
                              : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          MediaQuery.sizeOf(context).width < 700 ? 2.05 : 1.05,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final city = filtered[index];
                      final selected = city.slug == widget.selectedSlug;
                      return AnimatedScale(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        scale: selected ? .97 : 1,
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label: '${city.name}，${city.subtitle}',
                          child: Material(
                            color: AppColors.paperDeep,
                            borderRadius: BorderRadius.circular(22),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                widget.onSelected(city.slug);
                                Navigator.of(context).pop();
                              },
                              child: Stack(fit: StackFit.expand, children: [
                                city.heroImage.isEmpty
                                    ? const ColoredBox(color: AppColors.moss)
                                    : Image.network(
                                        city.heroImage,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                                color: AppColors.moss),
                                      ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black87
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(city.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          )),
                                      const SizedBox(height: 3),
                                      Text(city.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          )),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Positioned(
                                    top: 12,
                                    right: 12,
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppColors.gold,
                                      child: Icon(Icons.check_rounded,
                                          size: 18, color: AppColors.ink),
                                    ),
                                  ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

String _normalizeCitySearch(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.state});

  final DiscoveryState state;

  @override
  Widget build(BuildContext context) {
    final message = state.isLocating
        ? '正在获取当前位置，景区顺序稍后更新…'
        : _failureMessage(state.locationFailure);
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Icon(
            state.isLocating
                ? Icons.my_location_rounded
                : Icons.location_off_outlined,
            size: 16,
            color: AppColors.moss,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  String? _failureMessage(DiscoveryLocationFailureReason? reason) =>
      switch (reason) {
        null => null,
        DiscoveryLocationFailureReason.denied ||
        DiscoveryLocationFailureReason.deniedForever =>
          '未获得定位权限，当前按后台推荐顺序展示。',
        DiscoveryLocationFailureReason.serviceDisabled =>
          '系统定位已关闭，当前按后台推荐顺序展示。',
        DiscoveryLocationFailureReason.timeout ||
        DiscoveryLocationFailureReason.unavailable =>
          '暂时无法获得当前位置，当前按后台推荐顺序展示。',
      };
}

class _RouteCarousel extends ConsumerStatefulWidget {
  const _RouteCarousel({super.key, required this.cards});

  final List<ScenicAreaCard> cards;

  @override
  ConsumerState<_RouteCarousel> createState() => _RouteCarouselState();
}

class _RouteCarouselState extends ConsumerState<_RouteCarousel> {
  late final PageController _controller;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journeyIndex = ref.watch(routeJourneyIndexProvider).value ?? const {};
    return FadeSlideIn(
      delay: const Duration(milliseconds: 80),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale =
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
              final cardWidth = constraints.maxWidth * .88;
              final imageHeight = cardWidth / 2.24;
              final contentHeight = cardWidth * .29 * textScale;
              final carouselHeight = imageHeight + contentHeight;
              return SizedBox(
                height: carouselHeight,
                child: PageView.builder(
                  key: const ValueKey('route-carousel'),
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.cards.length,
                  onPageChanged: (index) =>
                      setState(() => _selectedIndex = index),
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final page = _controller.hasClients &&
                              _controller.position.hasContentDimensions
                          ? _controller.page ?? _selectedIndex.toDouble()
                          : _selectedIndex.toDouble();
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      final scale = 1 - distance * .045;
                      return Transform.translate(
                        offset: Offset(0, distance * 12),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: 1 - distance * .22,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _RouteCard(
                        card: widget.cards[index],
                        onTap: () {
                          if (_selectedIndex != index) {
                            _controller.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                            );
                            return;
                          }
                          _openRoute(
                            widget.cards[index].route,
                            journeyIndex[widget.cards[index].route.id],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '第 ${_selectedIndex + 1} 个，共 ${widget.cards.length} 个景区',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.cards.length, (index) {
                final selected = index == _selectedIndex;
                return AnimatedContainer(
                  key: ValueKey('route-indicator-$index'),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: selected ? 24 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.ink
                        : AppColors.ink.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRoute(
      RouteExperience route, JourneyLibraryItem? libraryItem) async {
    if (libraryItem == null) {
      context.push('/route/${route.slug}');
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final key = UserJourneyKey(userId, libraryItem.journey.id);
    try {
      final ownerContext = await ref.read(journeyContextProvider(key).future);
      if (!mounted) return;
      if (ownerContext.journey.status == 'active') {
        ref
            .read(journeyControllerProvider.notifier)
            .resume(ownerContext.route, ownerContext.journey);
        context.go('/journey/${ownerContext.journey.id}');
      } else if (ownerContext.journeyKind == 'fragmented') {
        await ref
            .read(activeTourControllerProvider.notifier)
            .startRevisit(ownerContext);
        if (mounted) context.go('/journey/${ownerContext.journey.id}');
      } else {
        context.go('/footprints/${ownerContext.journey.id}');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('旅程进度暂时无法恢复，请稍后重试')),
      );
    }
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.card, required this.onTap});

  final ScenicAreaCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = card.route;
    final packageKey = OfflinePackageKey(
      route.slug,
      route.audioTour?.scriptVersion,
    );
    final packageStatus =
        ref.watch(offlinePackageControllerProvider(packageKey)).asData?.value ??
            const OfflinePackageStatus.idle();
    return Semantics(
      button: true,
      label: '查看景区 ${route.title}',
      child: Card(
        key: ValueKey('route-card-${route.slug}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2.24,
                child: EditorialImage(
                  source: route.heroImage,
                  heroTag: 'route-${route.slug}',
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _GlassPill(
                              label: card.distanceMeters == null
                                  ? route.isFeatured
                                      ? '本周精选'
                                      : '城市景区'
                                  : _formatDistance(card.distanceMeters!),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          route.theme,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.gold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          route.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.schedule_rounded,
                          text: '${route.durationMinutes} 分钟',
                        ),
                        _Metric(
                          icon: Icons.route_rounded,
                          text: '${route.distanceKm} km',
                        ),
                        _Metric(
                          icon: Icons.flag_outlined,
                          text: '${route.numberOfStops} 站',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _OfflinePackageButton(
                          route: route,
                          status: packageStatus,
                          onPressed: () => ref
                              .read(offlinePackageControllerProvider(packageKey)
                                  .notifier)
                              .download(route),
                        ),
                        const Spacer(),
                        Text('打开城市手册',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(width: 10),
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.white,
                          child: Icon(Icons.arrow_forward_rounded, size: 19),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflinePackageButton extends StatelessWidget {
  const _OfflinePackageButton({
    required this.route,
    required this.status,
    required this.onPressed,
  });

  final RouteExperience route;
  final OfflinePackageStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final downloading = status.phase == OfflinePackagePhase.downloading;
    final tooltip = switch (status.phase) {
      OfflinePackagePhase.idle => '下载离线包',
      OfflinePackagePhase.downloading => status.total > 0
          ? '正在下载离线包 ${status.complete}/${status.total}'
          : '正在下载离线包',
      OfflinePackagePhase.complete => '离线包已下载 · ${status.message ?? '完整性校验通过'}',
      OfflinePackagePhase.stale => '离线包有新版本，点击更新',
      OfflinePackagePhase.failed => status.message ?? '下载失败，点击重试',
    };
    final icon = switch (status.phase) {
      OfflinePackagePhase.idle => Icons.download_outlined,
      OfflinePackagePhase.complete => Icons.download_done_rounded,
      OfflinePackagePhase.stale => Icons.system_update_alt_rounded,
      OfflinePackagePhase.failed => Icons.error_outline_rounded,
      OfflinePackagePhase.downloading => null,
    };
    return Semantics(
      label: tooltip,
      button: true,
      child: SizedBox.square(
        dimension: 48,
        child: IconButton(
          key: ValueKey('offline-package-${route.slug}'),
          tooltip: tooltip,
          onPressed: downloading ? null : onPressed,
          iconSize: 20,
          icon: downloading
              ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    value: status.total > 0
                        ? (status.complete / status.total)
                            .clamp(0.0, 1.0)
                            .toDouble()
                        : null,
                  ),
                )
              : Icon(
                  icon,
                  color: status.phase == OfflinePackagePhase.failed
                      ? Theme.of(context).colorScheme.error
                      : AppColors.ink,
                ),
        ),
      ),
    );
  }
}

String _formatDistance(double meters) {
  if (meters < 1000) return '距你 ${meters.round()} 米';
  final kilometers = meters / 1000;
  return '距你 ${kilometers < 10 ? kilometers.toStringAsFixed(1) : kilometers.round()} 公里';
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: AppColors.white),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.moss),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _ExperiencePromise extends StatelessWidget {
  const _ExperiencePromise();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.visibility_outlined, '观察真实细节'),
      (Icons.auto_awesome_outlined, '带走一条见识'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('少看屏幕，多看眼前', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppColors.paperDeep, shape: BoxShape.circle),
                        child: Icon(item.$1, color: AppColors.ink, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.$2,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteSkeleton extends StatelessWidget {
  const _RouteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 470,
      decoration: BoxDecoration(
          color: AppColors.paperDeep, borderRadius: BorderRadius.circular(24)),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 40, color: AppColors.moss),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36),
            const SizedBox(height: 12),
            const Text('路线暂时没有抵达'),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('重新试试')),
          ],
        ),
      ),
    );
  }
}
