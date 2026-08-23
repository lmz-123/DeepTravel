import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../application/nearby_story_points.dart';
import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'widgets/evidence_photo_widgets.dart';
import 'widgets/narration_voice_selector.dart';
import 'widgets/node_community_section.dart';

class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({required this.journeyId, super.key});
  final String journeyId;

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage> {
  bool _started = false;
  OverlayEntry? _feedbackOverlay;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _clearRootFeedback();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleActiveTourStart();
  }

  void _scheduleActiveTourStart() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final journey = ref.read(journeyControllerProvider);
      if (journey.route?.audioTour != null &&
          journey.session?.id == widget.journeyId) {
        ref
            .read(activeTourControllerProvider.notifier)
            .start(journey.route!, journey.session!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant JourneyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journeyId == widget.journeyId) return;
    _started = false;
    _scheduleActiveTourStart();
  }

  @override
  Widget build(BuildContext context) {
    final legacy = ref.watch(journeyControllerProvider);
    if (legacy.route != null &&
        legacy.session?.id == widget.journeyId &&
        legacy.route!.audioTour == null) {
      return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go('/');
          },
          child: _LegacyJourneyView(state: legacy));
    }
    final state = ref.watch(activeTourControllerProvider);
    if (state.route == null || state.session?.id != widget.journeyId) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/');
        },
        child: Scaffold(
            appBar: AppBar(
                leading: IconButton(
                    tooltip: '返回首页',
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded))),
            body: Center(
                child: state.status == 'preparing'
                    ? const CircularProgressIndicator()
                    : FilledButton(
                        onPressed: () => context.go('/'),
                        child: const Text('从路线详情重新进入')))),
      );
    }
    final manifest = state.route!.audioTour!;
    final ledger = state.ledger;
    final userId = ref.watch(currentUserIdProvider);
    final selectedFragmentId =
        state.selectedFragmentId ?? state.current?.id ?? state.liveFragmentId;
    final selectedFragment = ledger?.entries
        .where((entry) => entry.id == selectedFragmentId && entry.isRevealed)
        .firstOrNull;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              tooltip: '返回首页',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back_rounded)),
          title: const Text('行走中的故事'),
          actions: [
            IconButton(
                tooltip: '故事线索簿',
                onPressed: ledger == null ? null : () => _showLedger(ledger),
                icon: Badge(
                    label: Text('${ledger?.collectedCount ?? 0}'),
                    child: const Icon(Icons.auto_stories_outlined))),
            const SizedBox(width: 8)
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              _StatusPanel(state: state),
              const SizedBox(height: 20),
              Text(manifest.centralQuestion,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              _FragmentRail(manifest: manifest, ledger: ledger),
              const SizedBox(height: 14),
              _SelectedNodeDetail(
                manifest: manifest,
                ledger: ledger,
                selectedFragmentId: selectedFragmentId,
                points: state.nearbyStoryPoints,
                isLoading: state.isBusy || ledger == null,
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  child: state.current == null
                      ? _ListeningCard(
                          key: const ValueKey('listening'), state: state)
                      : _NarrationCard(
                          key: ValueKey(state.current!.id), state: state)),
              if (ledger != null) ...[
                if (selectedFragment?.mission != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child:
                        _MissionCard(fragment: selectedFragment!, state: state),
                  ),
              ],
              if (state.locationMode == TourLocationMode.simulated) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                    onPressed: state.isBusy || state.status != 'simulated'
                        ? null
                        : () => ref
                            .read(activeTourControllerProvider.notifier)
                            .triggerNextDemo(),
                    icon: state.isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                    label: Text(state.isBusy ? '正在确认下一条线索…' : '下一条线索（测试）')),
              ],
              if (state.playbackMode == TourPlaybackMode.liveReplay &&
                  state.liveFragmentId != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => ref
                      .read(activeTourControllerProvider.notifier)
                      .returnToLive(),
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: const Text('回到当前行走进度'),
                ),
              ],
              if (state.errorMessage != null)
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(state.errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              if (userId != null && selectedFragment != null)
                NodeCommunitySection(
                  userId: userId,
                  journeyId: widget.journeyId,
                  fragment: selectedFragment,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLedger(StoryLedger ledger) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .94,
        builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            children: [
              Text('故事线索簿', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                  '${ledger.collectedCount} / ${ledger.totalCount} 条线索已收集。未发现的内容不会提前剧透。'),
              const SizedBox(height: 20),
              _LedgerReconstructionEntry(
                ledger: ledger,
                onPressed: () async {
                  Navigator.pop(context);
                  if (ledger.reconstructionCompleted) {
                    final recap = await ref
                        .read(activeTourControllerProvider.notifier)
                        .loadRecap();
                    if (mounted) _showCompleteStory(recap);
                  } else if (ledger.reconstructionUnlocked) {
                    await _showReconstruction(ledger);
                  }
                },
              ),
              const SizedBox(height: 12),
              ...ledger.entries
                  .map((fragment) => _LedgerEntry(fragment: fragment)),
            ]),
      ),
    );
  }

  Future<void> _showReconstruction(StoryLedger ledger) async {
    if (ledger.reconstructionItems.isEmpty) {
      _showRootFeedback('故事关系还没有从服务器加载完成，请稍后重试。');
      return;
    }
    var values = List<ReconstructionItem>.from(ledger.reconstructionItems);
    var mismatchPositions = <int>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .82,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('拼回完整故事',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text('长按拖动，让这些关系形成有解释力的历史链。'),
                        const SizedBox(height: 16),
                        Expanded(
                            child: ReorderableListView.builder(
                                itemCount: values.length,
                                onReorderItem: (oldIndex, newIndex) {
                                  setSheetState(() {
                                    values.insert(
                                        newIndex, values.removeAt(oldIndex));
                                    mismatchPositions = {};
                                  });
                                },
                                itemBuilder: (context, index) => Card(
                                    key: ValueKey(values[index].id),
                                    color: mismatchPositions.contains(index)
                                        ? Theme.of(context)
                                            .colorScheme
                                            .errorContainer
                                        : null,
                                    shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: mismatchPositions
                                                    .contains(index)
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                : Colors.transparent,
                                            width: 1.5),
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: ListTile(
                                        key: ValueKey(
                                            'reconstruction-${values[index].id}'),
                                        leading: CircleAvatar(
                                            backgroundColor: AppColors.ink,
                                            foregroundColor: AppColors.white,
                                            child: Text('${index + 1}')),
                                        title: Text(values[index].text),
                                        trailing:
                                            const Icon(Icons.drag_handle_rounded))))),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed: () async {
                                  ReconstructionResult result;
                                  try {
                                    result = await ref
                                        .read(activeTourControllerProvider
                                            .notifier)
                                        .reconstruct(values
                                            .map((item) => item.id)
                                            .toList());
                                  } catch (_) {
                                    _showRootFeedback(
                                        '提交失败，当前顺序已经保留，请检查网络后重试。');
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  if (!result.correct) {
                                    setSheetState(() {
                                      mismatchPositions = result.feedback
                                          .map((item) => item['position'])
                                          .whereType<int>()
                                          .map((position) => position - 1)
                                          .where((position) => position >= 0)
                                          .toSet();
                                    });
                                    _showRootFeedback(
                                        '还有 ${result.feedback.length} 处关系没有接上，红色线索的位置需要调整。');
                                    return;
                                  }
                                  _clearRootFeedback();
                                  Navigator.pop(context);
                                  final recap = await ref
                                      .read(
                                          activeTourControllerProvider.notifier)
                                      .loadRecap();
                                  if (mounted) {
                                    _showCompleteStory(recap);
                                  }
                                },
                                child: const Text('提交这条历史因果链'))),
                      ]),
                ),
              )),
    );
  }

  void _showRootFeedback(String message) {
    _clearRootFeedback();
    final overlay = Overlay.of(context, rootOverlay: true);
    _feedbackOverlay = OverlayEntry(
        builder: (context) => Positioned(
              top: MediaQuery.paddingOf(context).top + 14,
              left: 18,
              right: 18,
              child: SafeArea(
                bottom: false,
                child: Semantics(
                  liveRegion: true,
                  button: true,
                  label: message,
                  hint: '轻触关闭',
                  child: GestureDetector(
                    onTap: _clearRootFeedback,
                    child: Material(
                      key: const ValueKey('reconstruction-feedback-overlay'),
                      elevation: 16,
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        child: Row(children: [
                          Icon(Icons.account_tree_rounded,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(message,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ));
    overlay.insert(_feedbackOverlay!);
    _feedbackTimer = Timer(const Duration(seconds: 5), () {
      _feedbackOverlay?.remove();
      _feedbackOverlay = null;
    });
  }

  void _clearRootFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _feedbackOverlay?.remove();
    _feedbackOverlay = null;
  }

  void _showCompleteStory(FragmentRecap recap) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.paper,
        builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .88,
            builder: (context, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 40),
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.moss, size: 42),
                      const SizedBox(height: 12),
                      Text('你拼回了这座城',
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 12),
                      Text(recap.completeStory,
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      const Text('内容状态：研究预览。现场物件与坐标仍待实地核验，来源可在线索簿中查看。'),
                    ])));
  }
}

class _LegacyJourneyView extends ConsumerWidget {
  const _LegacyJourneyView({required this.state});
  final JourneyUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = state.route!;
    final session = state.session!;
    final stop = route.stops[session.currentStopPosition - 1];
    final arrived = session.arrivedStopId == stop.id;
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              tooltip: '返回首页',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back_rounded)),
          title:
              Text('${session.currentStopPosition} / ${route.stops.length}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(stop.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 18),
          if (!arrived)
            FilledButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => ref.read(journeyControllerProvider.notifier).arrive(),
              icon: const Icon(Icons.location_on_rounded),
              label: const Text('我已到达，开始观察'),
            )
          else ...[
            Text(stop.storyTitle,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(stop.storyBody),
            const SizedBox(height: 22),
            const Text('观察一下'),
            const SizedBox(height: 6),
            Text(stop.challenge.prompt,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...stop.challenge.options.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(journeyControllerProvider.notifier)
                      .answer(entry.$1),
                  child: Text(entry.$2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.state});
  final ActiveTourState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoring = state.status == 'monitoring';
    final simulated = state.status == 'simulated';
    final revisiting = state.playbackMode == TourPlaybackMode.revisit;
    final running = monitoring || simulated;
    final label = switch (state.status) {
      'preparing' => '正在准备离线故事',
      'permission_limited' => '自动定位受限',
      'simulated' => '模拟定位中 · 不读取 GPS',
      'paused' => '导览已暂停',
      'stopped' => '导览已停止',
      'revisit' => '足迹回听中 · 不改写进度',
      _ => monitoring ? '正在寻找附近的历史线索' : '正在恢复导览'
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: running ? AppColors.gold : AppColors.terracotta,
                  shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w600))),
          IconButton.filledTonal(
              tooltip: revisiting
                  ? state.isPlaying
                      ? '暂停回听'
                      : '继续回听'
                  : running
                      ? '暂停自动导览'
                      : '继续自动导览',
              onPressed: revisiting
                  ? () => ref
                      .read(activeTourControllerProvider.notifier)
                      .togglePlayback()
                  : running
                      ? () => ref
                          .read(activeTourControllerProvider.notifier)
                          .pauseTour()
                      : () => ref
                          .read(activeTourControllerProvider.notifier)
                          .resumeTour(),
              icon: Icon((revisiting ? state.isPlaying : running)
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded)),
          IconButton(
              tooltip: '停止自动导览',
              color: AppColors.white,
              onPressed: () =>
                  ref.read(activeTourControllerProvider.notifier).stopTour(),
              icon: const Icon(Icons.stop_circle_outlined)),
        ]),
        if (state.locationMessage != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(state.locationMessage!,
                      style: TextStyle(
                          color: AppColors.white.withValues(alpha: .72),
                          height: 1.45)))),
        if (!revisiting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                state.locationMode == TourLocationMode.simulated
                    ? '设置模式：模拟定位'
                    : '设置模式：真实定位',
                style: TextStyle(
                    color: AppColors.white.withValues(alpha: .62),
                    fontSize: 12),
              ),
            ),
          ),
      ]),
    );
  }
}

