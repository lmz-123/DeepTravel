import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_back.dart';
import '../../../core/theme/app_theme.dart';
import '../data/footprint_share_service.dart';
import '../domain/footprint_models.dart';
import 'experience_providers.dart';
import 'widgets/traveler_bottom_navigation.dart';

class FootprintDetailPage extends ConsumerWidget {
  const FootprintDetailPage({required this.footprintId, super.key});
  final String footprintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(footprintEditorControllerProvider(footprintId));
    return RouteBackScope(
      fallbackLocation: '/footprints',
      child: Scaffold(
        bottomNavigationBar: const TravelerBottomNavigation(
          active: TravelerSection.footprints,
        ),
        appBar: AppBar(
          title: const Text('足迹详情'),
          leading: IconButton(
            tooltip: '返回足迹',
            onPressed: () => popOrGo(context, '/footprints'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: FilledButton.tonal(
              onPressed: () => ref
                  .invalidate(footprintEditorControllerProvider(footprintId)),
              child: const Text('重新加载这条足迹'),
            ),
          ),
          data: (entry) => _FootprintEditor(entry: entry),
        ),
      ),
    );
  }
}

class _FootprintEditor extends ConsumerStatefulWidget {
  const _FootprintEditor({required this.entry});
  final FootprintEntry entry;

  @override
  ConsumerState<_FootprintEditor> createState() => _FootprintEditorState();
}

