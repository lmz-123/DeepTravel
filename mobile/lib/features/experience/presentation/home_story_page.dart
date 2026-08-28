import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'home_story_controller.dart';
import 'discovery_controller.dart';
import 'widgets/favorite_button.dart';
import 'widgets/traveler_bottom_navigation.dart';

class HomeStoryPage extends ConsumerStatefulWidget {
  const HomeStoryPage({this.catalogId, super.key});

  final String? catalogId;

  @override
  ConsumerState<HomeStoryPage> createState() => _HomeStoryPageState();
}

class _HomeStoryPageState extends ConsumerState<HomeStoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final city = ref.read(discoveryControllerProvider).asData?.value.city;
      if (widget.catalogId case final catalogId?) {
        ref
            .read(homeStoryPlaybackControllerProvider.notifier)
            .loadCatalog(catalogId);
        return;
      }
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
      backgroundColor: AppColors.ink,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        leading: IconButton(
          tooltip: '返回首页',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (state.story case final story?)
            FavoriteButton(kind: 'story', targetId: story.id),
          const SizedBox(width: 10),
        ],
      ),
      bottomNavigationBar: const TravelerBottomNavigation(
        active: TravelerSection.discovery,
      ),
      body: switch (state.phase) {
        HomeStoryPhase.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        HomeStoryPhase.empty || HomeStoryPhase.error => _StoryFailure(
            message: state.message ?? '故事暂时没有加载出来。',
            onRetry: () {
              final controller =
                  ref.read(homeStoryPlaybackControllerProvider.notifier);
              if (widget.catalogId case final catalogId?) {
                controller.loadCatalog(catalogId);
              } else {
                controller.load(
                  citySlug: ref
                      .read(discoveryControllerProvider)
                      .asData
                      ?.value
                      .city
                      ?.slug,
                );
              }
            },
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
      padding: EdgeInsets.zero,
      children: [
        Semantics(
          image: true,
          label: '${story.title} 的故事封面',
          child: SizedBox(
            height: 430,
            child: Stack(
              fit: StackFit.expand,
              children: [
                story.coverImage.isEmpty
                    ? const _StoryCoverFallback()
                    : Image.network(
                        story.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _StoryCoverFallback(),
                      ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22142B33),
                        Color(0x11142B33),
                        AppColors.ink,
                      ],
                      stops: [0, .42, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${story.cityName} · 城市故事 · ${_storyTime(duration)}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.gold,
                                  letterSpacing: 1.1,
                                ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        story.title,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${story.narratorName} · ${story.routeTitle}',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: .68),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.introduction,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.white.withValues(alpha: .82),
                  height: 1.9,
                  fontFamily: 'Songti SC',
                  fontFamilyFallback: const ['STSong', 'serif'],
                ),
              ),
              if (story.themes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: story.themes
                      .map(
                        (theme) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            theme,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: .74),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (story.placeContext.isNotEmpty)
                _StoryContextNote(
                  icon: Icons.location_on_outlined,
                  text: story.placeContext,
                ),
              if (story.observableDetail.isNotEmpty)
                _StoryContextNote(
                  icon: Icons.visibility_outlined,
                  text: '可以观察：${story.observableDetail}',
                ),
              if (story.attentionHint?.isNotEmpty ?? false)
                _StoryContextNote(
                  icon: Icons.auto_awesome_outlined,
                  text: '到现场时可以留意：${story.attentionHint}',
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 34,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filled(
                          key: const ValueKey('home-story-play-pause'),
                          tooltip: state.isPlaying ? '暂停故事' : '播放故事',
                          style: IconButton.styleFrom(
                            backgroundColor: state.isPlaying
                                ? AppColors.terracotta
                                : AppColors.ink,
                            foregroundColor: state.isPlaying
                                ? AppColors.white
                                : AppColors.gold,
                            minimumSize: const Size.square(50),
                          ),
                          onPressed: () => ref
                              .read(
                                  homeStoryPlaybackControllerProvider.notifier)
                              .toggle(),
                          icon: Icon(
                            state.isPlaying
                                ? Icons.pause_rounded
                                : state.phase == HomeStoryPhase.ended
                                    ? Icons.replay_rounded
                                    : Icons.play_arrow_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isPlaying
                                    ? '正在讲给你听'
                                    : state.phase == HomeStoryPhase.ended
                                        ? '故事讲完了，再听一次也可以'
                                        : '准备好时，点一下开始',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                story.narratorName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.graphic_eq_rounded,
                          color: state.isPlaying
                              ? AppColors.terracotta
                              : AppColors.textMuted,
                        ),
                      ],
                    ),
                    Slider(
                      value: durationMs <= 0 ? 0 : positionMs.toDouble(),
                      max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                      onChanged: durationMs <= 0
                          ? null
                          : (value) => ref
                              .read(
                                homeStoryPlaybackControllerProvider.notifier,
                              )
                              .seek(Duration(milliseconds: value.round())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_storyTime(state.position)),
                        Text(_storyTime(duration)),
                      ],
                    ),
                  ],
                ),
              ),
              if (state.message != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.message!,
                  style: const TextStyle(color: AppColors.terracotta),
                ),
              ],
              const SizedBox(height: 20),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  unselectedWidgetColor: AppColors.white,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
                  iconColor: AppColors.gold,
                  collapsedIconColor: AppColors.white,
                  title: const Text(
                    '完整文字稿',
                    style: TextStyle(color: AppColors.white),
                  ),
                  children: [
                    Text(
                      story.transcript,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.white.withValues(alpha: .72),
                            height: 1.85,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: BorderSide(
                      color: AppColors.white.withValues(alpha: .2),
                    ),
                  ),
                  onPressed: state.phase == HomeStoryPhase.loading
                      ? null
                      : () => ref
                          .read(homeStoryPlaybackControllerProvider.notifier)
                          .load(
                            citySlug: story.citySlug,
                            excludeCurrent: true,
                          ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('换一个故事'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryContextNote extends StatelessWidget {
  const _StoryContextNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold, size: 18),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: .8),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
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
