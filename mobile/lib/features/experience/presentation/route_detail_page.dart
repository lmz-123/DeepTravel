import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/primary_action.dart';
import '../domain/tour_runtime.dart';
import '../domain/models.dart';
import '../domain/fragment_models.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'home_story_controller.dart';
import 'location_mode_controller.dart';
import 'offline_package_controller.dart';
import 'route_preview_location_provider.dart';
import 'widgets/location_mode_selector.dart';
import 'widgets/route_canvas.dart';
import 'widgets/favorite_button.dart';

class RouteDetailPage extends ConsumerWidget {
  const RouteDetailPage({required this.slug, super.key});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(offlineAwareRouteProvider(slug));
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final heroHeight = 330.0 + ((textScale - 1).clamp(0.0, 1.0) * 110.0);
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
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .88),
                shape: BoxShape.circle,
              ),
              child: FavoriteButton(kind: 'route', targetId: route.id),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: PrimaryAction(
          label: route.audioTour == null ? '开始这段探索' : '戴上耳机，开始行走',
          busy: journey.isBusy,
          icon: Icons.directions_walk_rounded,
          onPressed: () async {
            final id = await _startRoute(ref);
            if (id != null && context.mounted) context.go('/journey/$id');
          },
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: EditorialImage(
              source: route.heroImage,
              height: heroHeight,
              heroTag: 'route-${route.slug}',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 100, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      route.theme.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 9,
                        height: 1.3,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      route.title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontFamily: 'Songti SC',
                        fontFamilyFallback: [
                          'STSong',
                          'Noto Serif CJK SC',
                          'serif',
                        ],
                        fontSize: 27,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      route.subtitle,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: .76),
                        fontSize: 10,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ManualTabs(),
                    const SizedBox(height: 22),
                    if (route.predeparture?.available ?? false) ...[
                      _PredepartureSurface(route: route),
                      const SizedBox(height: 18),
                    ],
                    _Metrics(route: route),
                    const SizedBox(height: 25),
                    _HowToWalkCard(route: route),
                    const SizedBox(height: 16),
                    _PreparationCard(route: route),
                    const SizedBox(height: 16),
                    _RouteStoryCard(route: route),
                    const SizedBox(height: 28),
                    Text(
                      route.audioTour == null ? '这一路，你会看见什么' : '故事方向',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 19,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _ClueSurface(route: route),
                    const SizedBox(height: 20),
                    _AboutManualCard(route: route),
                    if (!route.isPublished) ...[
                      const SizedBox(height: 18),
                      const _EditorialNotice(),
                    ],
                    if (journey.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        journey.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _startRoute(WidgetRef ref) async {
    final controller = ref.read(journeyControllerProvider.notifier);
    final onlineId = await controller.start(route);
    if (onlineId != null) return onlineId;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return null;
    final package =
        await ref.read(routeOfflinePackageServiceProvider).load(route.slug);
    if (package == null) return null;
    final localId = 'offline:$userId:${route.id}';
    final now = DateTime.now().toUtc();
    final session = JourneySession(
      id: localId,
      routeId: route.id,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
      startedAt: now,
      updatedAt: now,
    );
    final store = ref.read(tourStoreProvider);
    await store.enqueue(OutboxEvent(
      id: 'start_journey:$localId',
      type: 'start_journey',
      payload: {
        'local_journey_id': localId,
        'route_id': route.id,
      },
    ));
    await store.saveJson('offline_session_$localId', {
      'route_slug': route.slug,
      'created_at': now.toIso8601String(),
    });
    return controller.resume(package.route, session);
  }
}

class _PredepartureSurface extends ConsumerWidget {
  const _PredepartureSurface({required this.route});

  final RouteExperience route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final introduction = route.predeparture!;
    final playback = ref.watch(homeStoryPlaybackControllerProvider);
    final expectedPrefix = 'predeparture:${route.id}:';
    final ownsPlayback = playback.source == ListeningSource.predeparture &&
        (playback.story?.id.startsWith(expectedPrefix) ?? false);
    final phase = ownsPlayback ? playback.phase : HomeStoryPhase.ready;
    final icon = switch (phase) {
      HomeStoryPhase.playing => Icons.pause_rounded,
      HomeStoryPhase.ended => Icons.replay_rounded,
      HomeStoryPhase.error => Icons.refresh_rounded,
      _ => Icons.play_arrow_rounded,
    };
    final label = switch (phase) {
      HomeStoryPhase.playing => '暂停出发前讲述',
      HomeStoryPhase.ended => '重新播放出发前讲述',
      HomeStoryPhase.error => '重试出发前讲述',
      _ => '播放出发前讲述',
    };
    return Container(
      key: const ValueKey('predeparture-surface'),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '先认识这座城',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  introduction.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'Songti SC',
                        fontSize: 13,
                        height: 1.82,
                      ),
                ),
                if (ownsPlayback && playback.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    playback.message!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          IconButton.filled(
            key: const ValueKey('predeparture-play-pause'),
            tooltip: label,
            onPressed: () async {
              final controller =
                  ref.read(homeStoryPlaybackControllerProvider.notifier);
              if (!ownsPlayback) {
                await controller.loadPredeparture(route);
                await controller.play();
              } else {
                await controller.toggle();
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: phase == HomeStoryPhase.playing
                  ? AppColors.terracotta
                  : AppColors.ink,
              foregroundColor: phase == HomeStoryPhase.playing
                  ? AppColors.white
                  : AppColors.gold,
            ),
            icon: Icon(icon),
          ),
        ],
      ),
    );
  }
}

