import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';

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
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final journey = ref.read(journeyControllerProvider);
      if (journey.route?.audioTour != null && journey.session != null) {
        ref
            .read(activeTourControllerProvider.notifier)
            .start(journey.route!, journey.session!);
      }
    });
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
              Text('你正在追问',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.terracotta)),
              const SizedBox(height: 7),
              Text(manifest.centralQuestion,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              _FragmentRail(manifest: manifest, ledger: ledger),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  child: state.current == null
                      ? _ListeningCard(
                          key: const ValueKey('listening'), state: state)
                      : _NarrationCard(
                          key: ValueKey(state.current!.id), state: state)),
              if (ledger != null) ...[
                ...ledger.entries.where((entry) => entry.isMissionPending).map(
                    (entry) => Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: _MissionCard(fragment: entry, state: state))),
                ...ledger.entries
                    .where((entry) =>
                        entry.isCollected && entry.evidenceId != null)
                    .map((entry) => Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: _EvidenceReceiptCard(
                            fragment: entry, state: state))),
                if (ledger.reconstructionUnlocked)
                  Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: _ReconstructionCard(
                          clueCount: ledger.totalCount,
                          onPressed: () => _showReconstruction(ledger))),
              ],
              if (AppConfig.enableDemoTriggers &&
                  state.locationMode == TourLocationMode.simulated) ...[
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
                    label: Text(state.isBusy ? '正在确认下一条线索…' : '模拟到达下一条线索')),
              ],
              if (state.errorMessage != null)
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(state.errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
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
    final running = monitoring || simulated;
    final label = switch (state.status) {
      'preparing' => '正在准备离线故事',
      'permission_limited' => '自动定位受限',
      'simulated' => '模拟定位中 · 不读取 GPS',
      'paused' => '导览已暂停',
      'stopped' => '导览已停止',
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
              tooltip: running ? '暂停自动导览' : '继续自动导览',
              onPressed: running
                  ? () => ref
                      .read(activeTourControllerProvider.notifier)
                      .pauseTour()
                  : () => ref
                      .read(activeTourControllerProvider.notifier)
                      .resumeTour(),
              icon: Icon(
                  monitoring ? Icons.pause_rounded : Icons.play_arrow_rounded)),
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
        if (AppConfig.enableDemoTriggers) ...[
          const SizedBox(height: 12),
          Divider(color: AppColors.white.withValues(alpha: .16), height: 1),
          const SizedBox(height: 8),
          Semantics(
            label: '模拟定位测试开关',
            hint: state.locationMode == TourLocationMode.simulated
                ? '当前忽略真实位置'
                : '当前使用真实位置',
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('模拟定位（测试）',
                        style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        state.locationMode == TourLocationMode.simulated
                            ? '手动模拟到达，不申请定位权限'
                            : '读取真实位置，稳定靠近后触发',
                        style: TextStyle(
                            color: AppColors.white.withValues(alpha: .66),
                            fontSize: 12)),
                  ])),
              Switch.adaptive(
                  value: state.locationMode == TourLocationMode.simulated,
                  onChanged: state.isBusy || state.status == 'preparing'
                      ? null
                      : (value) => ref
                          .read(activeTourControllerProvider.notifier)
                          .setLocationMode(value
                              ? TourLocationMode.simulated
                              : TourLocationMode.real)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _FragmentRail extends StatelessWidget {
  const _FragmentRail({required this.manifest, required this.ledger});
  final AudioTourManifest manifest;
  final StoryLedger? ledger;
  @override
  Widget build(BuildContext context) => Row(
          children: manifest.fragments.map((fragment) {
        StoryFragment? entry;
        for (final value in ledger?.entries ?? const <StoryFragment>[]) {
          if (value.id == fragment.id) entry = value;
        }
        final collected = entry?.isCollected ?? false;
        final pending = entry?.isMissionPending ?? false;
        return Expanded(
            child: Column(children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: collected
                      ? AppColors.moss
                      : pending
                          ? AppColors.terracotta
                          : AppColors.paperDeep,
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(
                  collected
                      ? Icons.check_rounded
                      : pending
                          ? Icons.photo_camera_outlined
                          : Icons.lock_outline_rounded,
                  color: collected || pending ? AppColors.white : AppColors.ink,
                  size: 17)),
          const SizedBox(height: 6),
          Text('${fragment.position}',
              style: Theme.of(context).textTheme.labelMedium)
        ]));
      }).toList());
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
          ]),
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
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.camera_alt_outlined, color: AppColors.terracotta),
                SizedBox(width: 8),
                Text('可以稍后完成的现场任务')
              ]),
              const SizedBox(height: 14),
              Text(mission.prompt,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(mission.safetyCopy,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (pendingPath != null && File(pendingPath).existsSync())
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(pendingPath),
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover))),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: state.isBusy
                          ? null
                          : () => ref
                              .read(activeTourControllerProvider.notifier)
                              .captureEvidence(fragment),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(pendingPath == null ? '拍摄并检查线索' : '重拍线索'))),
              if (pendingPath != null)
                SizedBox(
                    width: double.infinity,
                    child: TextButton(
                        onPressed: state.isBusy
                            ? null
                            : () => ref
                                .read(activeTourControllerProvider.notifier)
                                .submitPendingEvidence(fragment),
                        child: Text(
                            upload?.phase == EvidenceUploadPhase.uploading
                                ? '正在处理照片…'
                                : '重试私密上传'))),
            ])));
  }
}

class _EvidenceReceiptCard extends StatelessWidget {
  const _EvidenceReceiptCard({required this.fragment, required this.state});
  final StoryFragment fragment;
  final ActiveTourState state;

  @override
  Widget build(BuildContext context) {
    final upload = state.evidenceUploadFor(fragment.id);
    final path = upload?.filePath;
    final hasLocalPreview = path != null && File(path).existsSync();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.moss.withValues(alpha: .12),
          border: Border.all(color: AppColors.moss.withValues(alpha: .28)),
          borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        if (hasLocalPreview)
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(path),
                  width: 72, height: 72, fit: BoxFit.cover))
        else
          Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.moss.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.moss)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('现场照片已确认', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(fragment.title ?? fragment.safePreview,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 5),
          const Text('仅保存在你的旅程中',
              style: TextStyle(color: AppColors.moss, fontSize: 12)),
        ])),
        const Icon(Icons.check_circle_rounded, color: AppColors.moss),
      ]),
    );
  }
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

class _ReconstructionCard extends StatelessWidget {
  const _ReconstructionCard({required this.clueCount, required this.onPressed});
  final int clueCount;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: AppColors.moss, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.account_tree_outlined,
            color: AppColors.white, size: 32),
        const SizedBox(height: 12),
        Text('$clueCount 条线索已经齐了',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppColors.white)),
        const SizedBox(height: 8),
        const Text('把年代知识拼成一条真正的因果故事。',
            style: TextStyle(color: AppColors.white)),
        const SizedBox(height: 16),
        FilledButton.tonal(onPressed: onPressed, child: const Text('开始重构故事'))
      ]));
}
