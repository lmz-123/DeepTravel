import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chapter_prelude.dart';
import 'manual_chapter.dart';
import 'manual_visuals.dart';

Future<ManualChapterChoice?> showChapterDirectory(
  BuildContext context, {
  required List<ManualChapter> chapters,
  required String routeName,
  required Set<String> visited,
  String? currentId,
  Map<String, Duration> positions = const {},
}) =>
    Navigator.of(context).push<ManualChapterChoice>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RouteChapterDirectory(
          chapters: chapters,
          routeName: routeName,
          visited: visited,
          currentId: currentId,
          positions: positions,
        ),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final curve = CurvedAnimation(
            parent: animation,
            curve: const Cubic(.2, .7, .2, 1),
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .03),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );

class RouteChapterDirectory extends StatefulWidget {
  const RouteChapterDirectory({
    required this.chapters,
    required this.routeName,
    required this.visited,
    this.currentId,
    this.positions = const {},
    super.key,
  });
  final List<ManualChapter> chapters;
  final String routeName;
  final Set<String> visited;
  final String? currentId;
  final Map<String, Duration> positions;
  @override
  State<RouteChapterDirectory> createState() => _RouteChapterDirectoryState();
}

class _RouteChapterDirectoryState extends State<RouteChapterDirectory> {
  static const pageSize = 12;
  final _query = TextEditingController();
  final _scroll = ScrollController();
  var _progress = 0;
  var _page = 0;
  var _compact = false;

