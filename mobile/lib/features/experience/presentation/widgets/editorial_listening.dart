import 'package:flutter/material.dart';

/// The shared listening page geometry mirrors the approved 390 pt V5 plate.
const editorialInk = Color(0xff252824);
const editorialPaper = Color(0xfff5f0e7);
const editorialLime = Color(0xffdbe782);
const editorialMuted = Color(0xffb5b8aa);

TextStyle editorialSerif(double size, {Color color = editorialPaper}) =>
    TextStyle(
      fontFamily: 'Noto Serif SC',
      fontFamilyFallback: const ['Songti SC', 'serif'],
      fontSize: size,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: -.02 * size,
      color: color,
    );

class EditorialFocusHeader extends StatelessWidget {
  const EditorialFocusHeader({
    required this.onBack,
    this.onDirectory,
    this.trailing,
    this.backLabel = '返回路线',
    this.showBackLabel = false,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onDirectory;
  final Widget? trailing;
  final String backLabel;
  final bool showBackLabel;

  @override
  Widget build(BuildContext context) => Container(
    height: 77,
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: editorialPaper.withValues(alpha: .17)),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: backLabel,
          onPressed: onBack,
          color: editorialPaper,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.arrow_back, size: 19),
        ),
        if (showBackLabel)
          Text(
            backLabel,
            style: const TextStyle(color: editorialPaper, fontSize: 13),
          ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            '见地',
            style: editorialSerif(20).copyWith(letterSpacing: 2),
          ),
        ),
        if (onDirectory != null)
          TextButton.icon(
            onPressed: onDirectory,
            style: TextButton.styleFrom(
              foregroundColor: editorialPaper,
              minimumSize: const Size(60, 48),
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
            icon: const Icon(Icons.format_list_bulleted, size: 16),
            label: const Text('目录', style: TextStyle(fontSize: 11)),
          ),
        if (trailing != null)
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: editorialPaper.withValues(alpha: .33)),
            ),
            child: trailing,
          ),
      ],
    ),
  );
}

class EditorialRecordArtwork extends StatefulWidget {
  const EditorialRecordArtwork({
    required this.imageUrl,
    required this.chapterNumber,
    required this.isPlaying,
    this.caption = '给眼前的城市，一段耳朵的时间。',
    super.key,
  });

  final String imageUrl;
  final int chapterNumber;
  final bool isPlaying;
  final String caption;

  @override
  State<EditorialRecordArtwork> createState() => _EditorialRecordArtworkState();
}

