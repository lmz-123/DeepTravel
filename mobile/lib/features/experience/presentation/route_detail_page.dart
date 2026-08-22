import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/primary_action.dart';
import '../domain/tour_runtime.dart';
import '../domain/models.dart';
import '../domain/fragment_models.dart';
import 'experience_providers.dart';
import 'location_mode_controller.dart';
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
          label: route.audioTour == null ? '开始这段探索' : '戴上耳机，开始行走',
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
              source: route.heroImage,
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
                if (route.audioTour != null) ...[
                  const SizedBox(height: 26),
                  _AudioTourBrief(manifest: route.audioTour!),
                ],
                const SizedBox(height: 28),
                Text(route.audioTour == null ? '这一路，你会看见什么' : '这一路，你会追问什么',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(route.description,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                RouteCanvas(stops: route.stops),
                const SizedBox(height: 30),
                Text(route.audioTour == null ? '五次停留' : '五段不剧透的线索',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 18),
                if (route.audioTour == null)
                  ...route.stops.map((stop) =>
                      _StopRow(stop: stop, isLast: stop == route.stops.last))
                else
                  ...route.audioTour!.fragments.map((fragment) =>
                      _FragmentPreviewRow(
                          fragment: fragment,
                          isLast: fragment == route.audioTour!.fragments.last)),
                if (!route.isPublished) ...[
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
      (
        '${route.audioTour?.fragments.length ?? route.stops.length}',
        route.audioTour == null ? '站停留' : '段线索'
      ),
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

class _AudioTourBrief extends ConsumerWidget {
  const _AudioTourBrief({required this.manifest});
  final AudioTourManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = (manifest.downloadSizeBytes / 1024 / 1024).toStringAsFixed(1);
    final modeState = ref.watch(locationModeControllerProvider);
    final mode = modeState.asData?.value ?? TourLocationMode.real;
    final isSimulated = mode == TourLocationMode.simulated;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.headphones_rounded, color: AppColors.gold),
          SizedBox(width: 10),
          Text('耳机优先的定位导览',
              style: TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 14),
        Text(manifest.centralQuestion,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppColors.white)),
        const SizedBox(height: 14),
        Text(
            isSimulated
                ? '开始后将准备约 $size MB 音频。模拟定位不会读取真实位置，也不会申请定位权限；你可以手动推进线索。'
                : '开始后将准备约 $size MB 音频，并申请行走期间的位置、通知与拍照权限。锁屏时系统仍可能限制定位，应用会如实显示暂停状态。',
            style: TextStyle(
                color: AppColors.white.withValues(alpha: .78), height: 1.55)),
        const SizedBox(height: 16),
        Divider(color: AppColors.white.withValues(alpha: .16), height: 1),
        const SizedBox(height: 12),
        Semantics(
          label: '模拟定位测试开关',
          hint: isSimulated ? '当前忽略真实位置' : '当前使用真实位置',
          child: Row(children: [
            const Icon(Icons.location_searching_rounded, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('模拟定位（测试）',
                      style: TextStyle(
                          color: AppColors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(isSimulated ? '忽略 GPS，用按钮模拟到达' : '使用 GPS，靠近地点自动触发',
                      style: TextStyle(
                          color: AppColors.white.withValues(alpha: .68),
                          fontSize: 12)),
                ])),
            Switch.adaptive(
                value: isSimulated,
                onChanged: modeState.isLoading
                    ? null
                    : (value) => ref
                        .read(locationModeControllerProvider.notifier)
                        .setMode(value
                            ? TourLocationMode.simulated
                            : TourLocationMode.real)),
          ]),
        ),
        const SizedBox(height: 12),
        Text(manifest.demoLabel ?? '内容已完成审核',
            style: const TextStyle(color: AppColors.gold)),
      ]),
    );
  }
}

class _FragmentPreviewRow extends StatelessWidget {
  const _FragmentPreviewRow({required this.fragment, required this.isLast});
  final StoryFragment fragment;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            width: 36,
            child: Column(children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: AppColors.ink, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${fragment.position}',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600))),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 1, color: AppColors.ink.withValues(alpha: .18)))
            ])),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fragment.safePreview,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text(
                          fragment.interactionType == 'photo'
                              ? '包含一次可稍后完成的拍照线索'
                              : '自动播放 · 可阅读文字稿',
                          style: Theme.of(context).textTheme.bodyMedium)
                    ]))),
      ]));
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