class _FragmentRail extends ConsumerWidget {
  const _FragmentRail({required this.manifest, required this.ledger});
  final AudioTourManifest manifest;
  final StoryLedger? ledger;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeTourControllerProvider);
    final fragments = manifest.fragments;
    if (fragments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('当前漫游暂无可展示的节点。'),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      const minNodeExtent = 44.0;
      const maxNodeExtent = 56.0;
      const minSpacing = 4.0;
      const maxSpacing = 18.0;
      final count = fragments.length;
      final availableWidth = constraints.maxWidth;
      final minimumWidth = count * minNodeExtent + (count - 1) * minSpacing;
      final scrollable =
          availableWidth.isFinite && minimumWidth > availableWidth;
      final rawExtent = count == 0 || !availableWidth.isFinite
          ? maxNodeExtent
          : (availableWidth - (count - 1) * minSpacing) / count;
      final nodeExtent = scrollable
          ? minNodeExtent
          : rawExtent.clamp(minNodeExtent, maxNodeExtent).toDouble();
      final remaining = availableWidth.isFinite
          ? availableWidth - nodeExtent * count
          : minSpacing * (count - 1);
      final spacing = count <= 1
          ? 0.0
          : scrollable
              ? 8.0
              : (remaining / (count - 1))
                  .clamp(minSpacing, maxSpacing)
                  .toDouble();
      final nodes = <Widget>[];
      for (var index = 0; index < fragments.length; index += 1) {
        final fragment = fragments[index];
        StoryFragment? entry;
        for (final value in ledger?.entries ?? const <StoryFragment>[]) {
          if (value.id == fragment.id) entry = value;
        }
        final collected = entry?.isCollected ?? false;
        final pending = entry?.isMissionPending ?? false;
        final revealed = entry?.isRevealed ?? false;
        final selected = state.selectedFragmentId == fragment.id;
        final live = state.liveFragmentId == fragment.id;
        final action = collected
            ? '回听'
            : revealed
                ? '打开'
                : '查看信息';
        final stateLabel = collected
            ? '已听过'
            : revealed
                ? '已触发'
                : '尚未触发';
        if (index > 0) nodes.add(SizedBox(width: spacing));
        nodes.add(SizedBox(
          width: nodeExtent,
          child: Column(
            children: [
              Semantics(
                button: true,
                selected: selected,
                label:
                    '第 ${fragment.position} 个节点，${fragment.title ?? fragment.safePreview}，$stateLabel${live ? '，当前行走进度' : ''}，$action',
                child: SizedBox.square(
                  dimension: nodeExtent,
                  child: IconButton(
                    tooltip: '$action第 ${fragment.position} 个节点',
                    onPressed: () => ref
                        .read(activeTourControllerProvider.notifier)
                        .selectNode(fragment.id),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.square(nodeExtent),
                      maximumSize: Size.square(nodeExtent),
                      backgroundColor: collected || revealed
                          ? AppColors.moss
                          : pending
                              ? AppColors.terracotta
                              : AppColors.paperDeep,
                      foregroundColor: collected || revealed || pending
                          ? AppColors.white
                          : AppColors.ink,
                      side: BorderSide(
                        color: selected
                            ? AppColors.gold
                            : live
                                ? AppColors.terracotta
                                : Colors.transparent,
                        width: selected || live ? 3 : 1,
                      ),
                    ),
                    icon: Icon(
                      collected
                          ? selected
                              ? Icons.graphic_eq_rounded
                              : Icons.check_rounded
                          : revealed
                              ? Icons.volume_up_outlined
                              : pending
                                  ? Icons.photo_camera_outlined
                                  : Icons.radio_button_unchecked_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('${fragment.position}',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ));
      }
      final rail = Row(mainAxisSize: MainAxisSize.min, children: nodes);
      if (scrollable) {
        return SingleChildScrollView(
          key: const ValueKey('fragment-node-rail-scroll'),
          scrollDirection: Axis.horizontal,
          child: rail,
        );
      }
      return Align(alignment: Alignment.center, child: rail);
    });
  }
}

class _SelectedNodeDetail extends StatelessWidget {
  const _SelectedNodeDetail({
    required this.manifest,
    required this.ledger,
    required this.selectedFragmentId,
    required this.points,
    required this.isLoading,
  });

  final AudioTourManifest manifest;
  final StoryLedger? ledger;
  final String? selectedFragmentId;
  final List<NearbyStoryPoint> points;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (manifest.fragments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('当前漫游暂无可展示的节点内容。'),
        ),
      );
    }
    final effectiveId = manifest.fragments
            .where((fragment) => fragment.id == selectedFragmentId)
            .firstOrNull
            ?.id ??
        manifest.fragments.first.id;
    final manifestFragment =
        manifest.fragments.firstWhere((fragment) => fragment.id == effectiveId);
    final ledgerFragment = ledger?.entries
        .where((fragment) => fragment.id == effectiveId)
        .firstOrNull;
    final point = points
        .where((candidate) => candidate.fragment.id == effectiveId)
        .firstOrNull;
    final fragment = ledgerFragment?.isRevealed == true
        ? ledgerFragment!
        : point?.fragment ?? manifestFragment;
    final status = point?.status ?? NearbyStoryPointStatus.locationUnavailable;
    final durationSeconds = fragment.expectedDurationSeconds;
    final durationMinutes = durationSeconds == null
        ? null
        : (durationSeconds / 60).ceil().clamp(1, 99);
    final revealed = ledgerFragment?.isRevealed ?? false;
    final metadata = <String>[
      if (fragment.displayTheme != null) fragment.displayTheme!,
      if (durationMinutes != null) '约 $durationMinutes 分钟',
      isLoading && point == null ? '正在准备节点状态' : _statusLabel(status),
      if (point?.distanceMeters != null) _distanceLabel(point!.distanceMeters!),
    ];
    return Card(
      key: ValueKey('selected-node-detail-${fragment.id}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(status), color: _statusColor(status)),
                const SizedBox(width: 10),
                Text('节点 ${fragment.position}',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              fragment.title ?? fragment.safePreview,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (fragment.title != null && fragment.safePreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(fragment.safePreview),
            ],
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metadata
                    .map((value) => Chip(label: Text(value)))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              revealed
                  ? '这个节点已经触发，可以在下方播放卡片继续收听或回听。'
                  : '先按自己的方向行走；靠近这个节点后，讲解会自动触发。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(NearbyStoryPointStatus status) => switch (status) {
      NearbyStoryPointStatus.locationUnavailable => '等待定位',
      NearbyStoryPointStatus.outside => '尚未进入范围',
      NearbyStoryPointStatus.approaching => '正在确认位置',
      NearbyStoryPointStatus.inRange => '已进入触发范围',
      NearbyStoryPointStatus.triggered => '已触发，可回听',
      NearbyStoryPointStatus.heard => '已听过，可回听',
    };

IconData _statusIcon(NearbyStoryPointStatus status) => switch (status) {
      NearbyStoryPointStatus.locationUnavailable => Icons.location_off_outlined,
      NearbyStoryPointStatus.outside => Icons.radio_button_unchecked_rounded,
      NearbyStoryPointStatus.approaching => Icons.radar_rounded,
      NearbyStoryPointStatus.inRange => Icons.location_on_outlined,
      NearbyStoryPointStatus.triggered => Icons.volume_up_outlined,
      NearbyStoryPointStatus.heard => Icons.check_circle_outline_rounded,
    };

Color _statusColor(NearbyStoryPointStatus status) => switch (status) {
      NearbyStoryPointStatus.triggered ||
      NearbyStoryPointStatus.inRange =>
        AppColors.terracotta,
      NearbyStoryPointStatus.heard => AppColors.moss,
      _ => AppColors.ink,
    };

String _distanceLabel(double meters) {
  if (meters < 1000) return '${meters.round()} 米';
  return '${(meters / 1000).toStringAsFixed(1)} 公里';
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({required this.state, super.key});
  final ActiveTourState state;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.headphones_rounded,
                size: 36, color: AppColors.moss),
            const SizedBox(height: 16),
            Text('把手机放进口袋', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(state.locationMode == TourLocationMode.simulated
                ? '当前忽略真实位置。需要推进时，点击“模拟到达下一条线索”；故事、拍照和线索簿仍走完整后端流程。'
                : '靠近地点后，需要两次稳定定位才会唤醒故事。耳机断开时音频会先暂停。')
          ])));
}