class _ManualTabs extends StatelessWidget {
  const _ManualTabs();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab(context, '出发前', active: true),
            const SizedBox(width: 18),
            _tab(context, '故事方向'),
            const SizedBox(width: 18),
            _tab(context, '行走提示'),
          ],
        ),
      );

  Widget _tab(BuildContext context, String label, {bool active = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.ink : AppColors.textMuted,
                  fontSize: 9,
                ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 20 : 0,
            height: 2,
            color: AppColors.terracotta,
          ),
        ],
      );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.route});
  final RouteExperience route;

  @override
  Widget build(BuildContext context) {
    final values = <(IconData, String)>[
      (Icons.schedule_rounded, '${route.durationMinutes} 分钟'),
      (Icons.route_rounded, '${route.distanceKm} km'),
      (
        Icons.headphones_rounded,
        '${route.audioTour?.fragments.length ?? route.stops.length} ${route.audioTour == null ? '站停留' : '段讲述'}'
      ),
      (Icons.alt_route_rounded, '自由顺序'),
    ];
    return Wrap(
      runSpacing: 10,
      children: values
          .map(
            (value) => Padding(
              padding: const EdgeInsets.only(right: 17),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(value.$1, size: 13, color: AppColors.moss),
                  const SizedBox(width: 5),
                  Text(
                    value.$2,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 9,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HowToWalkCard extends ConsumerWidget {
  const _HowToWalkCard({required this.route});

  final RouteExperience route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(locationModeControllerProvider).asData?.value ??
        TourLocationMode.real;
    return _ManualCard(
      title: '这一路，你会怎样行走',
      child: Column(
        children: [
          _InstructionRow(
            icon: Icons.alt_route_rounded,
            title: '没有必须照走的固定路线',
            body: '从任意景点开始都可以，故事会保留自己的阅读顺序。',
          ),
          _InstructionRow(
            icon: Icons.headphones_rounded,
            title: '走近景点，听见讲述',
            body: route.audioTour == null
                ? '抵达每一次停留后，打开对应的城市故事。'
                : '真实定位模式会在接近节点时准备讲述，也可以随时手动打开。',
          ),
          const _InstructionRow(
            icon: Icons.visibility_outlined,
            title: '观察与拍照都由你决定',
            body: '现场任务只是邀请，不完成也不会阻断后面的内容。',
            last: true,
          ),
          const SizedBox(height: 14),
          LocationModeSelector(
            keyPrefix: 'route-detail-mode',
            value: mode,
            onChanged: (next) =>
                ref.read(locationModeControllerProvider.notifier).setMode(next),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              mode == TourLocationMode.simulated
                  ? '模拟预览已启用，开始导览后可手动推进线索'
                  : '真实行走已启用，开始导览后会按位置发现线索',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.moss,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationCard extends ConsumerWidget {
  const _PreparationCard({required this.route});

  final RouteExperience route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = OfflinePackageKey(route.slug, route.audioTour?.scriptVersion);
    final status = ref.watch(offlinePackageControllerProvider(key));
    final package = status.asData?.value ?? const OfflinePackageStatus.idle();
    final downloading = package.phase == OfflinePackagePhase.downloading;
    final label = switch (package.phase) {
      OfflinePackagePhase.idle => '下载离线内容',
      OfflinePackagePhase.downloading => package.total > 0
          ? '正在准备 ${package.complete}/${package.total}'
          : '正在准备…',
      OfflinePackagePhase.complete => '离线内容已准备',
      OfflinePackagePhase.stale => '更新离线内容',
      OfflinePackagePhase.failed => '重试下载',
    };
    final tags = route.pretrip?.companionTags ?? const <String>[];
    final tips = route.pretrip?.tips;
    final preparationNotes = <String>[
      ...?tips?.safety.take(1),
      ...?tips?.rest.take(1),
      ...?tips?.accessibility.take(1),
      ...?tips?.weatherAdaptation.take(1),
    ];
    return _ManualCard(
      title: '轻装出发，也留一点余量',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: (tags.isEmpty
                    ? const ['建议佩戴耳机', '穿适合步行的鞋', '留意天气']
                    : tags.take(4))
                .map((tag) => _ManualTag(label: tag))
                .toList(growable: false),
          ),
          const SizedBox(height: 13),
          const Text('提前下载后，网络不稳定时仍可继续听讲述；位置触发是否可用取决于系统定位状态。'),
          if (preparationNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...preparationNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $note',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  route.audioTour == null || downloading || package.isUsable
                      ? null
                      : () => ref
                          .read(offlinePackageControllerProvider(key).notifier)
                          .download(route),
              icon: downloading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(package.isUsable
                      ? Icons.download_done_rounded
                      : Icons.download_outlined),
              label: Text(route.audioTour == null ? '暂无离线音频' : label),
            ),
          ),
          if (package.message != null) ...[
            const SizedBox(height: 8),
            Text(package.message!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _RouteStoryCard extends ConsumerWidget {
  const _RouteStoryCard({required this.route});

  final RouteExperience route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = routeCanvasPointsFor(route);
    return RouteCanvas(
      points: points,
      userLocation: points.isEmpty
          ? null
          : ref.watch(routePreviewLocationProvider).asData?.value,
    );
  }
}

class _ClueSurface extends StatelessWidget {
  const _ClueSurface({required this.route});

  final RouteExperience route;

  @override
  Widget build(BuildContext context) {
    final children = route.audioTour == null
        ? route.stops
            .map((stop) => _StopRow(
                  stop: stop,
                  isLast: stop == route.stops.last,
                ))
            .toList(growable: false)
        : route.audioTour!.fragments
            .map((fragment) => _FragmentPreviewRow(
                  fragment: fragment,
                  isLast: fragment == route.audioTour!.fragments.last,
                ))
            .toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _AboutManualCard extends StatelessWidget {
  const _AboutManualCard({required this.route});

  final RouteExperience route;

  @override
  Widget build(BuildContext context) => _ManualCard(
        title: '关于这条手册',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 10,
                    height: 1.7,
                    color: const Color(0xFF596965),
                  ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ManualTag(label: route.difficulty),
                _ManualTag(label: '${route.numberOfStops} 个故事节点'),
                if (!route.isPublished) const _ManualTag(label: '内容预览中'),
              ],
            ),
          ],
        ),
      );
}

class _ManualCard extends StatelessWidget {
  const _ManualCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .07),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.icon,
    required this.title,
    required this.body,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 27,
              child: Align(
                alignment: Alignment.topLeft,
                child: Icon(icon, size: 17, color: AppColors.terracotta),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          height: 1.5,
                          color: const Color(0xFF717B77),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FragmentPreviewRow extends StatelessWidget {
  const _FragmentPreviewRow({required this.fragment, required this.isLast});
  final StoryFragment fragment;
  final bool isLast;

  @override
  Widget build(BuildContext context) => _ClueRow(
        number: fragment.position,
        title: fragment.title ?? fragment.safePreview,
        metadata: fragment.interactionType == 'photo'
            ? '可选拍照线索 · 可稍后完成'
            : '自动播放 · 可阅读文字稿',
        tags: fragment.experienceTags,
        isLast: isLast,
      );
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isLast});
  final ExperienceStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) => _ClueRow(
        number: stop.position,
        title: stop.title,
        metadata: stop.kicker,
        tags: stop.experienceTags,
        isLast: isLast,
      );
}

class _ClueRow extends StatelessWidget {
  const _ClueRow({
    required this.number,
    required this.title,
    required this.metadata,
    required this.tags,
    required this.isLast,
  });

  final int number;
  final String title;
  final String metadata;
  final List<String> tags;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.ink.withValues(alpha: .09),
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 29,
              child: Text(
                number.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.terracotta,
                  fontFamily: 'Songti SC',
                  fontSize: 15,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 11,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadata,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 8,
                          color: const Color(0xFF7C837E),
                        ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ExperienceTags(tags: tags),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, size: 18),
            ),
          ],
        ),
      );
}

class _ManualTag extends StatelessWidget {
  const _ManualTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A5B55),
            fontSize: 8,
            height: 1.2,
          ),
        ),
      );
}

class _ExperienceTags extends StatelessWidget {
  const _ExperienceTags({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 6,
        children:
            tags.map((tag) => _ManualTag(label: tag)).toList(growable: false),
      );
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
