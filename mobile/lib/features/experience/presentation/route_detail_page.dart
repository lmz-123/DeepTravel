import 'dart:async';

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
import 'widgets/traveler_bottom_navigation.dart';
import 'widgets/discovery_art.dart';
import 'city_atlas.dart' show cityAtlasCategory;
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
  ManualChapterChoice? _focus;
  bool _overlay = false;
  late HomeStoryPlaybackController _playback;
  late ManualSessionController _session;

  List<ManualChapter> get chapters => routeManualChapters(widget.route);

  @override
  void initState() {
    super.initState();
    _playback = ref.read(homeStoryPlaybackControllerProvider.notifier);
    _session = ref.read(manualSessionProvider(widget.route.id).notifier);
  }

  @override
  void dispose() {
    _scroll.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final items = chapters;
    final canCompanion = route.audioTour?.fragments.isNotEmpty ?? false;
    ref.watch(manualSessionProvider(route.id));
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
    final side = narrow ? 20.0 : 23.0;
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
                        height: 65,
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xffd7d2c5)))),
                        child: Row(children: [
                          TextButton.icon(
                            onPressed: () async {
                              await _pause();
                              if (context.mounted) popOrGo(context, '/');
                            },
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: const Color(0xff807664)),
                            icon: const DiscoveryIcon(DiscoveryMark.arrowLeft,
                                size: 17),
                            label: Text('景区详情',
                                style: manualType(12,
                                    color: const Color(0xff807664))),
                          ),
                          const Spacer(),
                          FavoriteButton(
                              kind: 'route',
                              targetId: route.id,
                              mark: DiscoveryMark.heart),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 23, bottom: 12),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  [route.cityName, route.district]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: manualType(11,
                                      color: const Color(0xff807664)))),
                          Text(cityAtlasCategory(route),
                              style: manualType(11, color: manualRed)),
                        ]),
                      ),
                      const SizedBox(height: 3),
                      _EditorialCover(route: route, narrow: narrow),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 330),
                            child: Text(
                                route.subtitle.isNotEmpty
                                    ? route.subtitle
                                    : route.description,
                                style: manualType(13,
                                    color: const Color(0xff606657),
                                    height: 1.95))),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 15, bottom: 19),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0xffd7d2c5)))),
                        child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 13,
                            runSpacing: 8,
                            children: [
                              _EditorialFact('${route.durationMinutes}', '分钟'),
                              Text('·',
                                  style: manualType(11, color: manualMuted)),
                              _EditorialFact(
                                  route.distanceKm.toStringAsFixed(1), 'km'),
                              Text('·',
                                  style: manualType(11, color: manualMuted)),
                              Text('文字漫游',
                                  style: manualType(11,
                                      color: const Color(0xff807664))),
                            ]),
                      ),
                      if (canCompanion)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 12),
                          child: RouteCompanionEntry(
                              key: const ValueKey('route-companion-entry'),
                              routeName: route.title,
                              onTap: _openCompanion),
                        ),
                      Row(children: [
                        Expanded(
                            child: Text('沿途故事',
                                style: manualType(24,
                                    serif: true,
                                    weight: FontWeight.w500,
                                    color: const Color(0xff30372d)))),
                        TextButton(
                          key: const ValueKey('route-directory-entry'),
                          onPressed: items.isEmpty ? null : _directory,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: Text('全部 ${items.length} 篇 ↗',
                              style: manualType(11,
                                  color: const Color(0xff807664))),
                        ),
                      ]),
                      const SizedBox(height: 7),
                      for (final chapter in items.take(3))
                        _EditorialChapter(
                            chapter: chapter, onTap: () => _prelude(chapter)),
                      if (items.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('故事正在编写中',
                                style: manualType(13, color: manualMuted))),
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
            if (focus == null && !_overlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TravelerBottomNavigation(
                    editorial: true,
                    active: TravelerSection.journal,
                    onSelected: (section) async {
                      await _pause();
                      if (!context.mounted) return;
                      if (section == TravelerSection.companion) {
                        await _openCompanion();
                      } else if (section == TravelerSection.journal) {
                        popOrGo(context, '/');
                      } else {
                        context.go('/?tab=atlas');
                      }
                    }),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCompanion() async {
    await _pause();
    if (!mounted) return;
    final supported = widget.route.audioTour?.fragments.isNotEmpty ?? false;
    context.go(companionLocation(supported ? widget.route.slug : null,
        requestSelection: supported));
  }
}

class _EditorialCover extends StatelessWidget {
  const _EditorialCover({required this.route, required this.narrow});
  final RouteExperience route;
  final bool narrow;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final style = manualType(narrow ? 52 : 57,
            serif: true,
            height: 1.19,
            weight: FontWeight.w600,
            spacing: -3.0,
            color: const Color(0xff30372d));
        final title = TextPainter(
            text: TextSpan(text: route.title, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context))
          ..layout(maxWidth: constraints.maxWidth - 16);
        final titleHeight = title.height + 11;
        title.dispose();
        return SizedBox(
            height: titleHeight - 20 + (narrow ? 219 : 234),
            child: Stack(children: [
              Positioned(
                  left: narrow ? 21 : 24,
                  right: 0,
                  top: titleHeight - 20,
                  bottom: 0,
                  child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(67)),
                      child: route.heroImage.isEmpty
                          ? _fallback()
                          : Image.network(route.heroImage,
                              frameBuilder: (_, child, frame, __) =>
                                  frame == null
                                      ? child
                                      : ColorFiltered(
                                          colorFilter: discoveryPhotoTone(.78),
                                          child: child),
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, .08),
                              errorBuilder: (_, __, ___) => _fallback()))),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                          padding: const EdgeInsets.only(right: 16, bottom: 11),
                          decoration: const BoxDecoration(
                              color: manualPaper,
                              borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(23))),
                          child: Text(route.title, style: style)))),
            ]));
      });
  Widget _fallback() => ColoredBox(
      color: const Color(0xffdce0c9),
      child: Center(
          child: Text(route.title.characters.firstOrNull ?? '',
              style: manualType(110,
                  serif: true, color: const Color(0xff687355)))));
}

class _EditorialFact extends StatelessWidget {
  const _EditorialFact(this.value, this.unit);
  final String value, unit;
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(
            text: value,
            style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontStyle: FontStyle.italic,
                height: 1.2,
                color: Color(0xff30372d))),
        TextSpan(
            text: '  $unit',
            style: manualType(11, color: const Color(0xff807664))),
      ]));
}

class _EditorialChapter extends StatelessWidget {
  const _EditorialChapter({required this.chapter, required this.onTap});
  final ManualChapter chapter;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xffd7d2c5)))),
      child: DiscoveryTouch(
        label: chapter.title,
        onTap: onTap,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  SizedBox(
                      width: 22,
                      child: Text(chapter.folio,
                          style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                              color: manualRed))),
                  const SizedBox(width: 17),
                  Expanded(
                      child: Text(chapter.title,
                          style: manualType(17,
                              serif: true,
                              height: 1.6,
                              weight: FontWeight.w500,
                              color: const Color(0xff30372d)))),
                  const SizedBox(width: 12),
                  const DiscoveryIcon(DiscoveryMark.arrowRight,
                      size: 16, color: Color(0xff898d7d)),
                ]))),
      ));
}