class _NarrationCard extends ConsumerWidget {
  const _NarrationCard({required this.state, super.key});
  final ActiveTourState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fragment = state.current!;
    final total = state.duration?.inMilliseconds ?? 0;
    final progress = total == 0
        ? 0.0
        : (state.position.inMilliseconds / total).clamp(0.0, 1.0);
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('线索 ${fragment.position} · 研究预览',
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(fragment.title ?? fragment.safePreview,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.white)),
          const SizedBox(height: 16),
          Slider(
              value: progress,
              onChanged: total == 0
                  ? null
                  : (value) => ref
                      .read(activeTourControllerProvider.notifier)
                      .seek(Duration(milliseconds: (total * value).round()))),
          Row(
            children: [
              Text(
                _formatAudioTime(state.position),
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: .72),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                total == 0 ? '--:--' : _formatAudioTime(state.duration!),
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: .72),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [
            IconButton(
                color: AppColors.white,
                tooltip: '重播',
                onPressed: () =>
                    ref.read(activeTourControllerProvider.notifier).replay(),
                icon: const Icon(Icons.replay_rounded)),
            const Spacer(),
            IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink),
                tooltip: state.isPlaying ? '暂停' : '继续',
                onPressed: () => ref
                    .read(activeTourControllerProvider.notifier)
                    .togglePlayback(),
                icon: Icon(state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded)),
            const Spacer(),
            PopupMenuButton<double>(
                initialValue: state.speed,
                tooltip: '速度',
                onSelected: (value) => ref
                    .read(activeTourControllerProvider.notifier)
                    .setSpeed(value),
                itemBuilder: (_) => const [.8, 1.0, 1.2, 1.5]
                    .map((speed) =>
                        PopupMenuItem(value: speed, child: Text('${speed}x')))
                    .toList(),
                child: Text('${state.speed}x',
                    style: const TextStyle(color: AppColors.white))),
            NarrationVoiceIconButton(
              profiles: state.route!.audioTour!.narrationProfiles,
              selectedProfileId: state.narrationProfileId,
              foregroundColor: AppColors.white,
              onSelected: (profileId) => ref
                  .read(activeTourControllerProvider.notifier)
                  .selectNarrationProfile(profileId),
            ),
          ]),
          if (state.narrationProfileMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.narrationProfileMessage!,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: .72),
                  fontSize: 12,
                ),
              ),
            ),
          if (fragment.transcript != null)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: AppColors.white,
                iconColor: AppColors.gold,
                title: const Text('阅读等价文字稿',
                    style: TextStyle(color: AppColors.white)),
                children: [
                  Text(fragment.transcript!,
                      style: TextStyle(
                          color: AppColors.white.withValues(alpha: .82),
                          height: 1.7))
                ]),
          if (state.queue.isNotEmpty)
            Text('另有 ${state.queue.length} 段故事在队列中',
                style: const TextStyle(color: AppColors.gold)),
        ]),
      ),
    );
  }
}

