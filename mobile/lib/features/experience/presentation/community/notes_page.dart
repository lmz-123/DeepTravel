import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/community_models.dart';
import '../experience_providers.dart';
import '../widgets/discovery_art.dart';
import 'notes_controller.dart';
import 'notes_widgets.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});
  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  bool _citiesOpen = false, _more = false;
  final _busy = <String>{};
  Future<void> _mutate(CommunityPost post, bool save) async {
    if (!_busy.add(post.id)) return;
    setState(() {});
    final user = ref.read(currentUserIdProvider);
    try {
      final repo = ref.read(experienceRepositoryProvider);
      CommunityPost updated;
      if (save) {
        await repo.setCommunitySaved(post.id, !post.viewerHasSaved);
        updated = post.copyWith(viewerHasSaved: !post.viewerHasSaved);
      } else {
        final value =
            await repo.setCommunityLike(post.id, !post.viewerHasLiked);
        updated = post.copyWith(
            viewerHasLiked: value.liked, likeCount: value.likeCount);
      }
      if (mounted && user == ref.read(currentUserIdProvider)) {
        ref.read(notesFeedProvider.notifier).replace(updated);
        ref.invalidate(communityDetailControllerProvider(
            CommunityPostKey(user ?? 'demo', post.id)));
      }
    } catch (_) {
      if (mounted) noteNotice(context, '暂时无法更新，请重试');
    } finally {
      if (mounted) setState(() => _busy.remove(post.id));
    }
  }

  Future<void> _open(CommunityPost post) async {
    await context.push('/community/post/${post.id}');
    if (mounted) ref.invalidate(notesFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notesFeedProvider);
    final places = ref.watch(notesPlacesProvider);
    final selected = ref.watch(notesCityProvider);
    final cities = <String, String>{
      for (final p in places.value ?? <CommunityPlace>[]) p.citySlug: p.cityName
    };
    final cityName = cities[selected] ?? '全部城市';
    return NoteScaffold(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          height: 78,
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: noteLine))),
          child: DiscoveryBrand(
              editorial: true, onTap: () => context.push('/profile'))),
      Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: '见闻'),
                        TextSpan(
                            text: '.',
                            style: noteSerif(46, color: noteRed, height: 1.1))
                      ]),
                      style: noteSerif(
                              MediaQuery.sizeOf(context).width <= 360 ? 42 : 46,
                              height: 1.1,
                              weight: FontWeight.w500)
                          .copyWith(letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text('NOTES FROM THE WAY', style: noteItalic(10))
                ])),
            NoteArrow('留一则见闻',
                size: 14,
                icon: DiscoveryMark.pen,
                leadingIcon: true, onTap: () async {
              await context.push('/community/write');
              if (mounted) ref.invalidate(notesFeedProvider);
            })
          ])),
      Container(
          margin: const EdgeInsets.only(top: 6, bottom: 24),
          decoration: const BoxDecoration(
              border:
                  Border.symmetric(horizontal: BorderSide(color: noteLine))),
          child: Column(children: [
            NoteButton(
                key: const ValueKey('notes-city-toggle'),
                label: '选择城市，当前$cityName',
                onTap: () => setState(() => _citiesOpen = !_citiesOpen),
                child: SizedBox(
                    height: 62,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                              padding: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color:
                                              noteRed.withValues(alpha: .38)))),
                              child: Text(cityName, style: noteSerif(20))),
                          const SizedBox(width: 13),
                          AnimatedRotation(
                              turns: _citiesOpen ? -.25 : 0,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: const RotatedBox(
                                  quarterTurns: 1,
                                  child: DiscoveryIcon(
                                      DiscoveryMark.arrowUpRight,
                                      size: 17,
                                      color: noteRed)))
                        ]))),
            AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: !_citiesOpen
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        key: const ValueKey('notes-city-directory'),
                        padding: const EdgeInsets.only(top: 17, bottom: 20),
                        decoration: const BoxDecoration(
                            color: Color(0xfff9f5ed),
                            border: Border(top: BorderSide(color: noteLine))),
                        child: places.when(
                            data: (_) => LayoutBuilder(builder: (context, box) {
                                  final entries = <MapEntry<String?, String>>[
                                    const MapEntry(null, '全部'),
                                    ...cities.entries
                                  ];
                                  return Wrap(children: [
                                    for (var i = 0; i < entries.length; i++)
                                      SizedBox(
                                          width: box.maxWidth / 3,
                                          child: _CityChoice(
                                              entries[i],
                                              selected == entries[i].key,
                                              i % 3 != 0, () {
                                            ref
                                                .read(
                                                    notesCityProvider.notifier)
                                                .select(entries[i].key);
                                            setState(() => _citiesOpen = false);
                                          }))
                                  ]);
                                }),
                            error: (_, __) => NoteFailure('城市暂时无法读取',
                                () => ref.invalidate(notesPlacesProvider)),
                            loading: () => const SizedBox(
                                height: 78,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1, color: noteQuiet))))))
          ])),
      feed.when(
          skipLoadingOnRefresh: true,
          data: (page) => Column(children: [
                if (page.items.isEmpty)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 62),
                      child: Column(children: [
                        Text('这里还没有见闻。', style: noteSerif(23)),
                        const SizedBox(height: 10),
                        Text('留下你在路上的第一则记录。',
                            style: noteSans(12, color: noteQuiet))
                      ])),
                for (var i = 0; i < page.items.length; i++)
                  _card(page.items[i], i),
                if (page.hasMore)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: NoteArrow(_more ? '正在加载' : '更多见闻',
                          onTap: _more
                              ? null
                              : () async {
                                  setState(() => _more = true);
                                  try {
                                    await ref
                                        .read(notesFeedProvider.notifier)
                                        .loadMore();
                                  } catch (_) {
                                    if (context.mounted) {
                                      noteNotice(context, '加载失败，请重试');
                                    }
                                  } finally {
                                    if (mounted) setState(() => _more = false);
                                  }
                                }))
              ]),
          loading: () => const Padding(
              padding: EdgeInsets.all(70),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 1, color: noteQuiet))),
          error: (_, __) =>
              NoteFailure('见闻暂时无法读取', () => ref.invalidate(notesFeedProvider))),
      const SizedBox(height: 24)
    ]));
  }

  Widget _card(CommunityPost post, int index) => Container(
      key: ValueKey('note-${post.id}'),
      padding: EdgeInsets.only(top: index > 0 ? 20 : 0),
      decoration: index > 0
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: noteLine)))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NoteAuthor(post),
        NotePhoto(post, onTap: () => _open(post)),
        if (post.title?.isNotEmpty == true)
          Padding(
              padding: const EdgeInsets.only(top: 17),
              child: NoteButton(
                  label: '查看动态详情',
                  onTap: () => _open(post),
                  child: Text(post.title!,
                      style: noteSerif(
                          MediaQuery.sizeOf(context).width <= 360 ? 21 : 23,
                          weight: FontWeight.w500)))),
        if (post.body.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 7),
              child: NoteButton(
                  label: '查看动态正文',
                  onTap: () => _open(post),
                  child: Text(post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: noteSans(12,
                          color: const Color(0xff626656), height: 1.9)))),
        NotePlaceRow(post, onOpen: () => _open(post)),
        NoteActions(post,
            onLike: _busy.contains(post.id) ? null : () => _mutate(post, false),
            onSave: _busy.contains(post.id) ? null : () => _mutate(post, true),
            onComments: () => _open(post))
      ]));
}

class _CityChoice extends StatelessWidget {
  const _CityChoice(this.city, this.selected, this.line, this.tap);
  final MapEntry<String?, String> city;
  final bool selected, line;
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => NoteButton(
      key: ValueKey('notes-city-${city.key ?? 'all'}'),
      label: city.value,
      selected: selected,
      onTap: tap,
      child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              border: line
                  ? const Border(left: BorderSide(color: noteLine))
                  : null),
          child: Stack(children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(city.value,
                      style: noteSerif(24,
                          color: selected ? noteRed : noteInk, height: 1.3)),
                  const SizedBox(height: 8),
                  Text(
                      city.key?.replaceAll('-', ' ').toUpperCase() ??
                          'ALL CITIES',
                      style: noteItalic(9))
                ]),
            if (selected) ...[
              const Positioned(
                  right: 0,
                  top: 6,
                  child: DiscoveryIcon(DiscoveryMark.check,
                      size: 12, color: noteRed)),
              Positioned(
                  left: 0,
                  bottom: 0,
                  child: Transform.rotate(
                      angle: -.1,
                      child: Container(width: 17, height: 1, color: noteRed)))
            ]
          ])));
}
