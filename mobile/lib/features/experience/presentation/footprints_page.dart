import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_back.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/footprint_models.dart';
import 'experience_providers.dart';

class FootprintsPage extends ConsumerWidget {
  const FootprintsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(currentFootprintsProvider);
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
            ref.invalidate(currentFootprintsProvider);
            try {
              await ref.read(currentFootprintsProvider.future);
            } catch (_) {
              // The AsyncValue below retains the last known private records.
            }
          },
          child: result.when(
            skipError: true,
            loading: () =>
                const _ScrollableCenter(child: CircularProgressIndicator()),
            error: (_, __) => _ScrollableCenter(
              child: _Message(
                icon: Icons.cloud_off_outlined,
                title: '足迹暂时没有加载出来',
                message: '下拉刷新，或稍后再回来看看。',
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(currentFootprintsProvider),
                  child: const Text('重新加载'),
                ),
              ),
            ),
            data: (value) => _FootprintList(
              result: value,
              refreshFailed: result.hasError,
            ),
          ),
        ),
      ),
    );
  }
}

class _FootprintList extends ConsumerStatefulWidget {
  const _FootprintList({required this.result, required this.refreshFailed});
  final FootprintPageResult result;
  final bool refreshFailed;

  @override
  ConsumerState<_FootprintList> createState() => _FootprintListState();
}

class _FootprintListState extends ConsumerState<_FootprintList> {
  final List<FootprintEntry> _additional = [];
  bool _loadingMore = false;