class _EditorialRecordArtworkState extends State<EditorialRecordArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRotation();
  }

  @override
  void didUpdateWidget(covariant EditorialRecordArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRotation();
  }

  void _updateRotation() {
    if (widget.isPlaying && !MediaQuery.disableAnimationsOf(context)) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 375;
    final diameter = compact ? 185.0 : 207.0;
    return Semantics(
      image: true,
      label: '第 ${widget.chapterNumber} 篇的唱片封面',
      child: Stack(
        children: [
          Positioned(
            top: -2,
            left: 1,
            child: ExcludeSemantics(
              child: Text(
                widget.chapterNumber.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: const ['serif'],
                  fontStyle: FontStyle.italic,
                  fontSize: compact ? 118 : 132,
                  height: 1,
                  letterSpacing: -10,
                  color: editorialPaper.withValues(alpha: .1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 32, 0, 14),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  RotationTransition(
                    turns: _rotation,
                    child: Container(
                      key: const ValueKey('editorial-record'),
                      width: diameter,
                      height: diameter,
                      decoration: BoxDecoration(
                        color: const Color(0xff10130f),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xff42463a)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 40,
                            offset: Offset(0, 22),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final factor in [.92, .84, .76])
                            Container(
                              width: diameter * factor,
                              height: diameter * factor,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x6633382d),
                                ),
                              ),
                            ),
                          ClipOval(
                            child: SizedBox(
                              width: diameter * .68,
                              height: diameter * .68,
                              child: widget.imageUrl.isEmpty
                                  ? const _RecordFallback()
                                  : Image.network(
                                      widget.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const _RecordFallback(),
                                    ),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: editorialInk,
                              border: Border.all(
                                color: editorialPaper,
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.caption,
                    style: const TextStyle(
                      color: editorialMuted,
                      fontSize: 9,
                      letterSpacing: .72,
                    ),
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

class _RecordFallback extends StatelessWidget {
  const _RecordFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xff77826b), Color(0xffa79471)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(Icons.landscape_outlined, size: 48, color: editorialPaper),
    ),
  );
}

class EditorialChapterHeading extends StatelessWidget {
  const EditorialChapterHeading({
    required this.number,
    required this.total,
    required this.title,
    this.location,
    this.isReading = false,
    super.key,
  });
  final int number;
  final int total;
  final String title;
  final String? location;
  final bool isReading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '第 ${number.toString().padLeft(2, '0')} 段 / 共 ${total.toString().padLeft(2, '0')} 段',
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: .72,
                color: editorialMuted,
              ),
            ),
          ),
          Icon(
            isReading ? Icons.menu_book_outlined : Icons.headphones_outlined,
            size: 13,
            color: editorialLime,
          ),
          const SizedBox(width: 5),
          Text(
            isReading ? '文字手册' : '音频故事',
            style: const TextStyle(fontSize: 9, color: editorialLime),
          ),
        ],
      ),
      const SizedBox(height: 13),
      Text(
        title,
        style: editorialSerif(
          MediaQuery.sizeOf(context).width <= 375 ? 28 : 31,
        ),
      ),
      if (location?.isNotEmpty ?? false) ...[
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.location_on_outlined,
                color: editorialMuted,
                size: 13,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                location!,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: editorialMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

class EditorialPlaybackControls extends StatelessWidget {
  const EditorialPlaybackControls({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
    this.onNext,
    this.onPrevious,
    this.chapterNavigation = false,
    this.previousLabel = '上一段',
    this.nextLabel = '下一段',
    this.status,
    this.playKey,
    this.playTooltip,
    super.key,
  });
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final bool chapterNavigation;
  final String previousLabel;
  final String nextLabel;
  final String? status;
  final Key? playKey;
  final String? playTooltip;

  @override
  Widget build(BuildContext context) {
    final total = duration?.inMilliseconds ?? 0;
    final value = total <= 0
        ? 0.0
        : position.inMilliseconds.clamp(0, total).toDouble();
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              editorialAudioTime(position),
              style: const TextStyle(color: Color(0xffc4c7b9), fontSize: 10),
            ),
            Text(
              duration == null ? '--:--' : editorialAudioTime(duration!),
              style: const TextStyle(color: Color(0xffc4c7b9), fontSize: 10),
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: editorialLime,
              inactiveTrackColor: editorialPaper.withValues(alpha: .2),
              thumbColor: editorialLime,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayColor: editorialLime.withValues(alpha: .12),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              max: total <= 0 ? 1 : total.toDouble(),
              semanticFormatterCallback: (value) =>
                  editorialAudioTime(Duration(milliseconds: value.round())),
              onChanged: total <= 0
                  ? null
                  : (value) => onSeek(Duration(milliseconds: value.round())),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EditorialSkip(
              icon: chapterNavigation
                  ? Icons.skip_previous_outlined
                  : Icons.replay_10_outlined,
              label: chapterNavigation ? previousLabel : '后退 10 秒',
              onPressed: chapterNavigation
                  ? onPrevious
                  : () => onSeek(
                      Duration(
                        milliseconds: (position.inMilliseconds - 10000).clamp(
                          0,
                          total > 0 ? total : 0,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 35),
            IconButton.filled(
              key: playKey,
              tooltip: playTooltip ?? (isPlaying ? '暂停' : '播放这一篇'),
              onPressed: onToggle,
              style: IconButton.styleFrom(
                backgroundColor: editorialLime,
                foregroundColor: editorialInk,
                fixedSize: const Size.square(64),
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 29,
              ),
            ),
            const SizedBox(width: 35),
            _EditorialSkip(
              icon: Icons.skip_next_outlined,
              label: nextLabel,
              onPressed: onNext,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          status ??
              (isPlaying
                  ? '播放中'
                  : position > Duration.zero
                  ? '已暂停'
                  : '待播放'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: editorialMuted,
            fontSize: 10,
            height: 1.8,
          ),
        ),
      ],
    );
  }
}

class _EditorialSkip extends StatelessWidget {
  const _EditorialSkip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        foregroundColor: editorialPaper,
        disabledForegroundColor: editorialMuted.withValues(alpha: .4),
        minimumSize: const Size(60, 48),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );
}

class EditorialDirectoryLink extends StatelessWidget {
  const EditorialDirectoryLink({
    required this.count,
    required this.onPressed,
    this.currentNumber,
    super.key,
  });
  final int count;
  final int? currentNumber;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: editorialPaper.withValues(alpha: .2)),
      ),
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 82),
        alignment: Alignment.centerLeft,
        foregroundColor: editorialPaper,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_list_bulleted, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('翻开章节目录', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 5),
                Text(
                  currentNumber == null
                      ? '共 $count 篇 · 选择下一段故事'
                      : '第 ${currentNumber.toString().padLeft(2, '0')} 篇 / 共 $count 篇',
                  style: const TextStyle(fontSize: 10, color: editorialMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 19),
        ],
      ),
    ),
  );
}

class EditorialTextAction extends StatelessWidget {
  const EditorialTextAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: editorialLime,
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
    ),
    icon: Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

String editorialAudioTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 359999);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class EditorialPageArrival extends StatelessWidget {
  const EditorialPageArrival({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: .2 + .8 * value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
  );
}
