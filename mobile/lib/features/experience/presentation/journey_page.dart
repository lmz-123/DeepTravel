import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/editorial_image.dart';
import '../../../core/widgets/primary_action.dart';
import '../domain/models.dart';
import 'experience_providers.dart';
import 'widgets/route_canvas.dart';

class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({required this.journeyId, super.key});
  final String journeyId;

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journeyControllerProvider);
    final route = state.route;
    final session = state.session;
    if (route == null || session == null || session.id != widget.journeyId) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 44),
                const SizedBox(height: 14),
                const Text('这段旅程需要从路线详情开始'),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('回到发现页')),
              ],
            ),
          ),
        ),
      );
    }
    final stop = route.stops[session.currentStopPosition - 1];
    final arrived = session.arrivedStopId == stop.id;
    final answered = session.answeredStopIds.contains(stop.id);
    return Scaffold(
      appBar: AppBar(
        title: Text('${session.currentStopPosition} / ${route.stops.length}'),
        actions: [
          IconButton(
            tooltip: '查看路线',
            onPressed: () =>
                _showMap(context, route, session.currentStopPosition),
            icon: const Icon(Icons.map_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (session.currentStopPosition - 1) / route.stops.length,
            minHeight: 3,
            color: AppColors.terracotta,
            backgroundColor: AppColors.paperDeep,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                            .animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(stop.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EditorialImage(
                        asset: stop.image, height: 235, borderRadius: 24),
                    const SizedBox(height: 24),
                    Text(
                      '第 ${stop.position} 站 · ${stop.kicker}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.terracotta),
                    ),
                    const SizedBox(height: 8),
                    Text(stop.title,
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 17, color: AppColors.moss),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(stop.address,
                                style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (!arrived)
                      _ArrivalCard(
                        busy: state.isBusy,
                        onArrive: () => ref
                            .read(journeyControllerProvider.notifier)
                            .arrive(),
                      )
                    else ...[
                      _StorySection(stop: stop),
                      const SizedBox(height: 24),
                      _ChallengeSection(
                        stop: stop,
                        feedback: state.feedback,
                        busy: state.isBusy,
                        onSelected: (option) {
                          ref
                              .read(journeyControllerProvider.notifier)
                              .answer(option);
                        },
                      ),
                      if (answered && state.feedback != null) ...[
                        const SizedBox(height: 18),
                        _InsightCard(feedback: state.feedback!),
                        const SizedBox(height: 20),
                        PrimaryAction(
                          label: stop == route.stops.last ? '完成这段旅程' : '前往下一站',
                          busy: state.isBusy,
                          onPressed: () async {
                            final completed = await ref
                                .read(journeyControllerProvider.notifier)
                                .advance();
                            if (!context.mounted) return;
                            if (completed) {
                              ref.invalidate(recapProvider(widget.journeyId));
                              context.go('/recap/${widget.journeyId}');
                            } else {
                              await _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                        ),
                      ],
                    ],
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
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

  void _showMap(BuildContext context, RouteExperience route, int position) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('你的路线', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            RouteCanvas(stops: route.stops, currentPosition: position),
          ],
        ),
      ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({required this.busy, required this.onArrive});
  final bool busy;
  final VoidCallback onArrive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.paperDeep, shape: BoxShape.circle),
              child: const Icon(Icons.near_me_outlined),
            ),
            const SizedBox(height: 16),
            Text('站到合适的位置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('先看看眼前，再打开这一站的故事。MVP 中可用演示到达完成体验。'),
            const SizedBox(height: 20),
            PrimaryAction(
              label: '我已到达（演示）',
              icon: Icons.location_on_rounded,
              busy: busy,
              onPressed: onArrive,
            ),
          ],
        ),
      ),
    );
  }
}

class _StorySection extends StatelessWidget {
  const _StorySection({required this.stop});
  final ExperienceStop stop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stop.storyTitle,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Text(stop.storyBody, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        const _StoryPlayer(),
      ],
    );
  }
}

class _StoryPlayer extends StatefulWidget {
  const _StoryPlayer();

  @override
  State<_StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<_StoryPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 75));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: _controller.isAnimating ? '暂停故事音频' : '播放故事音频',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () {
              setState(() {
                _controller.isAnimating
                    ? _controller.stop()
                    : _controller.forward();
              });
            },
            icon: Icon(_controller.isAnimating
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '故事音频 · 演示播放器',
                    style: TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _controller.value,
                    minHeight: 3,
                    color: AppColors.gold,
                    backgroundColor: AppColors.white.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('1:15', style: TextStyle(color: AppColors.white)),
        ],
      ),
    );
  }
}

class _ChallengeSection extends StatelessWidget {
  const _ChallengeSection({
    required this.stop,
    required this.feedback,
    required this.busy,
    required this.onSelected,
  });

  final ExperienceStop stop;
  final AnswerFeedback? feedback;
  final bool busy;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    color: AppColors.terracotta),
                const SizedBox(width: 8),
                Text('观察一下', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(stop.challenge.prompt,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(stop.challenge.hint,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            ...stop.challenge.options.indexed.map((entry) {
              final (index, option) = entry;
              final selected = feedback?.selectedOption == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: feedback != null || busy
                        ? null
                        : () => onSelected(index),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      side: BorderSide(
                        color: selected
                            ? AppColors.terracotta
                            : AppColors.ink.withValues(alpha: 0.14),
                      ),
                      backgroundColor: selected
                          ? AppColors.terracotta.withValues(alpha: 0.09)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text('${String.fromCharCode(65 + index)}  $option'),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.feedback});
  final AnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: feedback.isCorrect ? AppColors.moss : AppColors.terracotta,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                feedback.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.lightbulb_rounded,
                color: AppColors.white,
              ),
              const SizedBox(width: 8),
              Text(
                feedback.isCorrect ? '你看见了关键细节' : '换一个角度，也是一种发现',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(feedback.explanation,
              style: const TextStyle(color: AppColors.white, height: 1.55)),
          const SizedBox(height: 12),
          Text(
            feedback.insight,
            style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                height: 1.55),
          ),
        ],
      ),
    );
  }
}