  @override
  void didUpdateWidget(covariant _FootprintList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) _additional.clear();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(footprintFilterProvider);
    final hasFilter = filter.citySlug != null ||
        filter.theme != null ||
        filter.journeyState != null ||
        filter.organizationState != null ||
        filter.month != null;
    final items = [...widget.result.items, ..._additional];
    if (items.isEmpty && !hasFilter) {
      return const _ScrollableCenter(
        child: _Message(
          icon: Icons.auto_stories_outlined,
          title: '还没有留下足迹',
          message: '每听到一个故事，就可以保存一段概括、一个现场细节或一句自己的话。',
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 42),
      children: [
        if (widget.refreshFailed) ...[
          MaterialBanner(
            content: const Text('刷新暂时没有成功，下面保留的是上次已加载的私人足迹。'),
            actions: [
              TextButton(
                onPressed: () => ref.invalidate(currentFootprintsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _Summary(result: widget.result),
        const SizedBox(height: 18),
        _Filters(result: widget.result),
        const SizedBox(height: 18),
        if (items.isEmpty)
          _Message(
            icon: Icons.filter_alt_off_outlined,
            title: '这个筛选下还没有足迹',
            message: '清除筛选，可以查看其他城市、主题或时间留下的内容。',
            action: FilledButton.tonal(
              onPressed: () {
                final controller = ref.read(footprintFilterProvider.notifier);
                controller.selectCity(null);
                controller.selectTheme(null);
                controller.selectJourneyState(null);
                controller.selectOrganizationState(null);
                controller.selectMonth(null);
              },
              child: const Text('查看全部'),
            ),
          )
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _FootprintCard(item: item),
              )),
        if (widget.result.nextCursor != null && _additional.isEmpty ||
            _additional.isNotEmpty &&
                _additional.length + widget.result.items.length <
                    widget.result.total)
          Center(
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(_loadingMore ? '加载中…' : '继续查看'),
            ),
          ),
      ],
    );
  }

  Future<void> _loadMore() async {
    var cursor = widget.result.nextCursor;
    if (_additional.isNotEmpty) {
      // The latest response cursor is retained after each successful page below.
      cursor = _nextCursor;
    }
    if (cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(experienceRepositoryProvider)
          .footprints(ref.read(footprintFilterProvider), cursor: cursor);
      if (!mounted) return;
      setState(() {
        final existing = {
          ...widget.result.items.map((item) => item.id),
          ..._additional.map((item) => item.id),
        };
        _additional.addAll(page.items.where((item) => existing.add(item.id)));
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更多足迹暂时没有加载出来')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String? _nextCursor;
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});
  final FootprintPageResult result;

  @override
  Widget build(BuildContext context) {
    final drafts = result.items.where((item) => item.needsOrganization).length;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('这些不是路线成绩，\n是你真正带走的城市印象。',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.white, height: 1.35)),
          const SizedBox(height: 18),
          Text(
            '${result.total} 条记录 · ${result.cities.length} 座城市 · $drafts 条待整理',
            style: const TextStyle(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.result});
  final FootprintPageResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(footprintFilterProvider);
    final controller = ref.read(footprintFilterProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('按城市', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: filter.citySlug == null,
            onSelected: (_) => controller.selectCity(null),
          ),
          for (final city in result.cities)
            ChoiceChip(
              label: Text('${city.name} ${city.count}'),
              selected: filter.citySlug == city.slug,
              onSelected: (_) => controller.selectCity(city.slug),
            ),
        ]),
        if (result.themes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('按主题', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: const Text('全部主题'),
              selected: filter.theme == null,
              onSelected: (_) => controller.selectTheme(null),
            ),
            for (final theme in result.themes)
              ChoiceChip(
                label: Text('${theme.name} ${theme.count}'),
                selected: filter.theme == theme.name,
                onSelected: (_) => controller.selectTheme(theme.name),
              ),
          ]),
        ],
        if (result.months.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('按时间', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: const Text('全部时间'),
              selected: filter.month == null,
              onSelected: (_) => controller.selectMonth(null),
            ),
            for (final month in result.months)
              ChoiceChip(
                label: Text('${month.label} ${month.count}'),
                selected: filter.month == month.key,
                onSelected: (_) => controller.selectMonth(month.key),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text('全部旅程'),
            selected: filter.journeyState == null,
            onSelected: (_) => controller.selectJourneyState(null),
          ),
          ChoiceChip(
            label: const Text('未完成漫游'),
            selected: filter.journeyState == 'partial',
            onSelected: (_) => controller.selectJourneyState('partial'),
          ),
          ChoiceChip(
            label: const Text('待整理'),
            selected: filter.organizationState == 'draft',
            onSelected: (_) => controller.selectOrganizationState(
                filter.organizationState == 'draft' ? null : 'draft'),
          ),
          ActionChip(
            label: Text(filter.order == 'recent' ? '最近留下' : '最早留下'),
            avatar: const Icon(Icons.swap_vert_rounded, size: 17),
            onPressed: () => controller
                .selectOrder(filter.order == 'recent' ? 'oldest' : 'recent'),
          ),
        ]),
      ],
    );
  }
}

class _FootprintCard extends StatelessWidget {
  const _FootprintCard({required this.item});
  final FootprintEntry item;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label:
            '${item.cityName}，${item.storyTitle}，${_date(item.createdAt)}，${item.needsOrganization ? '待整理' : '已整理'}，${item.photo == null ? '无私人照片' : '有私人照片'}',
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/footprints/${item.id}'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${item.cityName} · ${item.sceneTitle}',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    if (item.isPartialJourney) const Chip(label: Text('漫游未完成')),
                  ]),
                  const SizedBox(height: 8),
                  Text(item.storyTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(item.selectedSummaryText ?? item.editorialSummary,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (item.themes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.themes
                          .map((theme) => Chip(label: Text(theme)))
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    Icon(item.photo == null
                        ? Icons.notes_rounded
                        : Icons.photo_outlined),
                    const SizedBox(width: 7),
                    Text(item.needsOrganization ? '稍后再整理' : '已经整理'),
                    const Spacer(),
                    Text(_date(item.createdAt)),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
}

class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * .17),
          child,
        ],
      );
}

class _Message extends StatelessWidget {
  const _Message({
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
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, size: 44, color: AppColors.moss),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]);
}
