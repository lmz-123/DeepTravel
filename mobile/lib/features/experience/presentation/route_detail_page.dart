import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_back.dart';
import '../../../core/router/travel_destinations.dart';
import '../domain/models.dart';
import 'active_tour_controller.dart' show tourStoreProvider;
import 'experience_providers.dart';
import 'home_story_controller.dart';
import 'offline_package_controller.dart' show offlineAwareRouteProvider;
import 'route_manual/chapter_directory.dart';
import 'route_manual/chapter_focus.dart';
import 'route_manual/chapter_prelude.dart';
import 'route_manual/manual_chapter.dart';
import 'route_manual/manual_session.dart';
import 'route_manual/manual_visuals.dart';
import 'route_manual/route_companion_entry.dart';
import 'widgets/favorite_button.dart';
import 'widgets/editorial_listening.dart' show EditorialPageArrival;

class RouteDetailPage extends ConsumerWidget {
  const RouteDetailPage({required this.slug, super.key});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(offlineAwareRouteProvider(slug)).when(
            loading: () => const Scaffold(
              backgroundColor: manualPaper,
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Scaffold(
              backgroundColor: manualPaper,
              appBar: AppBar(),
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(offlineAwareRouteProvider(slug)),
                  child: const Text('重新加载路线'),
                ),
              ),
            ),
            data: (route) => _RouteDetail(
              key: ValueKey('${ref.watch(currentUserIdProvider)}:${route.id}'),
              route: route,
            ),
          );
}

class _RouteDetail extends ConsumerStatefulWidget {
  const _RouteDetail({required this.route, super.key});
  final RouteExperience route;
  @override
  ConsumerState<_RouteDetail> createState() => _RouteDetailState();
}

class _RouteDetailState extends ConsumerState<_RouteDetail> {
  final _scroll = ScrollController();
  final _opening = GlobalKey();
  final _allChapters = GlobalKey();
  final _bookmarks = GlobalKey();
  ManualChapterChoice? _focus;
  bool _dock = false;
  bool _bookmarksLit = false;
  bool _overlay = false;
  Timer? _highlightTimer;
  late HomeStoryPlaybackController _playback;
  late ManualSessionController _session;

  List<ManualChapter> get chapters => routeManualChapters(widget.route);

  @override
  void initState() {
    super.initState();
    _playback = ref.read(homeStoryPlaybackControllerProvider.notifier);
    _session = ref.read(manualSessionProvider(widget.route.id).notifier);
    _scroll.addListener(_measureDock);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _highlightTimer?.cancel();
    // Invalidate any in-flight explicit play before this route leaves the tree.
    if (_focus != null) unawaited(_playback.pause());
    super.dispose();
  }

  Future<void> _pause() async {
    final state = ref.read(homeStoryPlaybackControllerProvider);
    final chapter = _focus?.chapter;
    if (state.source == ListeningSource.manualChapter &&
        (state.story?.id.startsWith('manual:${widget.route.id}:') ?? false)) {
      if (chapter != null) {
        await _session.remember(chapter.id, position: state.position);
      }
      await _playback.pause();
    }
  }

  Future<void> _directory() async {
    await _pause();
    if (!mounted) return;
    setState(() => _overlay = true);
    final session =
        ref.read(manualSessionProvider(widget.route.id)).asData?.value ??
            const ManualReadingSession();
    final choice = await showChapterDirectory(
      context,
      chapters: chapters,
      routeName: widget.route.title,
      visited: session.visited,
      currentId:
          _focus?.chapter.id ?? session.currentId ?? chapters.firstOrNull?.id,
      positions: session.positions,
    );
    if (!mounted) return;
    setState(() => _overlay = false);
    if (choice != null) await _enter(choice);
    _measureDock();
  }

  Future<void> _prelude(ManualChapter chapter) async {
    await _pause();
    if (!mounted) return;
    setState(() => _overlay = true);
    final session =
        ref.read(manualSessionProvider(widget.route.id)).asData?.value ??
            const ManualReadingSession();
    final mode = await showChapterPrelude(
      context,
      chapter: chapter,
      routeName: widget.route.title,
      count: chapters.length,
      resumeAt: session.positions[chapter.id] ?? Duration.zero,
    );
    if (!mounted) return;
    setState(() => _overlay = false);
    if (mode == ManualChapterMode.directory) {
      await _directory();
    } else if (mode != null) {
      await _enter(ManualChapterChoice(chapter, mode));
    }
  }

