import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/community_models.dart';
import '../experience_providers.dart';
import '../widgets/discovery_art.dart';
import 'notes_controller.dart';
import 'notes_widgets.dart';
import 'notes_filters.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});
  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  bool _more = false;
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
        ref.invalidate(savedNotesProvider);
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

  Future<void> _open(CommunityPost post, [int photo = 0]) async {
    await context.push('/community/post/${post.id}?photo=$photo');
    if (mounted) ref.invalidate(notesFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notesFeedProvider);
    return NoteScaffold(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          height: 72,
          child: Row(children: [
            DiscoveryBrand(title: '见闻', onTap: () => context.push('/profile'))
          ])),
      Padding(
          padding: const EdgeInsets.only(top: 1, bottom: 18),
          child: Row(children: [
            Expanded(child: Text('NOTES FROM THE WAY', style: noteItalic(10))),
            NoteArrow('留一则见闻',
                size: 13,
                icon: DiscoveryMark.pen,
                leadingIcon: true, onTap: () async {
              await context.push('/community/write');
              if (mounted) ref.invalidate(notesFeedProvider);
            })
          ])),
      const NotesFilterBar(),
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
        NotePhoto(post,
            onTap: () => _open(post), onPhotoTap: (i) => _open(post, i)),
        if (post.title?.isNotEmpty == true)
          Padding(
              padding: const EdgeInsets.only(top: 6),
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
