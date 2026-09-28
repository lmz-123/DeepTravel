import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'manual_chapter.dart';
import 'manual_visuals.dart';

Future<ManualChapterMode?> showChapterPrelude(
  BuildContext context, {
  required ManualChapter chapter,
  required String routeName,
  required int count,
  bool fromDirectory = false,
  Duration resumeAt = Duration.zero,
}) =>
    showGeneralDialog<ManualChapterMode>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '合上序页',
      barrierColor: const Color(0x7324271F),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) => Stack(children: [
        Positioned.fill(
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: const ColoredBox(color: Colors.transparent)))),
        Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Transform.translate(
                  offset: Offset(
                      0,
                      MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 42 *
                              (1 -
                                  const Cubic(.2, .7, .25, 1)
                                      .transform(animation.value))),
                  child: child),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Material(
                      color: manualPaper,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28))),
                      clipBehavior: Clip.antiAlias,
                      child: ChapterPrelude(
                          chapter: chapter,
                          routeName: routeName,
                          count: count,
                          fromDirectory: fromDirectory,
                          resumeAt: resumeAt))),
            )),
      ]),
    );

class ChapterPrelude extends StatelessWidget {
  const ChapterPrelude({
    required this.chapter,
    required this.routeName,
    required this.count,
    this.fromDirectory = false,
    this.resumeAt = Duration.zero,
    super.key,
  });
  final ManualChapter chapter;
  final String routeName;
  final int count;
  final bool fromDirectory;
  final Duration resumeAt;

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width <= 375;
    final side = small ? 21.0 : 25.0;
    final resume = resumeAt > const Duration(milliseconds: 500) &&
        (chapter.duration == Duration.zero ||
            resumeAt < chapter.duration - const Duration(milliseconds: 500));
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 31,
              height: 3,
              margin: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFB5B3A5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: side),
              child: Container(
                constraints: BoxConstraints(minHeight: fromDirectory ? 57 : 52),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x24252824))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (fromDirectory)
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(96, 48),
                          foregroundColor: const Color(0xFF5A5D4E),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 19),
                        label: Text(
                          '返回目录',
                          style: manualType(12, color: const Color(0xFF5A5D4E)),
                        ),
                      ),
                    Text(
                      '见地  /  一页序言',
                      style: manualType(
                        fromDirectory ? 10 : 11,
                        color: const Color(0xFF7C725F),
                      ),
                    ),
                    if (!fromDirectory)
                      IconButton(
                        tooltip: '合上序页',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 22),
                      ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, small ? 15 : 20, side, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$routeName · 共 $count 篇',
                      style: manualType(
                        10,
                        color: const Color(0xFF8A7C68),
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: small ? 9 : 11),
                    Text(
                      '先翻一页，',
                      style: manualType(
                        small ? 34 : 37,
                        serif: true,
                        height: 1.45,
                        weight: FontWeight.w500,
                        spacing: -1.9,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        '再${chapter.hasAudio ? '听' : '读'}一座城。',
                        style: manualType(
                          small ? 34 : 37,
                          serif: true,
                          color: manualRed,
                          height: 1.45,
                          weight: FontWeight.w500,
                          spacing: -1.9,
                        ),
                      ),
                    ),
                    SizedBox(height: small ? 19 : 24),
                    Row(
                      children: [
                        SizedBox(
                          width: small ? 95 : 106,
                          height: small ? 138 : 151,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(58),
                              bottom: Radius.circular(3),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ManualPhoto(source: chapter.image),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0x85152419),
                                      ],
                                      stops: [.55, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  bottom: 8,
                                  child: Text(
                                    chapter.folio,
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 37,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFFF7F1E5),
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: small ? 17 : 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '第 ${chapter.folio} 篇 · ${chapter.hasAudio ? chapter.durationLabel : '文字手册'}',
                                style: manualType(
                                  10,
                                  color: const Color(0xFF95806A),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                chapter.title,
                                style: manualType(
                                  small ? 20 : 21,
                                  serif: true,
                                  height: 1.55,
                                  weight: FontWeight.w500,
                                  spacing: -.84,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                chapter.place,
                                style: manualType(
                                  10,
                                  color: const Color(0xFF817763),
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: small ? 16 : 22),
                    Text(
                      resume
                          ? '上次听到 ${manualTime(resumeAt)}，这一页替你留着。'
                          : '停在这一页，让故事慢慢展开。',
                      style: manualType(
                        11,
                        color: const Color(0xFF827563),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 11),
                    if (!fromDirectory)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x24252824)),
                          ),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            ManualChapterMode.directory,
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(double.infinity, 51),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.format_list_bulleted,
                                size: 16,
                                color: Color(0xFF615F4F),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                '从目录挑一篇',
                                style: manualType(
                                  12,
                                  color: const Color(0xFF615F4F),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: Color(0xFF615F4F),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 15, side, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chapter.hasAudio) ...[
                    ManualPaperAction(
                      key: const ValueKey('manual-play-chapter'),
                      label: resume ? '继续听这一篇' : '播放这一篇',
                      folio: chapter.folio,
                      play: true,
                      onPressed: () =>
                          Navigator.pop(context, ManualChapterMode.audio),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x7077725B)),
                        ),
                      ),
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pop(context, ManualChapterMode.text),
                        key: const ValueKey('manual-read-chapter'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 18,
                              color: Color(0xFF626451),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              '阅读这一篇',
                              style: manualType(
                                15,
                                serif: true,
                                color: const Color(0xFF626451),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward,
                              size: 19,
                              color: Color(0xFF626451),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    ManualPaperAction(
                      key: const ValueKey('manual-read-chapter'),
                      label: '阅读这一篇',
                      onPressed: () =>
                          Navigator.pop(context, ManualChapterMode.text),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
