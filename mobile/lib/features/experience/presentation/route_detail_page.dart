import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/primary_action.dart';
import '../domain/models.dart';
import 'experience_providers.dart';
import 'widgets/route_canvas.dart';

class RouteDetailPage extends ConsumerWidget {
  const RouteDetailPage({required this.slug, super.key});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider(slug));
    return route.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton.tonal(
            onPressed: () => ref.invalidate(routeProvider(slug)),
            child: const Text('重新加载路线'),
          ),
        ),
      ),
      data: (value) => _RouteDetail(route: value),
    );
  }
}

class _RouteDetail extends ConsumerWidget {
  const _RouteDetail({required this.route});
  final RouteExperience route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyControllerProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filledTonal(
            tooltip: '返回',
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: PrimaryAction(
          label: '开始这段探索',
          busy: journey.isBusy,
          icon: Icons.directions_walk_rounded,
          onPressed: () async {
            final id =
                await ref.read(journeyControllerProvider.notifier).start(route);
            if (id != null && context.mounted) context.go('/journey/$id');
          },
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: EditorialImage(
              asset: route.heroImage,
              height: 430,
              heroTag: 'route-${route.slug}',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      route.theme.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.gold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      route.title,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      route.subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList.list(
              children: [
                _Metrics(route: route),
                const SizedBox(height: 28),
                Text('这一路，你会看见什么',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(route.description,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                RouteCanvas(stops: route.stops),
                const SizedBox(height: 30),
                Text('五次停留', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 18),
                ...route.stops.map((stop) =>
                    _StopRow(stop: stop, isLast: stop == route.stops.last)),
                if (!route.isVerified) ...[
                  const SizedBox(height: 22),
                  const _EditorialNotice(),
                ],
                if (journey.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(journey.errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.route});
  final RouteExperience route;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('${route.durationMinutes}', '分钟'),
      ('${route.distanceKm}', '公里'),
      ('${route.stops.length}', '站停留'),
    ];
    return Row(
      children: values
          .map(
            (value) => Expanded(
              child: Column(
                children: [
                  Text(value.$1,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 3),
                  Text(value.$2,
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isLast});
  final ExperienceStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: AppColors.ink, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    '${stop.position}',
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 1,
                          color: AppColors.ink.withValues(alpha: 0.18))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(stop.kicker,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialNotice extends StatelessWidget {
  const _EditorialNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.paperDeep, borderRadius: BorderRadius.circular(18)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text('当前为 MVP 演示内容。公开发布前，地点史实、图片与讲述文本需经过来源标注和人工审核。')),
        ],
      ),
    );
  }
}