String _formatAudioTime(Duration value) {
  final safeSeconds = value.inSeconds.clamp(0, 359999);
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  String two(int number) => number.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

class _MissionCard extends ConsumerWidget {
  const _MissionCard({required this.fragment, required this.state});
  final StoryFragment fragment;
  final ActiveTourState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = fragment.mission;
    if (mission == null) return const SizedBox.shrink();
    final upload = state.evidenceUploadFor(fragment.id);
    final pendingPath = upload?.filePath;
    final hasPhoto = fragment.evidenceId != null || pendingPath != null;
    final status = upload == null
        ? hasPhoto
            ? '已保存到足迹'
            : '1 个推荐机位 · 可选'
        : _uploadLabel(upload.phase);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('node-photo-entry-${fragment.id}'),
        onTap:
            state.isBusy ? null : () => _showCameraGuide(context, ref, mission),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasPhoto
                    ? AppColors.moss.withValues(alpha: .14)
                    : AppColors.terracotta.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                hasPhoto
                    ? Icons.photo_camera_back_rounded
                    : Icons.add_a_photo_outlined,
                color: hasPhoto ? AppColors.moss : AppColors.terracotta,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('可选的现场留念',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(mission.prompt,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.moss, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }

  Future<void> _showCameraGuide(
    BuildContext context,
    WidgetRef ref,
    PhotoMission mission,
  ) async {
    final pendingPath = state.evidenceUploadFor(fragment.id)?.filePath;
    final shouldCapture = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .9,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            backgroundColor: AppColors.paper,
            leading: IconButton(
              tooltip: '关闭留念详情',
              onPressed: () => Navigator.pop(sheetContext, false),
              icon: const Icon(Icons.close_rounded),
            ),
            title: const Text('现场留念'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            children: [
              Text(mission.prompt,
                  style: Theme.of(sheetContext).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('一个节点只保留这一处留念入口。机位建议用于帮助构图，不是通关条件。'),
              if (pendingPath?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                LocalPhotoThumbnail(
                  path: pendingPath!,
                  title: fragment.title ?? fragment.safePreview,
                  width: 220,
                ),
              ],
              const SizedBox(height: 22),
              Text('推荐机位', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 14),
              _GuideRow(
                icon: Icons.place_outlined,
                label: '站位',
                value: mission.vantagePoint,
              ),
              _GuideRow(
                icon: Icons.explore_outlined,
                label: '朝向',
                value: mission.shootingDirection,
              ),
              _GuideRow(
                icon: Icons.crop_free_rounded,
                label: '构图',
                value: mission.compositionTip,
              ),
              _GuideRow(
                icon: Icons.health_and_safety_outlined,
                label: '安全',
                value: mission.safetyCopy,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(fragment.evidenceId == null ? '打开相机' : '重新拍摄'),
                ),
              ),
              if (state.evidenceUploadFor(fragment.id)?.filePath != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext, false);
                    ref
                        .read(activeTourControllerProvider.notifier)
                        .submitPendingEvidence(fragment);
                  },
                  child: const Text('重试私密上传'),
                ),
            ],
          ),
        ),
      ),
    );
    if (shouldCapture == true) {
      await ref
          .read(activeTourControllerProvider.notifier)
          .captureEvidence(fragment);
    }
  }

  String _uploadLabel(EvidenceUploadPhase phase) => switch (phase) {
        EvidenceUploadPhase.captured => '照片已保存在本机，轻触画框可查看',
        EvidenceUploadPhase.uploading => '正在私密上传，照片仍可查看',
        EvidenceUploadPhase.queued => '等待网络重试，照片仍保留在本机',
        EvidenceUploadPhase.accepted => '已保存到这次足迹',
      };
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.paperDeep,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.terracotta, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LedgerEntry extends StatelessWidget {
  const _LedgerEntry({required this.fragment});
  final StoryFragment fragment;
  @override
  Widget build(BuildContext context) {
    final revealed = fragment.isRevealed;
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          leading: CircleAvatar(
              backgroundColor: fragment.isCollected
                  ? AppColors.moss
                  : fragment.isMissionPending
                      ? AppColors.terracotta
                      : AppColors.paperDeep,
              foregroundColor: fragment.isCollected || fragment.isMissionPending
                  ? AppColors.white
                  : AppColors.ink,
              child: Icon(
                  fragment.isCollected
                      ? Icons.check_rounded
                      : fragment.isMissionPending
                          ? Icons.photo_camera_outlined
                          : Icons.lock_outline_rounded,
                  size: 18)),
          title: Text(revealed ? fragment.title! : '未发现的线索'),
          subtitle: Text(revealed
              ? fragment.keyClaim ?? fragment.safePreview
              : fragment.safePreview),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: revealed
              ? [
                  if (fragment.authenticityLabel != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('现场关系：${fragment.authenticityLabel}',
                            style: Theme.of(context).textTheme.labelMedium)),
                  if (fragment.sources.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...fragment.sources.map((source) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                '${source.publisher}｜${source.title}\n${source.summary}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium))))
                  ]
                ]
              : const [],
        ));
  }
}

