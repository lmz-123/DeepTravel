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
import 'widgets/editorial_listening.dart';
import 'widgets/location_mode_selector.dart';
import 'widgets/narration_voice_selector.dart';
import 'widgets/node_community_section.dart';
import 'widgets/route_canvas.dart';
import 'widgets/traveler_bottom_navigation.dart';

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
  String _directoryQuery = '';
  int _directoryPage = 0;

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
        child: _LegacyJourneyView(state: legacy),
      );
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
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: Center(
            child: state.status == 'preparing'
                ? const CircularProgressIndicator()
                : FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('从路线详情重新进入'),
                  ),
          ),
        ),
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
        bottomNavigationBar: TravelerBottomNavigation(
          active: TravelerSection.journey,
          journeyId: widget.journeyId,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _JourneyMapHeader(
                routeTitle: state.route!.title,
                fragments: manifest.fragments,
                ledger: ledger,
                points: state.nearbyStoryPoints,
                userLocation: state.latestLocationSample,
                selectedFragmentId: selectedFragmentId,
                collectedCount: ledger?.collectedCount ?? 0,
                onBack: () => context.go('/'),
                onLedger: ledger == null ? null : () => _showLedger(ledger),
                onSelectNode: (fragmentId) => _showNodePrelude(fragmentId),
              ),
              Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 44),
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIELD NOTES / 沿途的见地',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.terracotta,
                              fontSize: 9,
                              letterSpacing: 1.1,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        manifest.centralQuestion,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontFamily: 'Noto Serif SC',
                              fontSize: 27,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _SelectedNodeDetail(
                        manifest: manifest,
                        ledger: ledger,
                        selectedFragmentId: selectedFragmentId,
                        points: state.nearbyStoryPoints,
                        isLoading: state.isBusy || ledger == null,
                      ),
                      const SizedBox(height: 13),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        child: state.current == null
                            ? _ListeningCard(
                                key: const ValueKey('listening'),
                                state: state,
                              )
                            : _NarrationCard(
                                key: ValueKey(state.current!.id),
                                state: state,
                                onDirectory: ledger == null
                                    ? null
                                    : () => _showLedger(ledger),
                              ),
                      ),
                      if (ledger != null && selectedFragment?.mission != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: _MissionCard(
                            fragment: selectedFragment!,
                            state: state,
                          ),
                        ),
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
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (userId != null && selectedFragment != null)
                        NodeCommunitySection(
                          userId: userId,
                          journeyId: widget.journeyId,
                          fragment: selectedFragment,
                        ),
                      const SizedBox(height: 13),
                      LocationModeSelector(
                        keyPrefix: 'journey-mode',
                        value: state.locationMode,
                        onChanged: (mode) => ref
                            .read(activeTourControllerProvider.notifier)
                            .setLocationMode(mode),
                      ),
                      if (state.locationMode == TourLocationMode.simulated) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                state.isBusy || state.status != 'simulated'
                                    ? null
                                    : () => ref
                                        .read(
                                          activeTourControllerProvider.notifier,
                                        )
                                        .triggerNextDemo(),
                            icon: state.isBusy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded),
                            label: Text(
                              state.isBusy ? '正在确认下一条线索…' : '下一条线索（测试）',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNodePrelude(
    String fragmentId, {
    bool fromDirectory = false,
  }) async {
    final tour = ref.read(activeTourControllerProvider);
    final fragment = tour.ledger?.entries
        .where((entry) => entry.id == fragmentId && entry.isRevealed)
        .firstOrNull;
    if (fragment == null) return;
    await ref.read(activeTourControllerProvider.notifier).pauseTour();
    if (!mounted) return;
    var reading = false;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: editorialPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 31,
                  height: 3,
                  margin: const EdgeInsets.only(top: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xffb5b3a5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      if (fromDirectory)
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pop(sheetContext, 'directory'),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text(
                            '返回目录',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '第 ${fragment.position.toString().padLeft(2, '0')} 篇',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xff7c725f),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭章节序页',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, size: 19),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tour.route!.title,
                          style: const TextStyle(
                            color: Color(0xff8a7c68),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(
                          reading ? fragment.title! : '先停一停，\n再翻这一页。',
                          style: editorialSerif(
                            reading ? 31 : 37,
                            color: editorialInk,
                          ).copyWith(height: 1.45, letterSpacing: -1.8),
                        ),
                        const SizedBox(height: 24),
                        if (!reading)
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(58),
                                  topRight: Radius.circular(58),
                                  bottomLeft: Radius.circular(3),
                                  bottomRight: Radius.circular(3),
                                ),
                                child: SizedBox(
                                  width: 106,
                                  height: 151,
                                  child: tour.route!.heroImage.isEmpty
                                      ? const ColoredBox(
                                          color: Color(0xffd9ddc2),
                                        )
                                      : Image.network(
                                          tour.route!.heroImage,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const ColoredBox(
                                            color: Color(0xffd9ddc2),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fragment.expectedDurationSeconds == null
                                          ? '沿途故事'
                                          : '约 ${(fragment.expectedDurationSeconds! / 60).ceil()} 分钟',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xff95806a),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      fragment.title!,
                                      style: editorialSerif(
                                        21,
                                        color: editorialInk,
                                      ).copyWith(height: 1.55),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      fragment.safePreview,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        height: 1.7,
                                        color: Color(0xff817763),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          SelectableText(
                            fragment.transcript ?? fragment.safePreview,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 2,
                              color: editorialInk,
                            ),
                          ),
                          if (fragment.authenticityLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                '现场关系：${fragment.authenticityLabel}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.8,
                                  color: Color(0xff817763),
                                ),
                              ),
                            ),
                          ...fragment.sources.map(
                            (source) => Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                '${source.publisher}｜${source.title}\n${source.summary}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.8,
                                  color: Color(0xff817763),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 22, 0, 11),
                          child: Text(
                            '听一段，或读一页。按自己的节奏慢慢走。',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.7,
                              color: Color(0xff827563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 15, 25, 18),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, 'listen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xffbc4432),
                            foregroundColor: const Color(0xfffff8e9),
                            minimumSize: const Size(48, 60),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(22),
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                fragment.position.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 25,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xfff0c4a2),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text('播放这一篇', style: editorialSerif(17)),
                              ),
                              const Icon(Icons.play_circle_outline, size: 33),
                            ],
                          ),
                        ),
                      ),
                      if (!reading)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0x7077725b)),
                            ),
                          ),
                        ),
                      if (!reading)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => update(() => reading = true),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 50),
                              foregroundColor: const Color(0xff626451),
                              padding: EdgeInsets.zero,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_outlined, size: 17),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    '阅读这一篇',
                                    style: editorialSerif(
                                      15,
                                      color: const Color(0xff626451),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward, size: 17),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'listen') {
      await ref
          .read(activeTourControllerProvider.notifier)
          .selectNode(fragment.id);
    } else if (result == 'directory' || (result == null && fromDirectory)) {
      final ledger = ref.read(activeTourControllerProvider).ledger;
      if (ledger != null) _showLedger(ledger);
    }
  }

  Future<void> _showLedger(StoryLedger ledger) async {
    await ref.read(activeTourControllerProvider.notifier).pauseTour();
    if (!mounted) return;
    final queryController = TextEditingController(text: _directoryQuery);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: editorialPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          final entries = ledger.entries
              .where(
                (entry) =>
                    '${entry.position} ${entry.title ?? ''} ${entry.safePreview}'
                        .contains(_directoryQuery.trim()),
              )
              .toList();
          final pages = (entries.length / 12).ceil().clamp(1, 100000);
          final page = _directoryPage.clamp(0, pages - 1);
          final visible = entries.skip(page * 12).take(12).toList();
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .9,
              child: Column(
                children: [
                  Container(
                    width: 31,
                    height: 3,
                    margin: const EdgeInsets.only(top: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xffb5b3a5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 14, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '沿途目录',
                            style: editorialSerif(32, color: editorialInk),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭目录',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ledger.collectedCount} / ${ledger.totalCount} 条线索已收集 · 未发现的故事，留给现场',
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.7,
                            color: Color(0xff827563),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: queryController,
                          onChanged: (value) => update(() {
                            _directoryQuery = value;
                            _directoryPage = 0;
                          }),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: '按篇名、地点或页码寻找',
                            prefixIcon: Icon(Icons.search, size: 19),
                            filled: false,
                            border: UnderlineInputBorder(),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0x55252824)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                      children: [
                        if (_directoryQuery.isEmpty) ...[
                          _LedgerReconstructionEntry(
                            ledger: ledger,
                            onPressed: () async {
                              Navigator.pop(sheetContext);
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
                          const SizedBox(height: 16),
                        ],
                        if (entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text('还没找到这一页，换个词试试。'),
                          ),
                        ...visible.map(
                          (fragment) => _LedgerEntry(
                            fragment: fragment,
                            onPressed: fragment.isRevealed
                                ? () {
                                    Navigator.pop(sheetContext);
                                    _showNodePrelude(
                                      fragment.id,
                                      fromDirectory: true,
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: '上一页目录',
                            onPressed: page == 0
                                ? null
                                : () => update(() => _directoryPage = page - 1),
                            icon: const Icon(Icons.arrow_back, size: 19),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '第 ${page + 1} / $pages 页 · 每页 12 篇',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '下一页目录',
                            onPressed: page == pages - 1
                                ? null
                                : () => update(() => _directoryPage = page + 1),
                            icon: const Icon(Icons.arrow_forward, size: 19),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    queryController.dispose();
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
                Text(
                  '拼回完整故事',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('长按拖动，让这些关系形成有解释力的历史链。'),
                const SizedBox(height: 16),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: values.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setSheetState(() {
                        values.insert(newIndex, values.removeAt(oldIndex));
                        mismatchPositions = {};
                      });
                    },
                    itemBuilder: (context, index) => Card(
                      key: ValueKey(values[index].id),
                      color: mismatchPositions.contains(index)
                          ? Theme.of(context).colorScheme.errorContainer
                          : null,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: mismatchPositions.contains(index)
                              ? Theme.of(context).colorScheme.error
                              : Colors.transparent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        key: ValueKey('reconstruction-${values[index].id}'),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.white,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(values[index].text),
                        trailing: const Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      ReconstructionResult result;
                      try {
                        result = await ref
                            .read(activeTourControllerProvider.notifier)
                            .reconstruct(
                              values.map((item) => item.id).toList(),
                            );
                      } catch (_) {
                        _showRootFeedback('提交失败，当前顺序已经保留，请检查网络后重试。');
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
                          '还有 ${result.feedback.length} 处关系没有接上，红色线索的位置需要调整。',
                        );
                        return;
                      }
                      _clearRootFeedback();
                      Navigator.pop(context);
                      final recap = await ref
                          .read(activeTourControllerProvider.notifier)
                          .loadRecap();
                      if (mounted) {
                        _showCompleteStory(recap);
                      }
                    },
                    child: const Text('提交这条历史因果链'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_tree_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.moss,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text('你拼回了这座城', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 12),
            Text(
              recap.completeStory,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const Text('内容状态：研究预览。现场物件与坐标仍待实地核验，来源可在线索簿中查看。'),
          ],
        ),
      ),
    );
  }
}

class _JourneyMapHeader extends StatelessWidget {
  const _JourneyMapHeader({
    required this.routeTitle,
    required this.fragments,
    required this.ledger,
    required this.points,
    required this.userLocation,
    required this.selectedFragmentId,
    required this.collectedCount,
    required this.onBack,
    required this.onLedger,
    required this.onSelectNode,
  });

  final String routeTitle;
  final List<StoryFragment> fragments;
  final StoryLedger? ledger;
  final List<NearbyStoryPoint> points;
  final LocationSample? userLocation;
  final String? selectedFragmentId;
  final int collectedCount;
  final VoidCallback onBack;
  final VoidCallback? onLedger;
  final ValueChanged<String> onSelectNode;

  @override
  Widget build(BuildContext context) => Container(
        height: 390 + MediaQuery.paddingOf(context).top,
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 10,
          16,
          24,
        ),
        color: AppColors.paper,
        child: Column(
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '返回首页',
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.paperDeep,
                    foregroundColor: AppColors.ink,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    routeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.ink, fontSize: 16),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '故事线索簿',
                  onPressed: onLedger,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.paperDeep,
                    foregroundColor: AppColors.ink,
                  ),
                  icon: Badge(
                    label: Text('$collectedCount'),
                    child: const Icon(Icons.auto_stories_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Expanded(
              child: _JourneyRouteSelector(
                fragments: fragments,
                ledger: ledger,
                points: points,
                userLocation: userLocation,
                selectedFragmentId: selectedFragmentId,
                onSelectNode: onSelectNode,
              ),
            ),
          ],
        ),
      );
}

class _JourneyRouteSelector extends StatelessWidget {
  const _JourneyRouteSelector({
    required this.fragments,
    required this.ledger,
    required this.points,
    required this.userLocation,
    required this.selectedFragmentId,
    required this.onSelectNode,
  });

  final List<StoryFragment> fragments;
  final StoryLedger? ledger;
  final List<NearbyStoryPoint> points;
  final LocationSample? userLocation;
  final String? selectedFragmentId;
  final ValueChanged<String> onSelectNode;

  @override
  Widget build(BuildContext context) {
    final revealedIds = ledger?.entries
            .where((entry) => entry.isRevealed)
            .map((entry) => entry.id)
            .toSet() ??
        const <String>{};
    final effectiveSelectedId = revealedIds.contains(selectedFragmentId)
        ? selectedFragmentId
        : fragments
            .where((fragment) => revealedIds.contains(fragment.id))
            .firstOrNull
            ?.id;
    final canvasPoints = fragments.map((fragment) {
      final ledgerEntry =
          ledger?.entries.where((entry) => entry.id == fragment.id).firstOrNull;
      final nearbyPoint = points
          .where((candidate) => candidate.fragment.id == fragment.id)
          .firstOrNull;
      final collected = ledgerEntry?.isCollected ?? false;
      final revealed = ledgerEntry?.isRevealed ?? false;
      final nearby = nearbyPoint?.status == NearbyStoryPointStatus.inRange ||
          nearbyPoint?.status == NearbyStoryPointStatus.approaching;
      final stateLabel = collected
          ? '已听过'
          : nearby
              ? '已接近'
              : revealed
                  ? '已触发'
                  : '未解锁';
      return RouteCanvasPoint(
        id: fragment.id,
        label: fragment.title ?? fragment.safePreview,
        latitude: fragment.triggerRegion.latitude,
        longitude: fragment.triggerRegion.longitude,
        triggerRadiusM: fragment.triggerRegion.entryRadiusM.toDouble(),
        enabled: revealed,
        semanticsLabel:
            '第 ${fragment.position} 个节点，${fragment.title ?? fragment.safePreview}，$stateLabel',
        tooltip: revealed
            ? '查看第 ${fragment.position} 个节点'
            : '第 ${fragment.position} 个节点尚未解锁',
        markerColor: collected
            ? AppColors.moss
            : nearby
                ? AppColors.terracotta
                : revealed
                    ? AppColors.gold
                    : null,
      );
    }).toList(growable: false);

    return RouteCanvas(
      points: canvasPoints,
      height: null,
      userLocation: userLocation,
      selectedPointId: effectiveSelectedId,
      nodeKeyPrefix: 'journey-node-',
      nodeDotKeyPrefix: 'journey-node-dot-',
      onPointSelected: (point) => onSelectNode(point.id),
    );
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
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('${session.currentStopPosition} / ${route.stops.length}'),
      ),
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
            Text(
              stop.storyTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(stop.storyBody),
            const SizedBox(height: 22),
            const Text('观察一下'),
            const SizedBox(height: 6),
            Text(
              stop.challenge.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
    final manifestFragment = manifest.fragments.firstWhere(
      (fragment) => fragment.id == effectiveId,
    );
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
    final metadata = <String>[
      if (durationMinutes != null) '约 $durationMinutes 分钟',
      if (isLoading && point == null) '正在准备节点状态',
      ...fragment.experienceTags,
    ];
    return Container(
      key: ValueKey('selected-node-detail-${fragment.id}'),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.ink.withValues(alpha: .22)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '节点 ${fragment.position}${fragment.displayTheme == null ? '' : ' · ${fragment.displayTheme}'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.terracotta,
                        fontSize: 9,
                        letterSpacing: 0,
                      ),
                ),
              ),
              Text(
                point?.distanceMeters == null
                    ? _statusLabel(status)
                    : _distanceLabel(point!.distanceMeters!),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: _statusColor(status), fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fragment.title ?? fragment.safePreview,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontSize: 19, height: 1.35),
          ),
          if (fragment.title != null && fragment.safePreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              fragment.safePreview,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    height: 1.6,
                  ),
            ),
          ],
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: metadata
                  .map(
                    (value) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paperDeep,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        value,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontSize: 10, letterSpacing: 0),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
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

class _ListeningCard extends ConsumerWidget {
  const _ListeningCard({required this.state, super.key});
  final ActiveTourState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revisiting = state.playbackMode == TourPlaybackMode.revisit;
    final running = state.status == 'monitoring' || state.status == 'simulated';
    final playing = revisiting ? state.isPlaying : running;
    final title = switch (state.status) {
      'preparing' => '正在准备沿途讲述',
      'permission_limited' => '等待你允许定位',
      'simulated' => '正在模拟寻找下一条线索',
      'paused' => '自动导览已暂停',
      'stopped' => '自动导览已停止',
      'revisit' => '正在回听这段足迹',
      _ => '正在寻找附近的历史线索',
    };
    return _DarkNarrationSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NarrationPlayButton(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: revisiting
                    ? playing
                        ? '暂停回听'
                        : '继续回听'
                    : playing
                        ? '暂停自动导览'
                        : '继续自动导览',
                onPressed: revisiting
                    ? () => ref
                        .read(activeTourControllerProvider.notifier)
                        .togglePlayback()
                    : playing
                        ? () => ref
                            .read(activeTourControllerProvider.notifier)
                            .pauseTour()
                        : () => ref
                            .read(activeTourControllerProvider.notifier)
                            .resumeTour(),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.locationMessage ??
                          (state.locationMode == TourLocationMode.simulated
                              ? '无需 GPS，手动推进节点'
                              : '靠近节点后自动唤醒故事'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: .65),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '停止自动导览',
                color: AppColors.white.withValues(alpha: .75),
                onPressed: () =>
                    ref.read(activeTourControllerProvider.notifier).stopTour(),
                icon: const Icon(Icons.stop_circle_outlined, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.locationMode == TourLocationMode.simulated
                ? '设置模式：模拟定位'
                : '设置模式：真实定位',
            style: TextStyle(
              color: AppColors.white.withValues(alpha: .62),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrationCard extends ConsumerStatefulWidget {
  const _NarrationCard({required this.state, this.onDirectory, super.key});
  final ActiveTourState state;
  final VoidCallback? onDirectory;

  @override
  ConsumerState<_NarrationCard> createState() => _NarrationCardState();
}

class _NarrationCardState extends ConsumerState<_NarrationCard> {
  var _showTranscript = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final fragment = state.current!;
    final profiles = state.route!.audioTour!.narrationProfiles;
    final selectedProfile = profiles
        .where((profile) => profile.id == state.narrationProfileId)
        .firstOrNull;
    final monitoring =
        state.status == 'monitoring' || state.status == 'simulated';
    final controller = ref.read(activeTourControllerProvider.notifier);
    return _DarkNarrationSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialRecordArtwork(
            imageUrl: state.route!.heroImage,
            chapterNumber: fragment.position,
            isPlaying: state.isPlaying,
            caption: '给眼前的城市，一段耳朵的时间。',
          ),
          const SizedBox(height: 9),
          EditorialChapterHeading(
            number: fragment.position,
            total: state.route!.audioTour!.fragments.length,
            title: fragment.title ?? fragment.safePreview,
            location: state.route!.title,
          ),
          const SizedBox(height: 16),
          Text(
            fragment.safePreview,
            style: const TextStyle(
              color: Color(0xffd1d2c6),
              fontSize: 12,
              height: 1.8,
            ),
          ),
          EditorialPlaybackControls(
            isPlaying: state.isPlaying,
            position: state.position,
            duration: state.duration,
            playTooltip: state.isPlaying ? '暂停' : '继续',
            onToggle: controller.togglePlayback,
            onSeek: controller.seek,
            nextLabel: '选篇',
            onNext: widget.onDirectory,
            status:
                '${_formatAudioTime(state.position)} / ${state.duration == null ? '--:--' : _formatAudioTime(state.duration!)} · 锁屏可继续播放',
          ),
          const SizedBox(height: 24),
          if (fragment.transcript != null) ...[
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x33f5f0e7))),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    setState(() => _showTranscript = !_showTranscript),
                style: TextButton.styleFrom(
                  foregroundColor: editorialPaper,
                  minimumSize: const Size(48, 72),
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('边听边读', style: TextStyle(fontSize: 13)),
                          SizedBox(height: 6),
                          Text(
                            '阅读等价文字稿',
                            style: TextStyle(
                              fontSize: 10,
                              color: editorialMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showTranscript
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_showTranscript)
              Padding(
                padding: const EdgeInsets.only(bottom: 25),
                child: SelectableText(
                  fragment.transcript!,
                  style: const TextStyle(
                    color: Color(0xffe4e3d7),
                    fontSize: 14,
                    height: 2.05,
                  ),
                ),
              ),
          ],
          if (widget.onDirectory != null)
            EditorialDirectoryLink(
              count: state.route!.audioTour!.fragments.length,
              currentNumber: fragment.position,
              onPressed: widget.onDirectory!,
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              PopupMenuButton<double>(
                initialValue: state.speed,
                tooltip: '速度',
                onSelected: controller.setSpeed,
                itemBuilder: (_) => const [.8, 1.0, 1.2, 1.5]
                    .map(
                      (speed) =>
                          PopupMenuItem(value: speed, child: Text('${speed}x')),
                    )
                    .toList(),
                child: _DarkControlSurface(
                  icon: Icons.speed_rounded,
                  label: '${state.speed}× 语速',
                ),
              ),
              if (profiles.isNotEmpty)
                _DarkControlButton(
                  icon: Icons.record_voice_over_outlined,
                  label: selectedProfile?.name ?? profiles.first.name,
                  selected: selectedProfile != null,
                  onPressed: profiles.length <= 1
                      ? null
                      : () async {
                          final chosen = await showNarrationVoicePicker(
                            context,
                            profiles: profiles,
                            selectedProfileId: state.narrationProfileId,
                          );
                          if (chosen != null &&
                              chosen != state.narrationProfileId) {
                            controller.selectNarrationProfile(chosen);
                          }
                        },
                ),
              Tooltip(
                message: monitoring ? '暂停自动导览' : '继续自动导览',
                child: _DarkControlButton(
                  icon: monitoring
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  label: monitoring ? '暂停自动导览' : '继续自动导览',
                  onPressed:
                      monitoring ? controller.pauseTour : controller.resumeTour,
                ),
              ),
            ],
          ),
          if (state.narrationProfileMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.narrationProfileMessage!,
                style: const TextStyle(
                  color: editorialMuted,
                  fontSize: 10,
                  height: 1.7,
                ),
              ),
            ),
          if (state.queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '另有 ${state.queue.length} 段故事在队列中',
                style: const TextStyle(color: editorialLime, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _DarkNarrationSurface extends StatelessWidget {
  const _DarkNarrationSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 7, 22, 25),
        decoration: BoxDecoration(
          color: editorialInk,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _NarrationPlayButton extends StatelessWidget {
  const _NarrationPlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(64),
          backgroundColor: editorialLime,
          foregroundColor: editorialInk,
        ),
        icon: Icon(icon),
      );
}

class _DarkControlButton extends StatelessWidget {
  const _DarkControlButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(99),
        child:
            _DarkControlSurface(icon: icon, label: label, selected: selected),
      );
}

class _DarkControlSurface extends StatelessWidget {
  const _DarkControlSurface({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.terracotta.withValues(alpha: .22)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? editorialLime
                  : editorialPaper.withValues(alpha: .22),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(color: editorialPaper, fontSize: 10),
            ),
          ],
        ),
      );
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
          child: Row(
            children: [
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
                    Text(
                      '可选的现场留念',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.moss,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
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
              Text(
                mission.prompt,
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
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
  const _LedgerEntry({required this.fragment, this.onPressed});
  final StoryFragment fragment;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x33252824))),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          onTap: onPressed,
          leading: SizedBox(
            width: 32,
            child: Text(
              fragment.position.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 27,
                color: Color(0xffb17661),
              ),
            ),
          ),
          title: Text(
            fragment.title ?? '未发现的线索',
            style: editorialSerif(17, color: editorialInk),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              fragment.isRevealed
                  ? (fragment.isCollected ? '已听过 · 随时回来翻阅' : '已抵达 · 选择听或读')
                  : fragment.safePreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.6,
                color: Color(0xff827563),
              ),
            ),
          ),
          trailing: Icon(
            fragment.isRevealed ? Icons.arrow_outward : Icons.lock_outline,
            size: 17,
            color: const Color(0xff827563),
          ),
        ),
      );
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
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: unlocked ? AppColors.gold : AppColors.white,
                foregroundColor: AppColors.ink,
                child: Icon(
                  completed
                      ? Icons.check_rounded
                      : unlocked
                          ? Icons.account_tree_outlined
                          : Icons.lock_outline_rounded,
                ),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: completed ? AppColors.moss : AppColors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
