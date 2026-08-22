import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/editorial_image.dart';
import '../domain/fragment_models.dart';
import '../domain/models.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'widgets/evidence_photo_widgets.dart';
import 'widgets/node_community_section.dart';

class FootprintDetailPage extends ConsumerWidget {
  const FootprintDetailPage({required this.journeyId, super.key});

  final String journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final key = UserJourneyKey(userId, journeyId);
    final contextValue = ref.watch(journeyContextProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('足迹详情'),
        leading: IconButton(
          tooltip: '返回足迹',
          onPressed: () => context.go('/footprints'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: contextValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailError(
          onRetry: () => ref.invalidate(journeyContextProvider(key)),
        ),
        data: (value) => _DetailContent(
          value: value,
          evidence: ref.watch(journeyEvidenceProvider(key)),
          onRefresh: () async {
            ref.invalidate(journeyContextProvider(key));
            ref.invalidate(journeyEvidenceProvider(key));
            await ref.read(journeyContextProvider(key).future);
          },
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({
    required this.value,
    required this.evidence,
    required this.onRefresh,
  });

  final JourneyContext value;
  final AsyncValue<List<EvidenceRecord>> evidence;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  String? _selectedFragmentId;

  StoryFragment? get _selected {
    final entries = widget.value.ledger?.entries ?? const <StoryFragment>[];
    final revealed = entries.where((entry) => entry.isRevealed).toList();
    if (revealed.isEmpty) return null;
    return revealed.firstWhere(
      (entry) => entry.id == _selectedFragmentId,
      orElse: () => revealed.last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 44),
        children: [
          EditorialImage(source: widget.value.route.heroImage, height: 260),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.value.route.contentStatus == 'archived')
                  const Chip(label: Text('这条路线已归档，足迹仍为你保留')),
                Text(widget.value.route.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 7),
                Text(
                  '${widget.value.collectedCount}/${widget.value.totalCount} 条线索已解锁',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.moss),
                ),
                const SizedBox(height: 26),
                Text(
                    widget.value.journeyKind == 'fragmented'
                        ? '已解锁的线索'
                        : '旅程回顾',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (widget.value.journeyKind == 'fragmented')
                  ...?widget.value.ledger?.entries.map(
                    (fragment) => _ClueRow(
                      fragment: fragment,
                      selected: _selected?.id == fragment.id,
                      onTap: fragment.isRevealed
                          ? () =>
                              setState(() => _selectedFragmentId = fragment.id)
                          : null,
                    ),
                  )
                else
                  ...widget.value.route.stops.map(
                    (stop) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_rounded,
                          color: AppColors.moss),
                      title: Text(stop.title),
                      subtitle: Text(stop.insight),
                    ),
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 24),
                  _SelectedFragmentRecap(
                    fragment: _selected!,
                    onRevisit: () async {
                      await ref
                          .read(activeTourControllerProvider.notifier)
                          .startRevisit(widget.value);
                      await ref
                          .read(activeTourControllerProvider.notifier)
                          .selectCollectedFragment(_selected!.id);
                      if (context.mounted) {
                        context.go('/journey/${widget.value.journey.id}');
                      }
                    },
                  ),
                  const SizedBox(height: 26),
                  Text('这条线索的留念',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                ],
                widget.evidence.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => const _PhotoMessage(
                    icon: Icons.broken_image_outlined,
                    message: '照片暂时无法读取，线索与足迹不受影响。下拉可重试。',
                  ),
                  data: (items) {
                    final matching = _selected == null
                        ? items
                        : items
                            .where((item) => item.fragmentId == _selected!.id)
                            .toList();
                    return matching.isEmpty
                        ? const _PhotoMessage(
                            icon: Icons.photo_outlined,
                            message: '这条线索没有上传照片，完整足迹仍然保留。',
                          )
                        : _EvidenceGallery(
                            value: widget.value, items: matching);
                  },
                ),
                if (_selected != null && userId != null)
                  NodeCommunitySection(
                    userId: userId,
                    journeyId: widget.value.journey.id,
                    fragment: _selected!,
                    evidence: widget.evidence.asData?.value ?? const [],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClueRow extends StatelessWidget {
  const _ClueRow(
      {required this.fragment, required this.selected, required this.onTap});

  final StoryFragment fragment;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        selected: selected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: selected ? AppColors.moss.withValues(alpha: .1) : null,
        leading: CircleAvatar(
          backgroundColor:
              fragment.isRevealed ? AppColors.moss : AppColors.paperDeep,
          foregroundColor: AppColors.white,
          child: Text('${fragment.position}'.padLeft(2, '0')),
        ),
        title: Text(fragment.title ?? fragment.safePreview),
        subtitle: fragment.transcript == null
            ? null
            : Text(fragment.transcript!,
                maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(fragment.isRevealed
            ? Icons.chevron_right_rounded
            : Icons.lock_outline),
        onTap: onTap,
      );
}

class _SelectedFragmentRecap extends StatelessWidget {
  const _SelectedFragmentRecap(
      {required this.fragment, required this.onRevisit});
  final StoryFragment fragment;
  final VoidCallback onRevisit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fragment.title ?? fragment.safePreview,
              style: Theme.of(context).textTheme.titleLarge),
          if (fragment.transcript != null) ...[
            const SizedBox(height: 9),
            Text(fragment.transcript!,
                maxLines: 6, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRevisit,
            icon: const Icon(Icons.headphones_rounded),
            label: const Text('回听这条线索'),
          ),
        ]),
      );
}

class _EvidenceGallery extends ConsumerWidget {
  const _EvidenceGallery({required this.value, required this.items});

  final JourneyContext value;
  final List<EvidenceRecord> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();
    final groups = <String, List<EvidenceRecord>>{};
    for (final item in items) {
      (groups[item.fragmentId ?? 'other'] ??= []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((group) {
        final fragment = value.ledger?.entries
            .where((entry) => entry.id == group.key)
            .firstOrNull;
        final title = fragment?.title ?? fragment?.safePreview ?? '旅途留念';
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 14,
                children: group.value.map((item) {
                  final time = item.capturedAt ?? item.uploadedAt;
                  return SizedBox(
                    width: 142,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EvidenceThumbnail(
                          userId: userId,
                          journeyId: value.journey.id,
                          evidence: item,
                          title: title,
                          width: 136,
                        ),
                        if (time != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 3),
                            child: Text(
                              _formatEvidenceTime(time),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _formatEvidenceTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

class _PhotoMessage extends StatelessWidget {
  const _PhotoMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.moss),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('重新加载这条足迹'),
        ),
      );
}
