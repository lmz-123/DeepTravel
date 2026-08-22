import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'experience_providers.dart';
import 'home_story_controller.dart';

class HomeStoryPage extends ConsumerStatefulWidget {
  const HomeStoryPage({super.key});

  @override
  ConsumerState<HomeStoryPage> createState() => _HomeStoryPageState();
}

class _HomeStoryPageState extends ConsumerState<HomeStoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final city = ref.read(activeCityProvider);
      final current = ref.read(homeStoryPlaybackControllerProvider);
      if (current.story == null || current.citySlug != city?.slug) {
        ref
            .read(homeStoryPlaybackControllerProvider.notifier)
            .load(citySlug: city?.slug);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeStoryPlaybackControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          tooltip: '返回首页',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('听一个短故事'),
        centerTitle: true,
      ),
      body: switch (state.phase) {
        HomeStoryPhase.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        HomeStoryPhase.empty || HomeStoryPhase.error => _StoryFailure(
            message: state.message ?? '故事暂时没有加载出来。',
            onRetry: () => ref
                .read(homeStoryPlaybackControllerProvider.notifier)
                .load(citySlug: ref.read(activeCityProvider)?.slug),
          ),
        _ when state.story != null => _StoryBody(state: state),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _StoryBody extends ConsumerWidget {
  const _StoryBody({required this.state});
  final HomeStoryPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = state.story!;
    final duration = state.duration ?? story.duration;
    final durationMs = duration.inMilliseconds;
    final positionMs = state.position.inMilliseconds.clamp(0, durationMs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 42),
      children: [
        Semantics(
          image: true,
          label: '${story.title} 的故事封面',
          child: AspectRatio(
            aspectRatio: 1.15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: story.coverImage.isEmpty
                  ? const _StoryCoverFallback()
                  : Image.network(
                      story.coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _StoryCoverFallback(),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('${story.cityName} · ${story.routeTitle}',
            style: const TextStyle(
              color: AppColors.terracotta,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            )),
        const SizedBox(height: 8),
        Text(story.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          story.introduction,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(children: [
            Row(children: [
              IconButton.filled(
                key: const ValueKey('home-story-play-pause'),
                tooltip: state.isPlaying ? '暂停故事' : '播放故事',
                onPressed: () => ref
                    .read(homeStoryPlaybackControllerProvider.notifier)
                    .toggle(),
                icon: Icon(state.isPlaying
                    ? Icons.pause_rounded
                    : state.phase == HomeStoryPhase.ended
                        ? Icons.replay_rounded
                        : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.isPlaying
                        ? '正在讲给你听'
                        : state.phase == HomeStoryPhase.ended
                            ? '故事讲完了，再听一次也可以'
                            : '准备好时，点一下开始'),
                    const SizedBox(height: 2),
                    Text(story.narratorName,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ]),
            Slider(
              value: durationMs <= 0 ? 0 : positionMs.toDouble(),
              max: durationMs <= 0 ? 1 : durationMs.toDouble(),
              onChanged: durationMs <= 0
                  ? null
                  : (value) => ref
                      .read(homeStoryPlaybackControllerProvider.notifier)
                      .seek(Duration(milliseconds: value.round())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_storyTime(state.position)),
                Text(_storyTime(duration)),
              ],
            ),
          ]),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          Text(state.message!,
              style: const TextStyle(color: AppColors.terracotta)),
        ],
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          title: const Text('不方便听？展开文字稿'),
          children: [
            Text(story.transcript,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.8)),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.phase == HomeStoryPhase.loading
              ? null
              : () => ref
                  .read(homeStoryPlaybackControllerProvider.notifier)
                  .load(citySlug: story.citySlug, excludeCurrent: true),
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('换一个故事'),
        ),
      ],
    );
  }
}

class _StoryCoverFallback extends StatelessWidget {
  const _StoryCoverFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff284c3d), Color(0xff9a654c)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child:
              Icon(Icons.graphic_eq_rounded, size: 70, color: AppColors.gold),
        ),
      );
}

class _StoryFailure extends StatelessWidget {
  const _StoryFailure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.library_music_outlined,
                size: 54, color: AppColors.moss),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('再试一次')),
          ]),
        ),
      );
}

String _storyTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 359999);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
