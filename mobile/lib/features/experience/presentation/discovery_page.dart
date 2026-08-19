import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../domain/models.dart';
import 'experience_providers.dart';

class DiscoveryPage extends ConsumerWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(featuredRouteProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(featuredRouteProvider.future),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: route.when(
                    loading: () => const _RouteSkeleton(),
                    error: (error, _) => _ErrorCard(
                      onRetry: () => ref.invalidate(featuredRouteProvider),
                    ),
                    data: (value) => _FeaturedRouteCard(route: value),
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

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 5),
              Text('上海', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedRouteCard extends StatelessWidget {
  const _FeaturedRouteCard({required this.route});
  final RouteExperience route;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 80),
      child: Semantics(
        button: true,
        label: '查看路线 ${route.title}',
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/route/${route.slug}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorialImage(
                  asset: route.heroImage,
                  height: 290,
                  heroTag: 'route-${route.slug}',
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _GlassPill(label: '本周精选'),
                            const Spacer(),
                            _GlassPill(
                              label: AppConfig.mode == AppMode.demo
                                  ? '演示模式'
                                  : '在线',
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
                              text: '${route.stops.length} 站'),
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