  Future<void> _enter(ManualChapterChoice choice) async {
    await _pause();
    if (!mounted) return;
    await _session.remember(choice.chapter.id, opened: true);
    if (!mounted) return;
    setState(() => _focus = choice);
    if (choice.mode == ManualChapterMode.audio) {
      final session =
          ref.read(manualSessionProvider(widget.route.id)).asData?.value;
      String? preparedPath;
      try {
        preparedPath = await preparedManualChapterPath(
          ref.read(tourStoreProvider),
          widget.route,
          choice.chapter.fragment!,
        );
      } catch (_) {
        // A missing local cache can still play the original published URL.
      }
      if (!mounted ||
          _overlay ||
          _focus?.chapter.id != choice.chapter.id ||
          _focus?.mode != ManualChapterMode.audio) {
        return;
      }
      await _playback.loadManualChapter(
        widget.route,
        choice.chapter.fragment!,
        coverImage: choice.chapter.image,
        place: choice.chapter.place,
        preparedPath: preparedPath,
        resumePosition: session?.positions[choice.chapter.id] ?? Duration.zero,
      );
      if (mounted &&
          !_overlay &&
          _focus?.chapter.id == choice.chapter.id &&
          _focus?.mode == ManualChapterMode.audio) {
        await _playback.play();
      }
    }
  }

  Future<void> _toggle() async {
    final chapter = _focus?.chapter;
    if (chapter == null || !chapter.hasAudio) return;
    final state = ref.read(homeStoryPlaybackControllerProvider);
    if (state.source == ListeningSource.manualChapter &&
        (state.story?.id.startsWith(
              'manual:${widget.route.id}:${chapter.id}:',
            ) ??
            false)) {
      await _playback.toggle();
    } else {
      await _enter(ManualChapterChoice(chapter, ManualChapterMode.audio));
    }
  }

  Future<void> _leaveFocus() async {
    await _pause();
    if (!mounted) return;
    setState(() => _focus = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureDock());
  }

  void _measureDock() {
    if (!mounted || _focus != null) return;
    final opening = _opening.currentContext?.findRenderObject() as RenderBox?;
    final ending =
        _allChapters.currentContext?.findRenderObject() as RenderBox?;
    final startTop = opening?.localToGlobal(Offset.zero).dy;
    final endTop = ending?.localToGlobal(Offset.zero).dy;
    final height = MediaQuery.sizeOf(context).height;
    final endVisible =
        endTop != null && endTop < height && endTop + ending!.size.height > 0;
    final next = startTop != null &&
        startTop + opening!.size.height < MediaQuery.paddingOf(context).top &&
        !endVisible;
    if (_dock != next) setState(() => _dock = next);
  }

