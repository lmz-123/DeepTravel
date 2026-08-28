import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/primary_action.dart';
import '../domain/models.dart';
import 'experience_providers.dart';

class RecapPage extends ConsumerWidget {
  const RecapPage({required this.journeyId, super.key});
  final String journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref.watch(recapProvider(journeyId));
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: recap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.tonal(
            onPressed: () => ref.invalidate(recapProvider(journeyId)),
            child: const Text('重新生成回顾'),
          ),
        ),
        data: (value) => _RecapContent(
          recap: value,
          journeyId: journeyId,
        ),
      ),
    );
  }
}

class _RecapContent extends StatelessWidget {
  const _RecapContent({required this.recap, required this.journeyId});
  final JourneyRecap recap;
  final String journeyId;

  @override
  Widget build(BuildContext context) {
    final correct = recap.insights.where((item) => item.isCorrect).length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 26, 24, 36),
            color: AppColors.ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: '返回行走',
                      onPressed: () => context.go('/journey/$journeyId'),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.white.withValues(alpha: .1),
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    const BrandMark(light: true),
                  ],
                ),
                const SizedBox(height: 42),
                Text(
                  '行走回顾',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '你走完的不是一条路线，\n而是几种看城市的方式。',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  recap.route.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _Stat(value: '${recap.insights.length}', label: '处停留'),
                    _Stat(value: '$correct', label: '次敏锐观察'),
                    _Stat(value: '${recap.route.distanceKm}', label: '公里漫步'),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          sliver: SliverList.list(
            children: [
              Text('这次行走留下的见识',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppColors.white)),
              const SizedBox(height: 18),
              ...recap.insights.indexed
                  .map((entry) => _Insight(index: entry.$1, item: entry.$2)),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: () => context.go('/footprints'),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('整理这次足迹'),
              ),
              const SizedBox(height: 10),
              PrimaryAction(
                label: '回到发现',
                icon: Icons.explore_outlined,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: AppColors.gold),
          ),
          Text(label, style: const TextStyle(color: AppColors.white)),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({required this.index, required this.item});
  final int index;
  final RecapInsight item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${index + 1}'.padLeft(2, '0'),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: AppColors.terracotta),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(item.insight),
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
