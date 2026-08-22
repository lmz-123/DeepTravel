import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../domain/models.dart';
import '../../auth/presentation/auth_provider.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';

class DiscoveryPage extends ConsumerWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(citiesProvider);
    final routes = ref.watch(cityRoutesProvider);
    final archivedJourneys = ref.watch(archivedActiveJourneysProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(citiesProvider);
            ref.invalidate(cityRoutesProvider);
            ref.invalidate(archivedActiveJourneysProvider);
            await ref.read(citiesProvider.future);
            await ref.read(cityRoutesProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: _Header()),
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
                padding: const EdgeInsets.symmetric(horizontal: 0),
                sliver: SliverToBoxAdapter(
                  child: cities.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _RouteSkeleton(),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ErrorCard(
                        onRetry: () => ref.invalidate(citiesProvider),
                      ),
                    ),
                    data: (availableCities) {
                      if (availableCities.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: _EmptyCatalog(
                            title: '还没有开放的城市',
                            message: '新目的地发布后会出现在这里。',
                          ),
                        );
                      }
                      return routes.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: _RouteSkeleton(),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _ErrorCard(
                            onRetry: () => ref.invalidate(cityRoutesProvider),
                          ),
                        ),
                        data: (items) => items.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: _EmptyCatalog(
                                  title: '这座城市还没有开放路线',
                                  message: '可以先切换城市，或稍后再来看看。',
                                ),
                              )
                            : _RouteCarousel(routes: items),
                      );
                    },
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
    );
  }
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

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(citiesProvider);
    final selectedCity = ref.watch(activeCityProvider);
    final selectedSlug = selectedCity?.slug;
    final availableCities = cities.value ?? const <CityExperience>[];

    return Row(
      children: [
        const BrandMark(),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: AppConfig.testAuthEnabled ? '账号与测试用户' : '账号',
          onSelected: (action) async {
            ref.invalidate(activeTourControllerProvider);
            await ref.read(tourStoreProvider).clearPrivateData();
            if (action == 'logout') {
              await ref.read(authControllerProvider.notifier).logout();
            } else {
              await ref
                  .read(authControllerProvider.notifier)
                  .switchTestUser(action);
            }
            ref.invalidate(journeyControllerProvider);
            ref.invalidate(activeTourControllerProvider);
            ref.invalidate(archivedActiveJourneysProvider);
          },
          itemBuilder: (context) => [
            if (AppConfig.testAuthEnabled) ...const [
              PopupMenuItem(value: 'tester-a', child: Text('切换到测试账号 A')),
              PopupMenuItem(value: 'tester-b', child: Text('切换到测试账号 B')),
              PopupMenuDivider(),
            ],
            const PopupMenuItem(value: 'logout', child: Text('退出登录')),
          ],
          icon: const Icon(Icons.account_circle_outlined),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: '选择城市',
          initialValue: selectedSlug,
          enabled: availableCities.isNotEmpty,
          onSelected: (slug) =>
              ref.read(selectedCityProvider.notifier).select(slug),
          itemBuilder: (context) => availableCities
              .map(
                (city) => PopupMenuItem<String>(
                  value: city.slug,
                  child: Row(
                    children: [
                      Icon(
                        city.slug == selectedSlug
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 18,
                        color: AppColors.moss,
                      ),
                      const SizedBox(width: 10),
                      Text(city.name),
                    ],
                  ),
                ),
              )
              .toList(),
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
      ],
    );
  }
}

class _RouteCarousel extends StatefulWidget {
  const _RouteCarousel({required this.routes});

  final List<RouteExperience> routes;

  @override
  State<_RouteCarousel> createState() => _RouteCarouselState();
}

class _RouteCarouselState extends State<_RouteCarousel> {
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
    return FadeSlideIn(
      delay: const Duration(milliseconds: 80),
      child: Column(
        children: [
          SizedBox(
            height: 505,
            child: PageView.builder(
              key: const ValueKey('route-carousel'),
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.routes.length,
              onPageChanged: (index) => setState(() => _selectedIndex = index),
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
                    route: widget.routes[index],
                    onTap: () {
                      if (_selectedIndex != index) {
                        _controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                        );
                        return;
                      }
                      context.push('/route/${widget.routes[index].slug}');
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '第 ${_selectedIndex + 1} 条，共 ${widget.routes.length} 条路线',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.routes.length, (index) {
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
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onTap});
  final RouteExperience route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '查看路线 ${route.title}',
      child: Card(
        key: ValueKey('route-card-${route.slug}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialImage(
                source: route.heroImage,
                height: 276,
                heroTag: 'route-${route.slug}',
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GlassPill(
                            label: route.isFeatured ? '本周精选' : '城市路线',
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
                            ?.copyWith(
                              color: AppColors.white,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.subtitle,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _Metric(
                            icon: Icons.schedule_rounded,
                            text: '${route.durationMinutes} 分钟'),
                        _Metric(
                            icon: Icons.route_rounded,
                            text: '${route.distanceKm} km'),
                        _Metric(
                            icon: Icons.flag_outlined,
                            text: '${route.numberOfStops} 站'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('打开城市手册',
                            style: Theme.of(context).textTheme.labelLarge),
                        const Spacer(),
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
              child:
                  Text(text, style: Theme.of(context).textTheme.labelMedium)),
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
      (Icons.headphones_rounded, '听一个短故事'),
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
                Text(item.$2, style: Theme.of(context).textTheme.bodyLarge),
              ],
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