  Future<void> _revealBookmarks() async {
    final target = _bookmarks.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    setState(() => _bookmarksLit = true);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _bookmarksLit = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final items = chapters;
    final canStart = items.isNotEmpty;
    final hasAudio = items.any((chapter) => chapter.hasAudio);
    final canCompanion = route.audioTour?.fragments.isNotEmpty ?? false;
    final session = ref.watch(manualSessionProvider(route.id)).asData?.value ??
        const ManualReadingSession();
    ref.listen(homeStoryPlaybackControllerProvider, (previous, next) {
      final selected = _focus?.chapter;
      if (selected != null &&
          next.source == ListeningSource.manualChapter &&
          (next.story?.id.startsWith('manual:${route.id}:${selected.id}:') ??
              false) &&
          (previous?.position.inSeconds ?? -1) ~/ 5 !=
              next.position.inSeconds ~/ 5) {
        unawaited(_session.remember(selected.id, position: next.position));
      }
    });
    final narrow = MediaQuery.sizeOf(context).width <= 375;
    final side = narrow ? 18.0 : 22.0;
    final focus = _focus;
    return PopScope(
      canPop: focus == null && Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_focus != null) {
          unawaited(_leaveFocus());
        } else {
          GoRouter.maybeOf(context)?.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: focus == null ? manualPaper : manualInk,
        body: Stack(
          children: [
            Offstage(
              offstage: focus != null,
              child: SafeArea(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(side, 0, side, 116),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 76,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0x35252824)),
                          ),
                        ),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await _pause();
                                if (context.mounted) popOrGo(context, '/');
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(100, 48),
                                foregroundColor: manualInk,
                              ),
                              icon: const Icon(Icons.arrow_back, size: 19),
                              label: Text(
                                route.cityName.isEmpty
                                    ? '回到城市'
                                    : '回到${route.cityName}',
                                style: manualType(13, weight: FontWeight.w500),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x45252824),
                                ),
                              ),
                              child: FavoriteButton(
                                kind: 'route',
                                targetId: route.id,
                                color: manualInk,
                                filledWhenSelected: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Text(
                            route.cityName.isEmpty
                                ? '见地 / 城市手册'
                                : route.cityName,
                            style: manualType(
                              10,
                              weight: FontWeight.w600,
                              spacing: .6,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Flexible(
                            child: Text(
                              route.theme,
                              style: manualType(
                                10,
                                color: manualRed,
                                weight: FontWeight.w600,
                                spacing: .6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 17),
                        child: Text(
                          route.title.replaceAll(' · ', '\n'),
                          style: manualType(
                            narrow ? 55 : 62,
                            serif: true,
                            weight: FontWeight.w600,
                            height: 1.1,
                            spacing: narrow ? -3 : -3.4,
                          ),
                        ),
                      ),
                      Text(route.subtitle, style: manualType(17, height: 1.55)),
                      Padding(
                        padding: const EdgeInsets.only(top: 13, bottom: 12),
                        child: Text(
                          '${route.durationMinutes} 分钟   /   ${route.distanceKm} km   /   ${items.length} 段${hasAudio ? '声音' : '文字'}',
                          style: manualType(
                            11,
                            color: manualRed,
                            weight: FontWeight.w500,
                            height: 1.6,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 310),
                        child: Text(
                          hasAudio
                              ? '把城市翻成一页页故事。选一篇，听见眼前，也读懂沿途。'
                              : '把城市翻成一页页故事。从感兴趣的地方开始，按自己的节奏慢慢读。',
                          style: manualType(
                            13,
                            color: const Color(0xFF62635C),
                            height: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      if (canStart)
                        ManualPaperAction(
                          key: _opening,
                          folio: items.length.toString().padLeft(2, '0'),
                          label:
                              session.visited.isEmpty ? '翻开这段旅程' : '继续翻阅这段旅程',
                          subtitle: hasAudio ? '先选一篇，再听或读' : '先选一篇，慢慢读',
                          onPressed: _directory,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text('这份手册，正在写给你。', style: manualType(14)),
                        ),
                      const SizedBox(height: 11),
                      Text(
                        canStart
                            ? (hasAudio
                                ? '${items.length} 篇声音 · 可听，也可读'
                                : '${items.length} 段文字 · 按自己的节奏')
                            : '可以先收藏，留给下次',
                        style: manualType(11, color: const Color(0xFF61645B)),
                      ),
                      if (canCompanion) ...[
                        const SizedBox(height: 14),
                        RouteCompanionEntry(
                          key: const ValueKey('route-companion-entry'),
                          routeName: route.title,
                          onTap: _openCompanion,
                        ),
                      ],
                      if (route.audioTour?.productionReady == false &&
                          (route.audioTour?.demoLabel?.isNotEmpty ?? false))
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(route.audioTour!.demoLabel!,
                                style: manualType(10,
                                    color: manualMuted, height: 1.7))),
                      SizedBox(height: canCompanion ? 18 : 30),
                      Padding(
                        padding: const EdgeInsets.only(left: 25),
                        child: SizedBox(
                          height: narrow ? 335 : 360,
                          child: Stack(
                            clipBehavior: Clip.none,
                            fit: StackFit.expand,
                            children: [
                              ManualPhoto(source: route.heroImage),
                              if (canCompanion)
                                Positioned(
                                  left: -19,
                                  top: 0,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      route.cityName == '上海'
                                          ? 'SHANGHAI, ON FOOT.'
                                          : 'THE CITY, ON FOOT.',
                                      style: manualType(
                                        9,
                                        height: 1,
                                        spacing: 1.3,
                                        color: const Color(0xFF767868),
                                      ),
                                    ),
                                  ),
                                ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0x99162217),
                                    ],
                                    stops: [.6, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 18,
                                bottom: 17,
                                right: 18,
                                child: Text(
                                  '一份写给行走者的城市手册',
                                  style: manualType(
                                    9,
                                    color: Colors.white,
                                    spacing: .27,
                                  ),
                                ),
                              ),
                              if (canStart)
                                Positioned(
                                  left: -25,
                                  bottom: 28,
                                  child: Transform.rotate(
                                    angle: -math.pi / 15,
                                    child: Semantics(
                                      button: true,
                                      label: '慢慢走，才看得见：看看沿途书签',
                                      child: Material(
                                        color: const Color(0xFFE1E8B4),
                                        shape: const CircleBorder(
                                          side: BorderSide(
                                            color: Color(0x35596044),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: _revealBookmarks,
                                          child: SizedBox(
                                            width: 98 *
                                                MediaQuery.textScalerOf(context)
                                                    .scale(1),
                                            height: 98 *
                                                MediaQuery.textScalerOf(context)
                                                    .scale(1),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '慢慢走\n才看得见',
                                                  textAlign: TextAlign.center,
                                                  style: manualType(
                                                    12,
                                                    weight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: Color(
                                                          0x70525944,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '看看沿途',
                                                    style: manualType(
                                                      10,
                                                      color: const Color(
                                                        0xFF525944,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.south,
                                                  size: 17,
                                                  color: manualInk,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: manualInk),
                          ),
                        ),
                        child: Row(
                          children: [
                            _Fact(
                              number: '${route.durationMinutes}',
                              label: '分钟 / 留一点时间',
                              narrow: narrow,
                            ),
                            _Fact(
                              number: '${route.distanceKm}',
                              suffix: 'km',
                              label: '路线长度 / 从容慢行',
                              narrow: narrow,
                            ),
                            _Fact(
                              number: items.length.toString().padLeft(2, '0'),
                              label: hasAudio ? '段声音 / 关于眼前' : '段文字 / 认识这里',
                              narrow: narrow,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 41),
                      Text(
                        '01 / WHY THIS WALK',
                        style: manualType(
                          9,
                          color: const Color(0xFF686B61),
                          weight: FontWeight.w600,
                          spacing: 1.08,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        '把脚步放慢，\n让城市展开。',
                        style: manualType(
                          31,
                          serif: true,
                          weight: FontWeight.w500,
                          spacing: -.93,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(route.description, style: manualType(14, height: 2)),
                      const SizedBox(height: 15),
                      Text(
                        hasAudio ? '到现场听，也可以先在这里认识它。' : '这条路线当前提供文字手册，暂不提供音频。',
                        style: manualType(
                          11,
                          color: const Color(0xFF686B61),
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 44),
                      if (canStart) ...[
                        Container(
                          key: _bookmarks,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '02 / BOOKMARKS ALONG THE WAY',
                                style: manualType(
                                  9,
                                  color: const Color(0xFF686B61),
                                  weight: FontWeight.w600,
                                  spacing: 1.08,
                                ),
                              ),
                              const SizedBox(height: 10),
                              IntrinsicWidth(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(text: '沿途书签'),
                                          TextSpan(
                                            text: '，',
                                            style: manualType(
                                              32,
                                              serif: true,
                                              color: manualRed,
                                            ),
                                          ),
                                          const TextSpan(text: '\n先翻几页。'),
                                        ],
                                      ),
                                      style: manualType(
                                        32,
                                        serif: true,
                                        weight: FontWeight.w500,
                                        height: 1.5,
                                        spacing: -1.6,
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: MediaQuery.disableAnimationsOf(
                                        context,
                                      )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 600),
                                      height: 1,
                                      width: _bookmarksLit ? 200 : 0,
                                      color: manualRed,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '预览 ${math.min(3, items.length)} 篇 · 共 ${items.length} 篇',
                                style: manualType(
                                  10,
                                  color: const Color(0xFF686B61),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Divider(height: 1, color: manualInk),
                              for (final chapter in items.take(3))
                                _Bookmark(
                                  chapter: chapter,
                                  onTap: () => _prelude(chapter),
                                ),
                              Container(
                                key: _allChapters,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0x66252824),
                                    ),
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: _directory,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      68,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Wrap(
                                              spacing: 12,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                            Text('翻开全部目录',
                                                style: manualType(17,
                                                    serif: true,
                                                    color: manualRed)),
                                            Text('${items.length} 篇',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontFamily: 'Georgia',
                                                    fontStyle: FontStyle.italic,
                                                    color: Color(0xFF827662))),
                                          ])),
                                      const Icon(
                                        Icons.format_list_bulleted,
                                        size: 20,
                                        color: manualRed,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                '不必按顺序，停在你感兴趣的那一页。',
                                style: manualType(
                                  11,
                                  color: const Color(0xFF837B69),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                      Container(
                        padding: const EdgeInsets.only(top: 27, bottom: 32),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: manualInk)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 12,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '见地',
                                  style: manualType(
                                    26,
                                    serif: true,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'JIAN DI',
                                  style: manualType(8, spacing: 1.2),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => popOrGo(context, '/'),
                              child: Text('回到城市  →', style: manualType(12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (focus != null)
              EditorialPageArrival(
                key: ValueKey('${focus.chapter.id}:${focus.mode}'),
                child: ManualChapterFocus(
                  route: route,
                  chapter: focus.chapter,
                  chapters: items,
                  mode: focus.mode,
                  onBack: _leaveFocus,
                  onDirectory: _directory,
                  onSelect: _prelude,
                  onListen: _toggle,
                  onRead: () => _enter(
                    ManualChapterChoice(focus.chapter, ManualChapterMode.text),
                  ),
                ),
              ),
            if (focus == null && _dock && !_overlay && canStart)
              Positioned(
                left: narrow ? 17 : 20,
                right: narrow ? 17 : 20,
                bottom: 14 + MediaQuery.paddingOf(context).bottom,
                child: _DirectoryDock(count: items.length, onTap: _directory),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCompanion() async {
    await _pause();
    if (!mounted) return;
    context.go(companionLocation(widget.route.slug, requestSelection: true));
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.number,
    required this.label,
    required this.narrow,
    this.suffix,
  });
  final String number;
  final String label;
  final String? suffix;
  final bool narrow;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: number),
                  if (suffix != null)
                    TextSpan(
                      text: ' $suffix',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: narrow ? 32 : 36,
                height: 1,
                color: manualInk,
              ),
            ),
            const SizedBox(height: 9),
            Text(label, style: manualType(9, height: 1.6)),
          ],
        ),
      );
}

class _Bookmark extends StatelessWidget {
  const _Bookmark({required this.chapter, required this.onTap});
  final ManualChapter chapter;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x35252824))),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Row(
              children: [
                SizedBox(
                  width: 35,
                  child: Text(
                    chapter.folio,
                    style: const TextStyle(
                      fontSize: 27,
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFB17661),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.place,
                        style: manualType(10, color: const Color(0xFF696C62)),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        chapter.title,
                        style: manualType(17,
                            serif: true, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.north_east,
                    size: 21, color: Color(0xFF61645B)),
              ],
            ),
          ),
        ),
      );
}

class _DirectoryDock extends StatelessWidget {
  const _DirectoryDock({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 9, 10, 9),
        decoration: BoxDecoration(
          color: const Color(0xF5F7F2E8),
          border: Border.all(color: const Color(0x6BB3A08C)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(23),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1830271C),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
            BoxShadow(color: Color(0xFFE6DFD2), offset: Offset(-3, 3)),
          ],
        ),
        child: Row(
          children: [
            Text(
              count.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: Color(0xFF8D7258),
              ),
            ),
            const SizedBox(width: 7),
            Text('篇', style: manualType(10, color: const Color(0xFF776B59))),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0x75B3A08C))),
                ),
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 19,
                        color: Color(0xFFAC3F2F),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '翻开目录',
                        style: manualType(
                          18,
                          serif: true,
                          color: const Color(0xFFAC3F2F),
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: Color(0xFFAC3F2F),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
