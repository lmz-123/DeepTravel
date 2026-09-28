import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'discovery_controller.dart';
import 'home_story_controller.dart';
import 'widgets/editorial_listening.dart';
import 'widgets/favorite_button.dart';

class HomeStoryPage extends ConsumerStatefulWidget {
  const HomeStoryPage({this.catalogId, super.key});
  final String? catalogId;

  @override
  ConsumerState<HomeStoryPage> createState() => _HomeStoryPageState();
}

class _HomeStoryPageState extends ConsumerState<HomeStoryPage> {
  bool _reading = false;
  bool _showDock = false;
  final _playerKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateDock);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final city = ref.read(discoveryControllerProvider).asData?.value.city;
      final controller = ref.read(homeStoryPlaybackControllerProvider.notifier);
      if (widget.catalogId case final catalogId?) {
        controller.loadCatalog(catalogId);
        return;
      }
      final current = ref.read(homeStoryPlaybackControllerProvider);
      if (current.story == null ||
          current.citySlug != city?.slug ||
          current.source != ListeningSource.cityStory) {
        controller.load(citySlug: city?.slug);
      } else if (current.isPlaying) {
        controller.toggle();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateDock() {
    final box = _playerKey.currentContext?.findRenderObject();
    final visible = !_reading &&
        box is RenderBox &&
        box.localToGlobal(Offset(0, box.size.height)).dy <
            MediaQuery.paddingOf(context).top;
    if (visible != _showDock && mounted) setState(() => _showDock = visible);
  }

  void _pause() {
    ref.read(homeStoryPlaybackControllerProvider.notifier).pause();
  }

  void _switchMode() {
    _pause();
    setState(() {
      _reading = !_reading;
      _showDock = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _nextStory() {
    final story = ref.read(homeStoryPlaybackControllerProvider).story;
    setState(() {
      _reading = false;
      _showDock = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    ref
        .read(homeStoryPlaybackControllerProvider.notifier)
        .load(citySlug: story?.citySlug, excludeCurrent: true);
  }

  void _retry() {
    final controller = ref.read(homeStoryPlaybackControllerProvider.notifier);
    if (widget.catalogId case final catalogId?) {
      controller.loadCatalog(catalogId);
    } else {
      controller.load(
        citySlug:
            ref.read(discoveryControllerProvider).asData?.value.city?.slug,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeStoryPlaybackControllerProvider);
    final story = state.story;
    final padding = MediaQuery.sizeOf(context).width <= 375 ? 18.0 : 22.0;
    final controller = ref.read(homeStoryPlaybackControllerProvider.notifier);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _pause();
      },
      child: Scaffold(
        backgroundColor: editorialInk,
        body: SafeArea(
          child: Stack(
            children: [
              if (state.phase == HomeStoryPhase.loading)
                const Center(
                  child: CircularProgressIndicator(color: editorialLime),
                )
              else if (story == null)
                _StoryFailure(
                  message: state.message ?? '故事暂时没有加载出来。',
                  onRetry: _retry,
                )
              else
                EditorialPageArrival(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      padding,
                      0,
                      padding,
                      _reading ? 32 : 146,
                    ),
                    children: [
                      EditorialFocusHeader(
                        backLabel: '返回首页',
                        onBack: () {
                          _pause();
                          context.pop();
                        },
                        trailing: FavoriteButton(
                          kind: 'story',
                          targetId: story.id,
                          color: editorialPaper,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Text(
                          [
                            story.cityName,
                            story.routeTitle,
                          ].where((part) => part.isNotEmpty).join(' · '),
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.6,
                            color: editorialMuted,
                          ),
                        ),
                      ),
                      if (!_reading) ...[
                        const SizedBox(height: 7),
                        EditorialRecordArtwork(
                          imageUrl: story.coverImage,
                          chapterNumber: 1,
                          isPlaying: state.isPlaying,
                          caption: '${story.narratorName} · 把城市，放进耳朵里',
                        ),
                        const SizedBox(height: 9),
                      ] else
                        const SizedBox(height: 39),
                      EditorialChapterHeading(
                        number: 1,
                        total: 1,
                        title: story.title,
                        location: story.placeContext.isNotEmpty
                            ? story.placeContext
                            : story.routeTitle,
                        isReading: _reading,
                      ),
                      if (_reading) ...[
                        const SizedBox(height: 21),
                        SelectableText(
                          story.transcript,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 2,
                            color: Color(0xffe4e3d7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0x33f5f0e7)),
                        EditorialTextAction(
                          label: '听这一篇',
                          icon: Icons.headphones_outlined,
                          onPressed: _switchMode,
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Text(
                          story.introduction,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.8,
                            color: Color(0xffd1d2c6),
                          ),
                        ),
                        EditorialPlaybackControls(
                          key: _playerKey,
                          playKey: const ValueKey('home-story-play-pause'),
                          playTooltip: state.isPlaying ? '暂停故事' : '播放故事',
                          isPlaying: state.isPlaying,
                          position: state.position,
                          duration: state.duration ?? story.duration,
                          onToggle: controller.toggle,
                          onSeek: controller.seek,
                          onNext: _nextStory,
                          nextLabel: '换一篇',
                          status: state.phase == HomeStoryPhase.ended
                              ? '这一篇讲完了，再听一次也可以'
                              : null,
                        ),
                        const SizedBox(height: 9),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: EditorialTextAction(
                            label: '安静地读这一篇',
                            icon: Icons.menu_book_outlined,
                            onPressed: _switchMode,
                          ),
                        ),
                      ],
                      if (state.message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            state.message!,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              color: Color(0xfff5af9e),
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      if (story.observableDetail.isNotEmpty)
                        _StoryMarginNote(
                          label: '可以观察',
                          text: story.observableDetail,
                        ),
                      if (story.attentionHint?.isNotEmpty ?? false)
                        _StoryMarginNote(
                          label: '走到现场',
                          text: story.attentionHint!,
                        ),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: Color(0x33f5f0e7)),
                          ),
                        ),
                        child: TextButton(
                          onPressed: _nextStory,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            foregroundColor: editorialPaper,
                            minimumSize: const Size(double.infinity, 72),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_stories_outlined, size: 19),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '再翻一篇城市故事',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              Icon(Icons.arrow_forward, size: 19),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_showDock && story != null)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 12,
                  child: _StoryListenDock(
                    title: story.title,
                    isPlaying: state.isPlaying,
                    onToggle: controller.toggle,
                    onRead: _switchMode,
                    onNext: _nextStory,
                  ),
                ),
              if (story == null)
                Positioned(
                  top: 10,
                  left: 12,
                  child: IconButton(
                    tooltip: '返回首页',
                    onPressed: () => context.pop(),
                    color: editorialPaper,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryListenDock extends StatelessWidget {
  const _StoryListenDock({
    required this.title,
    required this.isPlaying,
    required this.onToggle,
    required this.onRead,
    required this.onNext,
  });
  final String title;
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onRead;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xff2e332c),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(25),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          side:
              BorderSide(color: const Color(0xff8f947c).withValues(alpha: .43)),
        ),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 10, 17, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '01',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 17,
                      color: editorialLime,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: editorialSerif(12),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0x29f5f0e7), height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  EditorialTextAction(
                    label: '文字',
                    icon: Icons.menu_book_outlined,
                    onPressed: onRead,
                  ),
                  IconButton.filled(
                    onPressed: onToggle,
                    tooltip: isPlaying ? '暂停故事' : '播放故事',
                    style: IconButton.styleFrom(
                      backgroundColor: editorialLime,
                      foregroundColor: editorialInk,
                      fixedSize: const Size.square(56),
                    ),
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  EditorialTextAction(
                    label: '换一篇',
                    icon: Icons.skip_next_outlined,
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StoryMarginNote extends StatelessWidget {
  const _StoryMarginNote({required this.label, required this.text});
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 32,
              color: editorialLime.withValues(alpha: .5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: editorialLime, fontSize: 10),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    text,
                    style: const TextStyle(
                      color: editorialMuted,
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('稍候，再翻一页', style: editorialSerif(28)),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: editorialMuted, height: 1.8),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: editorialLime),
                icon: const Icon(Icons.refresh),
                label: const Text('再试一次'),
              ),
            ],
          ),
        ),
      );
}
