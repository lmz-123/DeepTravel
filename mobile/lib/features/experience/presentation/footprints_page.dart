import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_back.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/editorial_image.dart';
import '../domain/models.dart';
import 'experience_providers.dart';

class FootprintsPage extends ConsumerWidget {
  const FootprintsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(currentJourneyLibraryProvider);
    return RouteBackScope(
      fallbackLocation: '/',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的足迹'),
          leading: IconButton(
            tooltip: '返回首页',
            onPressed: () => popOrGo(context, '/'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(journeyLibraryProvider);
            ref.invalidate(currentJourneyLibraryProvider);
            await ref.read(currentJourneyLibraryProvider.future);
          },
          child: library.when(
            loading: () => const _ScrollableCenter(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => _ScrollableCenter(
              child: _LibraryMessage(
                icon: Icons.cloud_off_outlined,
                title: '足迹暂时没有加载出来',
                message: '下拉刷新，或稍后再回来看看。',
                action: FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(currentJourneyLibraryProvider),
                  child: const Text('重新加载'),
                ),
              ),
            ),
            data: (items) => items.isEmpty
                ? const _ScrollableCenter(
                    child: _LibraryMessage(
                      icon: Icons.route_outlined,
                      title: '还没有留下足迹',
                      message: '开始一段漫游后，即使只听了部分故事，也会保留在这里。',
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _FootprintSummary(items: items);
                      }
                      return _FootprintCard(item: items[index - 1]);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _FootprintSummary extends StatelessWidget {
  const _FootprintSummary({required this.items});

  final List<JourneyLibraryItem> items;

  @override
  Widget build(BuildContext context) {
    final clues = items.fold<int>(0, (sum, item) => sum + item.collectedCount);
    final photos = items.fold<int>(0, (sum, item) => sum + item.evidenceCount);
    final active = items.where((item) => !item.journey.isCompleted).length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _SummaryValue(value: '${items.length}', label: '段足迹'),
          _SummaryValue(value: '$active', label: '进行中'),
          _SummaryValue(value: '$clues', label: '条线索'),
          _SummaryValue(value: '$photos', label: '张留念'),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.gold)),
            Text(label, style: const TextStyle(color: AppColors.white)),
          ],
        ),
      );
}

class _FootprintCard extends ConsumerWidget {
  const _FootprintCard({required this.item});

  final JourneyLibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context, ref),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialImage(source: item.route.heroImage, height: 158),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.route.title,
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        if (item.route.contentStatus == 'archived')
                          const Chip(label: Text('已归档')),
                        if (!item.journey.isCompleted)
                          const Chip(label: Text('进行中')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.collectedCount}/${item.totalCount} 条线索 · ${item.evidenceCount} 张照片',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_activityLabel(item.journey) != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _activityLabel(item.journey)!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Icon(
                            item.journey.isCompleted
                                ? Icons.replay_rounded
                                : Icons.directions_walk_rounded,
                            size: 18,
                            color: AppColors.moss),
                        const SizedBox(width: 7),
                        Text(item.journey.isCompleted ? '查看足迹并回听故事' : '继续自由漫游'),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (item.journey.isCompleted) {
      context.push('/footprints/${item.journey.id}');
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final key = UserJourneyKey(userId, item.journey.id);
      final ownerContext = await ref.read(journeyContextProvider(key).future);
      if (!context.mounted) return;
      ref
          .read(journeyControllerProvider.notifier)
          .resume(ownerContext.route, ownerContext.journey);
      context.go('/journey/${ownerContext.journey.id}');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('旅程进度暂时无法恢复，请稍后重试')),
      );
    }
  }

  String? _activityLabel(JourneySession journey) {
    final time = journey.updatedAt ?? journey.completedAt ?? journey.startedAt;
    if (time == null) return null;
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '最近活动 ${local.year}-$month-$day';
  }
}

class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          child,
        ],
      );
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 48, color: AppColors.moss),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      );
}