  @override
  void initState() {
    super.initState();
    final current = widget.chapters.indexWhere(
      (chapter) => chapter.id == widget.currentId,
    );
    _page = math.max(0, current) ~/ pageSize;
    _scroll.addListener(() {
      if (!_compact &&
          widget.chapters.length > pageSize &&
          _scroll.offset > 72) {
        setState(() => _compact = true);
      }
    });
    if (current > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(
          ((current % pageSize) * 92 -
                  _scroll.position.viewportDimension / 2 +
                  46)
              .clamp(0.0, _scroll.position.maxScrollExtent),
        );
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter(VoidCallback change) {
    setState(() {
      change();
      _page = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width <= 375;
    final side = small ? 21.0 : 25.0;
    final needle = _query.text.trim().toLowerCase();
    final matches = widget.chapters
        .where(
          (chapter) =>
              ('${chapter.title} ${chapter.place} ${chapter.number}'
                  .toLowerCase()
                  .contains(needle)) &&
              (_progress == 0 ||
                  (_progress == 2
                      ? widget.visited.contains(chapter.id)
                      : !widget.visited.contains(chapter.id))),
        )
        .toList();
    final pages = math.max(1, (matches.length / pageSize).ceil());
    final page = math.min(_page, pages - 1);
    final visible = matches.skip(page * pageSize).take(pageSize).toList();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Scaffold(
      backgroundColor: manualPaper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 13, side, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Text('本刊目录', style: manualType(10, spacing: .8)),
                        const SizedBox(width: 10),
                        Text(
                          'INDEX',
                          style: manualType(
                            8,
                            color: const Color(0xFF7B7C71),
                            spacing: 1.12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '关闭章节目录',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 21),
                        ),
                      ],
                    ),
                  ),
                  AnimatedPadding(
                    duration: duration,
                    padding: EdgeInsets.only(top: _compact ? 3 : 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSize(
                                duration: duration,
                                alignment: Alignment.topLeft,
                                child: _compact
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          left: 3,
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          '翻到',
                                          style: manualType(
                                            26,
                                            serif: true,
                                            height: 1.2,
                                            spacing: -.39,
                                          ),
                                        ),
                                      ),
                              ),
                              AnimatedDefaultTextStyle(
                                duration: duration,
                                style: manualType(
                                  _compact ? 29 : (small ? 51 : 57),
                                  serif: true,
                                  height: 1.04,
                                  weight: FontWeight.w600,
                                  spacing: _compact ? -1.9 : -4.5,
                                ),
                                child: const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: '哪一页'),
                                      TextSpan(
                                        text: '。',
                                        style: TextStyle(color: manualRed),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: small ? 74 : 82,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.routeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: manualType(
                                  9,
                                  color: const Color(0xFF727469),
                                  height: 1.65,
                                ),
                              ),
                              AnimatedSize(
                                duration: duration,
                                alignment: Alignment.topRight,
                                child: _compact
                                    ? const SizedBox.shrink()
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.chapters.length
                                                .toString()
                                                .padLeft(2, '0'),
                                            style: const TextStyle(
                                              fontFamily: 'Georgia',
                                              fontSize: 31,
                                              height: 1.15,
                                              color: manualRed,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '篇城市故事',
                                            style: manualType(8, spacing: .24),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: duration,
                    alignment: Alignment.topLeft,
                    child: _compact
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              '挑一页，从你感兴趣的地方开始。',
                              style: manualType(
                                10,
                                color: manualMuted,
                                height: 1.7,
                              ),
                            ),
                          ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 13),
                    height: 49,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: manualInk)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 19,
                          color: Color(0xFF65695D),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            onChanged: (_) => _filter(() {}),
                            style: manualType(16, spacing: -.4),
                            decoration: InputDecoration(
                              hintText: '找一个地点，或一段故事',
                              hintStyle: manualType(
                                16,
                                color: const Color(0xFF8B8C7E),
                                spacing: -.4,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.search,
                          ),
                        ),
                        if (_query.text.isNotEmpty)
                          IconButton(
                            tooltip: '清除搜索',
                            onPressed: () => _filter(_query.clear),
                            icon: const Icon(Icons.close, size: 17),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x30252824)),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          _DirectoryFilter(
                            label: const ['全部', '未翻阅', '翻过'][index],
                            selected: _progress == index,
                            onTap: () => _filter(() => _progress = index),
                          ),
                          if (index < 2) SizedBox(width: small ? 10 : 12),
                        ],
                        const Spacer(),
                        Text(
                          '${matches.length} 篇',
                          style: manualType(9, color: const Color(0xFF7B7F70)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(side + 24, 45, side, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '这一页，\n暂时留白。',
                              style: manualType(34, serif: true, spacing: -.85),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              widget.chapters.isEmpty
                                  ? '故事还在准备，稍后再来翻阅。'
                                  : '换一个词，或看看其他章节。',
                              style: manualType(11, color: manualMuted),
                            ),
                            if (widget.chapters.isNotEmpty)
                              TextButton(
                                onPressed: () => _filter(() {
                                  _query.clear();
                                  _progress = 0;
                                }),
                                child: Text(
                                  '查看全部故事  →',
                                  style: manualType(12, color: manualRed),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.symmetric(horizontal: side),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final chapter = visible[index];
                        final current = chapter.id == widget.currentId;
                        return Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0x22252824)),
                            ),
                          ),
                          child: InkWell(
                            key: ValueKey('directory-chapter-${chapter.id}'),
                            onTap: () async {
                              FocusScope.of(context).unfocus();
                              final mode = await showChapterPrelude(
                                context,
                                chapter: chapter,
                                routeName: widget.routeName,
                                count: widget.chapters.length,
                                fromDirectory: true,
                                resumeAt: widget.positions[chapter.id] ??
                                    Duration.zero,
                              );
                              if (mode != null && context.mounted) {
                                Navigator.pop(
                                  context,
                                  ManualChapterChoice(chapter, mode),
                                );
                              }
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 91),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Row(
                                  children: [
                                    ManualCircledNumber(
                                      text: chapter.folio,
                                      selected: current,
                                    ),
                                    SizedBox(width: small ? 11 : 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chapter.title,
                                            style: manualType(
                                              small ? 18 : 19,
                                              serif: true,
                                              color: current
                                                  ? manualRed
                                                  : manualInk,
                                              weight: FontWeight.w500,
                                              height: 1.45,
                                              spacing: -.57,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${chapter.place}  ·  ${chapter.durationLabel}',
                                            style: manualType(
                                              9,
                                              color: const Color(0xFF7A7E71),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 13),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 17,
                                      color: current
                                          ? manualRed
                                          : const Color(0xFF848779),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: side),
              padding: EdgeInsets.only(top: pages == 1 ? 17 : 10, bottom: 15),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: pages == 1 ? const Color(0x30252824) : manualInk,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pages > 1)
                    Row(
                      children: [
                        IconButton(
                          tooltip: '上一页章节',
                          onPressed:
                              page == 0 ? null : () => _movePage(page - 1),
                          icon: const Icon(Icons.chevron_left, size: 20),
                        ),
                        Expanded(
                          child: Center(
                            child: DropdownButton<int>(
                              value: page,
                              underline: const SizedBox.shrink(),
                              isDense: false,
                              style: manualType(11),
                              dropdownColor: manualPaper,
                              items: List.generate(
                                pages,
                                (index) => DropdownMenuItem(
                                  value: index,
                                  child: Text(
                                    '第 ${index * pageSize + 1}–${math.min((index + 1) * pageSize, matches.length)} 项 / ${matches.length}',
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value != null) _movePage(value);
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '下一页章节',
                          onPressed: page == pages - 1
                              ? null
                              : () => _movePage(page + 1),
                          icon: const Icon(Icons.chevron_right, size: 20),
                        ),
                      ],
                    ),
                  Text(
                    '${pages == 1 ? '—  ' : ''}按自己的节奏，一页一页走。',
                    style: manualType(
                      9,
                      color: const Color(0xFF818674),
                      spacing: .72,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _movePage(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }
}

class _DirectoryFilter extends StatelessWidget {
  const _DirectoryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            width: label.length > 2 ? 51 : 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Transform.rotate(
                    angle: -.209,
                    child: Container(
                      height: 30,
                      width: label.length > 2 ? 48 : 45,
                      decoration: BoxDecoration(
                        border: Border.all(color: manualRed),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                Text(
                  label,
                  style: manualType(
                    11,
                    color: selected ? manualRed : const Color(0xFF777C6E),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