class _FootprintEditorState extends ConsumerState<_FootprintEditor> {
  late final TextEditingController _observation;
  late final TextEditingController _sentence;
  String? _selectedSummaryId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _observation = TextEditingController(text: widget.entry.observation);
    _sentence = TextEditingController(text: widget.entry.sentence);
    _selectedSummaryId = widget.entry.selectedSummaryId;
  }

  @override
  void didUpdateWidget(covariant _FootprintEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.updatedAt != widget.entry.updatedAt) {
      _observation.text = widget.entry.observation ?? '';
      _sentence.text = widget.entry.sentence ?? '';
      _selectedSummaryId = widget.entry.selectedSummaryId;
    }
  }

  @override
  void dispose() {
    _observation.dispose();
    _sentence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(footprintEditorControllerProvider(entry.id));
        await ref.read(footprintEditorControllerProvider(entry.id).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
        children: [
          Container(
            height: 270,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (entry.photo != null)
                  _PrivateFootprintPhoto(entry: entry, fill: true),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22142B33), Color(0xEE142B33)],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton.filledTonal(
                    tooltip: '生成分享卡',
                    onPressed: _busy ? null : () => _share(entry),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.white.withValues(alpha: .14),
                      foregroundColor: AppColors.white,
                    ),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 21,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.cityName} · ${entry.sceneTitle}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.gold,
                                  letterSpacing: 1,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.storyTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppColors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (entry.isPartialJourney) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _resumeJourney(entry),
              icon: const Icon(Icons.directions_walk_rounded),
              label: const Text('继续这次未完成的漫游'),
            ),
          ],
          const SizedBox(height: 24),
          _Section(
            eyebrow: '见地讲述',
            title: '经过审核的事实与故事概括',
            child: Text(entry.editorialSummary,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.65)),
          ),
          const SizedBox(height: 18),
          _Section(
            eyebrow: '我看到的',
            title: '现场观察与私人照片',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.photo != null) ...[
                  _PrivateFootprintPhoto(entry: entry),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _deletePhoto(entry),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('移除私人照片'),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.paperDeep,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text('照片是可选的，只作为你的私人留念。'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickPhoto(entry),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(entry.photo == null ? '拍一张私人留念' : '更换私人照片'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _observation,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '我看到的细节（可选）',
                    hintText: '一句话就够了，例如：墙脚有一段颜色更浅的旧砖。',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            eyebrow: '我留下的',
            title: '选择一种概括，或写下自己的短句',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: RadioGroup<String>(
                    groupValue: _selectedSummaryId,
                    onChanged: _busy
                        ? (_) {}
                        : (value) => setState(() => _selectedSummaryId = value),
                    child: Column(
                      children: [
                        for (final option in entry.summaryOptions)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: option.id,
                            title: Text(option.text),
                          ),
                        if (_selectedSummaryId != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                      setState(() => _selectedSummaryId = null),
                              child: const Text('清除已选概括'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: _sentence,
                  maxLength: 160,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '我留下的一句话（可选）',
                    hintText: '不用写长文字。',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _save(entry, defer: true),
                child: const Text('稍后再整理'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _save(entry),
                child: Text(_busy ? '保存中…' : '保存足迹'),
              ),
            ),
          ]),
          const SizedBox(height: 28),
          _RelatedContent(footprintId: entry.id),
        ],
      ),
    );
  }

  Future<void> _save(FootprintEntry entry, {bool defer = false}) async {
    setState(() => _busy = true);
    try {
      await ref.read(footprintEditorControllerProvider(entry.id).notifier).save(
            FootprintDraft(
              selectedSummaryId: _selectedSummaryId,
              observation: _observation.text,
              sentence: _sentence.text,
              deferOrganization: defer,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(defer ? '已经保留，之后可以继续整理' : '足迹已经保存')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂时没有保存成功，你写的内容仍留在页面上')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto(FootprintEntry entry) async {
    final path =
        await ref.read(footprintPhotoPickerProvider).pickPrivateKeepsake();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(footprintEditorControllerProvider(entry.id).notifier)
          .uploadPhoto(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('照片暂时没有保存成功，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePhoto(FootprintEntry entry) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(footprintEditorControllerProvider(entry.id).notifier)
          .deletePhoto();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resumeJourney(FootprintEntry entry) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      final owner = await ref.read(
          journeyContextProvider(UserJourneyKey(userId, entry.journeyId))
              .future);
      if (!mounted) return;
      ref
          .read(journeyControllerProvider.notifier)
          .resume(owner.route, owner.journey);
      context.go('/journey/${entry.journeyId}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('漫游进度暂时无法恢复，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(FootprintEntry entry) async {
    var includePhoto = false;
    if (entry.photo != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('生成足迹卡'),
          content: const Text('私人照片默认不会加入分享卡。你可以明确选择是否带上这张照片。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('不带照片')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('带上照片')),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      includePhoto = choice;
    }
    setState(() => _busy = true);
    try {
      Uint8List? photoBytes;
      final userId = ref.read(currentUserIdProvider);
      if (includePhoto && entry.photo != null && userId != null) {
        photoBytes = await ref.read(footprintPhotoBytesProvider(
          FootprintPhotoBytesKey(userId, entry.id, entry.photo!),
        ).future);
      }
      await ref.read(footprintShareServiceProvider).share(
            entry,
            explicitlyIncludedPhoto: photoBytes,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('分享卡暂时没有生成成功')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.eyebrow, required this.title, required this.child});
  final String eyebrow;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.ink.withValues(alpha: .08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.moss)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class _PrivateFootprintPhoto extends ConsumerWidget {
  const _PrivateFootprintPhoto({required this.entry, this.fill = false});
  final FootprintEntry entry;
  final bool fill;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final photo = entry.photo;
    if (userId == null || photo == null) return const SizedBox.shrink();
    final bytes = ref.watch(footprintPhotoBytesProvider(
        FootprintPhotoBytesKey(userId, entry.id, photo)));
    final image = bytes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const ColoredBox(
        color: AppColors.paperDeep,
        child: Center(child: Text('私人照片暂时无法读取')),
      ),
      data: (value) => Image.memory(value, fit: BoxFit.cover),
    );
    if (fill) return SizedBox.expand(child: image);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: 4 / 3, child: image),
    );
  }
}

class _RelatedContent extends ConsumerWidget {
  const _RelatedContent({required this.footprintId});
  final String footprintId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(footprintRelatedContentProvider(footprintId));
    return value.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('还可以读读这座城市', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .92,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Material(
                    color: index.isEven ? AppColors.ink : AppColors.moss,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/story/${item.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_stories_outlined,
                              color: AppColors.gold,
                            ),
                            const Spacer(),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              item.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: .68),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ]),
    );
  }
}
