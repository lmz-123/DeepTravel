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
      body: recap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.tonal(
            onPressed: () => ref.invalidate(recapProvider(journeyId)),
            child: const Text('重新生成回顾'),
          ),
        ),
        data: (value) => _RecapContent(recap: value),
      ),
    );
  }
}

class _RecapContent extends StatelessWidget {
  const _RecapContent({required this.recap});
  final JourneyRecap recap;

  @override
  Widget build(BuildContext context) {
    final correct = recap.insights.where((item) => item.isCorrect).length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 26, 24, 36),
            decoration: const BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(light: true),
                const SizedBox(height: 46),
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                      color: AppColors.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.ink, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  '你不只是来过，\n还读懂了一点。',
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
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
          sliver: SliverList.list(
            children: [
              Text('你带走的五条见识',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              ...recap.insights.indexed
                  .map((entry) => _Insight(index: entry.$1, item: entry.$2)),
              const SizedBox(height: 16),
              PrimaryAction(
                label: '回到发现页',
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
      child: Card(
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
