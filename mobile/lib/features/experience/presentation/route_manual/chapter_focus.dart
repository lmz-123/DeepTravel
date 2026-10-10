import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../home_story_controller.dart';
import '../widgets/editorial_listening.dart';
import '../widgets/favorite_button.dart';
import 'manual_chapter.dart';
import 'manual_visuals.dart';

class ManualChapterFocus extends ConsumerStatefulWidget {
  const ManualChapterFocus({
    required this.route,
    required this.chapter,
    required this.chapters,
    required this.mode,
    required this.onBack,
    required this.onDirectory,
    required this.onSelect,
    required this.onRead,
    required this.onListen,
    super.key,
  });
  final RouteExperience route;
  final ManualChapter chapter;
  final List<ManualChapter> chapters;
  final ManualChapterMode mode;
  final VoidCallback onBack;
  final VoidCallback onDirectory;
  final ValueChanged<ManualChapter> onSelect;
  final VoidCallback onRead;
  final VoidCallback onListen;
  @override
  ConsumerState<ManualChapterFocus> createState() => _ManualChapterFocusState();
}

class _ManualChapterFocusState extends ConsumerState<ManualChapterFocus> {
  final _scroll = ScrollController();
  final _controls = GlobalKey();
  bool _dock = false;
  bool _transcript = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ManualChapterFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.id != widget.chapter.id ||
        oldWidget.mode != widget.mode) {
      _transcript = false;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted) return;
    final box = _controls.currentContext?.findRenderObject() as RenderBox?;
    final top = box?.localToGlobal(Offset.zero).dy;
    final bottom = top == null ? null : top + box!.size.height;
    final next = widget.mode == ManualChapterMode.audio &&
        top != null &&
        (top < MediaQuery.paddingOf(context).top ||
            bottom! >
                MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).bottom);
    if (next != _dock) setState(() => _dock = next);
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final playback = ref.watch(homeStoryPlaybackControllerProvider);
    final owns = playback.source == ListeningSource.manualChapter &&
        (playback.story?.id.startsWith(
              'manual:${widget.route.id}:${chapter.id}:',
            ) ??
            false);
    final playing = owns && playback.isPlaying;
    final position = owns ? playback.position : Duration.zero;
    final duration = owns ? playback.duration : chapter.duration;
    final reading = widget.mode == ManualChapterMode.text;
    final index = widget.chapters.indexWhere((item) => item.id == chapter.id);
    final previous =
        index <= 0 ? null : () => widget.onSelect(widget.chapters[index - 1]);
    final next = index >= widget.chapters.length - 1
        ? null
        : () => widget.onSelect(widget.chapters[index + 1]);
    final side = MediaQuery.sizeOf(context).width <= 375 ? 18.0 : 22.0;
    return ColoredBox(
      color: manualInk,
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(side, 0, side, reading ? 25 : 146),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EditorialFocusHeader(
                    onBack: widget.onBack,
                    backLabel: '路线介绍',
                    showBackLabel: true,
                    onDirectory: widget.onDirectory,
                    trailing: FavoriteButton(
                      kind: 'route',
                      targetId: widget.route.id,
                      color: manualPaper,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.route.title,
                    style: manualType(10, color: editorialMuted, height: 1.6),
                  ),
                  if (!reading)
                    Padding(
                      padding: const EdgeInsets.only(top: 7, bottom: 9),
                      child: EditorialRecordArtwork(
                        imageUrl: chapter.image,
                        chapterNumber: chapter.number,
                        isPlaying: playing,
                        caption: '给眼前的城市，一段耳朵的时间。',
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                  EditorialChapterHeading(
                    number: chapter.number,
                    total: widget.chapters.length,
                    title: chapter.title,
                    location: chapter.place,
                    isReading: reading,
                  ),
                  if (reading) ...[
                    const SizedBox(height: 21),
                    SelectableText(
                      chapter.body,
                      style: manualType(
                        14,
                        color: const Color(0xFFE4E3D7),
                        height: 2,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x33F5F0E7)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ReadTurn(
                            label: '上一段',
                            previous: true,
                            onTap: previous,
                          ),
                          _ReadTurn(label: '下一段', onTap: next),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      _excerpt(chapter.body),
                      style: manualType(
                        12,
                        color: const Color(0xFFD1D2C6),
                        height: 1.8,
                      ),
                    ),
                    EditorialPlaybackControls(
                      playKey: _controls,
                      isPlaying: playing,
                      position: position,
                      duration: duration,
                      onToggle: widget.onListen,
                      onSeek: (value) => ref
                          .read(homeStoryPlaybackControllerProvider.notifier)
                          .seek(value),
                      chapterNavigation: true,
                      onPrevious: previous,
                      onNext: next,
                      nextLabel: '下一段',
                      playTooltip: playing ? '暂停音频' : '播放音频',
                      status: playing
                          ? '播放中'
                          : (owns && playback.phase == HomeStoryPhase.ended)
                              ? '已听完'
                              : position > Duration.zero
                                  ? '已暂停'
                                  : '待播放',
                    ),
                    if (owns && playback.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Text(
                          playback.message!,
                          style: manualType(
                            12,
                            color: const Color(0xFFF5AF9E),
                            height: 1.7,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x33F5F0E7)),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() => _transcript = !_transcript);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _measure(),
                          );
                        },
                        child: SizedBox(
                          height: 72,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '边听边读',
                                      style: manualType(13, color: manualPaper),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '这一段的完整文字',
                                      style: manualType(
                                        10,
                                        color: editorialMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _transcript
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 20,
                                color: manualPaper,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      alignment: Alignment.topCenter,
                      child: _transcript
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: 2,
                                bottom: 25,
                              ),
                              child: SelectableText(
                                chapter.body,
                                style: manualType(
                                  14,
                                  color: const Color(0xFFE4E3D7),
                                  height: 2.05,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                  EditorialDirectoryLink(
                    count: widget.chapters.length,
                    currentNumber: chapter.number,
                    onPressed: widget.onDirectory,
                  ),
                  if (chapter.hasAudio)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: EditorialTextAction(
                        label: reading ? '听听这一篇' : '安静地读这一篇',
                        icon: reading
                            ? Icons.headphones_outlined
                            : Icons.menu_book_outlined,
                        onPressed: reading
                            ? () => widget.onSelect(chapter)
                            : widget.onRead,
                      ),
                    ),
                  if (widget.route.audioTour?.productionReady == false &&
                      (widget.route.audioTour?.demoLabel?.isNotEmpty ?? false))
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(widget.route.audioTour!.demoLabel!,
                            style: manualType(10,
                                color: editorialMuted, height: 1.7))),
                  const SizedBox(height: 20),
                  Text(
                    '停在宽阔的公共步行区域。拥挤时，先照顾脚下和身边的人。',
                    style: manualType(
                      9,
                      color: const Color(0xFFAAAF9D),
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_dock && !reading)
            Positioned(
              left: 18,
              right: 18,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: Container(
                padding: const EdgeInsets.fromLTRB(17, 10, 17, 12),
                decoration: BoxDecoration(
                  color: const Color(0xF52E332C),
                  border: Border.all(color: const Color(0x6E8F947C)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(25),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 7),
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x29F5F0E7)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            chapter.folio,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 17,
                              color: manualLime,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              chapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: manualType(
                                12,
                                serif: true,
                                color: manualPaper,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DockAction(
                          label: '目录',
                          icon: Icons.format_list_bulleted,
                          onTap: widget.onDirectory,
                        ),
                        IconButton.filled(
                          tooltip: playing ? '暂停音频' : '播放音频',
                          onPressed: widget.onListen,
                          style: IconButton.styleFrom(
                            backgroundColor: manualLime,
                            foregroundColor: manualInk,
                            fixedSize: const Size.square(56),
                          ),
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 26,
                          ),
                        ),
                        _DockAction(
                          label: '下一篇',
                          icon: Icons.skip_next_outlined,
                          onTap: next,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _excerpt(String body) {
  final parts = body.split('。').where((part) => part.trim().isNotEmpty).take(2);
  return parts.isEmpty ? body : '${parts.join('。')}。';
}

class _ReadTurn extends StatelessWidget {
  const _ReadTurn({required this.label, this.previous = false, this.onTap});
  final String label;
  final bool previous;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: manualLime,
          disabledForegroundColor: manualLime.withValues(alpha: .4),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          children: [
            if (previous) ...[
              const Icon(Icons.arrow_back, size: 17),
              const SizedBox(width: 10),
            ],
            Text(label, style: const TextStyle(fontSize: 13)),
            if (!previous) ...[
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 17),
            ],
          ],
        ),
      );
}

class _DockAction extends StatelessWidget {
  const _DockAction({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFE1E2CF),
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.all(3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      );
}