class _LedgerReconstructionEntry extends StatelessWidget {
  const _LedgerReconstructionEntry({
    required this.ledger,
    required this.onPressed,
  });
  final StoryLedger ledger;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final completed = ledger.reconstructionCompleted;
    final unlocked = ledger.reconstructionUnlocked;
    return Material(
      color: completed
          ? AppColors.moss.withValues(alpha: .14)
          : unlocked
              ? AppColors.moss
              : AppColors.paperDeep,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: unlocked ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: unlocked ? AppColors.gold : AppColors.white,
              foregroundColor: AppColors.ink,
              child: Icon(completed
                  ? Icons.check_rounded
                  : unlocked
                      ? Icons.account_tree_outlined
                      : Icons.lock_outline_rounded),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completed
                        ? '完整故事已经拼好'
                        : unlocked
                            ? '把线索拼成完整故事'
                            : '完整故事还差一点',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: unlocked && !completed
                          ? AppColors.white
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    completed
                        ? '点开重温你走出来的故事'
                        : unlocked
                            ? '${ledger.totalCount} 条线索已齐，试着排出它们的关系'
                            : '${ledger.collectedCount}/${ledger.totalCount}，收集齐后在这里解锁',
                    style: TextStyle(
                      color: unlocked && !completed
                          ? Colors.white70
                          : AppColors.ink.withValues(alpha: .62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (unlocked)
              Icon(Icons.chevron_right_rounded,
                  color: completed ? AppColors.moss : AppColors.white),
          ]),
        ),
      ),
    );
  }
}
