import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/community_models.dart';
import '../experience_providers.dart';
import '../widgets/discovery_art.dart';
import 'notes_controller.dart';
import 'notes_widgets.dart';
import '../travel/guide_preparation.dart';
import '../travel/preparation_visuals.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({super.key, required this.postId, this.photoIndex = 0});
  final String postId;
  final int photoIndex;
  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  final _reply = TextEditingController();
  final _commentsKey = GlobalKey();
  String _commentId = const Uuid().v4();
  bool _saving = false;
  CommunityComment? _replyTo;
  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _save(CommunityPost p, CommunityPostKey key) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(experienceRepositoryProvider)
          .setCommunitySaved(p.id, !p.viewerHasSaved);
      if (mounted) {
        ref.invalidate(communityDetailControllerProvider(key));
        ref.invalidate(notesFeedProvider);
        ref.invalidate(savedNotesProvider);
      }
    } catch (_) {
      if (mounted) noteNotice(context, '收藏未能更新，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (old, value) {
      if (old != value) {
        _reply.clear();
        _replyTo = null;
        _commentId = const Uuid().v4();
      }
    });
    final key = CommunityPostKey(
        ref.watch(currentUserIdProvider) ?? 'demo', widget.postId);
    final async = ref.watch(communityDetailControllerProvider(key));
    final controller =
        ref.read(communityDetailControllerProvider(key).notifier);
    ref.listen(communityDetailControllerProvider(key), (previous, next) {
      final message = next.asData?.value.message;
      if (message != null && message != previous?.asData?.value.message) {
        noteNotice(context, message);
      }
    });
    final isGuide =
        async.asData?.value.post.category == CommunityCategory.guide;
    final content = async.when(
        skipLoadingOnRefresh: true,
        loading: () => Column(children: [
              const NoteTop('动态详情'),
              const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 1, color: noteQuiet))
            ]),
        error: (_, __) => Column(children: [
              const NoteTop('动态详情'),
              NoteFailure('这则见闻暂时无法打开',
                  () => ref.invalidate(communityDetailControllerProvider(key)))
            ]),
        data: (state) {
          final p = state.post;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isGuide) ...[
                  NoteTop('动态详情',
                      trailing: NoteButton(
                          label: p.viewerHasSaved ? '取消收藏' : '收藏见闻',
                          onTap: _saving ? null : () => _save(p, key),
                          child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                  child: DiscoveryIcon(DiscoveryMark.bookmark,
                                      size: 17,
                                      color: noteRed,
                                      filled: p.viewerHasSaved))))),
                  NoteAuthor(p),
                  NoteGallery(p, initialIndex: widget.photoIndex),
                  if (p.title?.isNotEmpty == true)
                    Padding(
                        padding: const EdgeInsets.only(top: 17, bottom: 11),
                        child: Text(p.title!, style: noteSerif(27))),
                  Text(p.body,
                      style: noteSans(13,
                          color: const Color(0xff525748), height: 2)),
                  if (p.category == CommunityCategory.guide &&
                      p.preparationItems.isNotEmpty)
                    GuideChecklist(p),
                  NotePlaceRow(p, detail: true),
                  NoteActions(p,
                      onLike: state.isMutating
                          ? null
                          : () async {
                              await controller.toggleLike();
                              if (mounted) ref.invalidate(notesFeedProvider);
                            },
                      onSave: _saving ? null : () => _save(p, key),
                      onComments: () => Scrollable.ensureVisible(
                          _commentsKey.currentContext!,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220))),
                ] else ...[
                  GuideByline(p),
                  Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 21),
                      child: Text(preparationTitle(p.title ?? '攻略'),
                          style: noteSerif(
                                  MediaQuery.sizeOf(context).width < 350
                                      ? 27
                                      : 30,
                                  weight: FontWeight.w500)
                              .copyWith(letterSpacing: -.7))),
                  Row(children: [
                    Expanded(
                        child: Text(
                            noteTime(p.createdAt).replaceAll(' · ', ' '),
                            style: noteSans(11, color: noteQuiet))),
                    Text(p.place?.cityName ?? '',
                        style: noteSans(11, color: noteQuiet))
                  ]),
                  Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: noteLine))),
                      child: Row(children: [
                        const DiscoveryIcon(DiscoveryMark.pin,
                            size: 14, color: preparationRed),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(p.place?.routeTitle ?? '',
                                style: noteSans(12))),
                        Text(
                            noteDistanceLabel(noteDistance(p.place,
                                ref.watch(notesLocationProvider).value)),
                            style: noteSans(11, color: noteQuiet)),
                      ])),
                  Padding(
                      padding: const EdgeInsets.only(top: 19),
                      child: Text(p.body, style: noteSerif(14, height: 2))),
                  if (p.media.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 19),
                        child: NoteGallery(p, initialIndex: widget.photoIndex)),
                  if (p.preparationItems.isNotEmpty) GuidePreparationPaper(p),
                ],
                Padding(
                    key: _commentsKey,
                    padding: const EdgeInsets.only(top: 22, bottom: 18),
                    child: Row(children: [
                      NoteButton(
                          label: '发表评论',
                          onTap: isGuide
                              ? () => _showGuideReply(key, controller)
                              : null,
                          child:
                              Text('评论', style: noteSerif(isGuide ? 20 : 23))),
                      const Spacer(),
                      Text(p.commentCount.toString().padLeft(2, '0'),
                          style: noteItalic(13))
                    ])),
                for (final comment in state.comments)
                  if (isGuide)
                    _guideComment(comment, state, controller, key)
                  else
                    _comment(comment, state, controller),
                if (state.comments.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text('还没有评论，来聊聊你的发现。',
                          style: noteSans(11, color: noteQuiet))),
                if (state.commentCursor != null)
                  NoteArrow('更多评论',
                      onTap: state.isMutating
                          ? null
                          : controller.loadMoreComments),
                if (!isGuide) _replyComposer(state, controller),
                if (!isGuide) const SizedBox(height: 24)
              ]);
        });
    if (isGuide) {
      final p = async.requireValue.post;
      return PreparationScaffold(
          title: '见闻',
          trailing: NoteButton(
              label: p.viewerHasSaved ? '取消收藏' : '收藏见闻',
              onTap: _saving ? null : () => _save(p, key),
              child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                      child: DiscoveryIcon(DiscoveryMark.bookmark,
                          size: 17,
                          color: noteInk,
                          filled: p.viewerHasSaved)))),
          footer: Row(children: [
            Expanded(
                child: Text(
                    '${p.place?.routeTitle ?? ''} · ${p.preparationItems.length} 项',
                    style: noteSans(11, color: noteQuiet))),
            const SizedBox(width: 12),
            GuideChecklist(p, showItems: false)
          ]),
          child: content);
    }
    return NoteScaffold(child: content);
  }

  Widget _replyComposer(
          CommunityDetailState state, CommunityDetailController controller) =>
      Column(children: [
        if (_replyTo != null)
          Row(children: [
            Expanded(
                child: Text('回复 ${_replyTo!.author.displayName}',
                    style: noteSans(11, color: noteQuiet))),
            IconButton(
                onPressed: () => setState(() => _replyTo = null),
                icon: const Icon(Icons.close, size: 16))
          ]),
        Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: noteLine))),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _reply,
                      style: noteSans(16),
                      maxLength: 300,
                      onChanged: (_) => _commentId = const Uuid().v4(),
                      decoration: InputDecoration(
                          hintText: '说说你的发现…',
                          hintStyle: noteSans(16, color: noteQuiet),
                          counterText: '',
                          filled: false,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: noteLine)),
                          enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: noteLine))))),
              const SizedBox(width: 12),
              NoteButton(
                  label: '发送',
                  onTap: state.isMutating
                      ? null
                      : () async {
                          if (_reply.text.trim().isEmpty) return;
                          final success = await controller.comment(
                              _reply.text.trim(), _commentId,
                              replyTo: _replyTo);
                          if (success && mounted) {
                            _reply.clear();
                            _commentId = const Uuid().v4();
                            setState(() => _replyTo = null);
                            ref.invalidate(notesFeedProvider);
                            ref.invalidate(savedNotesProvider);
                          }
                        },
                  child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                          child: Text('发送',
                              style: noteSerif(14, color: noteRed)))))
            ]))
      ]);

  Future<void> _showGuideReply(
      CommunityPostKey key, CommunityDetailController controller,
      {CommunityComment? reply}) async {
    setState(() => _replyTo = reply);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: notePaper,
        builder: (sheet) => SafeArea(
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    23, 20, 23, MediaQuery.viewInsetsOf(sheet).bottom + 23),
                child: Consumer(builder: (context, ref, _) {
                  final state =
                      ref.watch(communityDetailControllerProvider(key)).value;
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(child: Text('评论', style: noteSerif(23))),
                      IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close, size: 18))
                    ]),
                    if (state != null) _replyComposer(state, controller),
                  ]);
                }))));
  }

  Widget _guideComment(CommunityComment c, CommunityDetailState state,
      CommunityDetailController controller, CommunityPostKey key) {
    final replies = state.repliesByRoot[c.id] ?? c.replyPreview;
    return Padding(
        padding: const EdgeInsets.only(bottom: 19),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NoteButton(
              label: '回复${c.author.displayName}',
              onTap: c.isTombstone
                  ? null
                  : () => _showGuideReply(key, controller, reply: c),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 25,
                          height: 25,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: Color(0xffdddcc9), shape: BoxShape.circle),
                          child: Text(
                              c.author.displayName.characters.lastOrNull ?? '旅',
                              style: noteSerif(13, color: preparationGreen))),
                      const SizedBox(width: 8),
                      Text(c.isTombstone ? '评论已删除' : c.author.displayName,
                          style: noteSans(11, color: noteQuiet)),
                      const SizedBox(width: 8),
                      Text(noteTime(c.createdAt).replaceAll(' · ', ' '),
                          style: noteSans(11, color: noteQuiet))
                    ]),
                    if (!c.isTombstone)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(c.body, style: noteSans(12))),
                  ])),
          for (final reply in replies)
            Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: NoteButton(
                    label: '回复${reply.author.displayName}',
                    onTap: reply.isTombstone
                        ? null
                        : () => _showGuideReply(key, controller, reply: reply),
                    child: Text('${reply.author.displayName}：${reply.body}',
                        style: noteSans(11, color: noteQuiet)))),
          if (c.replyCount > replies.length)
            NoteArrow('查看回复',
                size: 12,
                underline: false,
                onTap: () => controller.loadReplies(c,
                    more: state.repliesByRoot.containsKey(c.id))),
        ]));
  }

  Widget _comment(CommunityComment c, CommunityDetailState state,
      CommunityDetailController controller) {
    final replies = state.repliesByRoot[c.id] ?? c.replyPreview;
    return Padding(
        padding: const EdgeInsets.only(bottom: 19),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NoteAvatar(c.isTombstone ? '旅' : c.author.displayName, sand: true),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                NoteButton(
                    label: '回复${c.author.displayName}',
                    onTap: c.isTombstone
                        ? null
                        : () => setState(() => _replyTo = c),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.isTombstone ? '评论已删除' : c.author.displayName,
                              style: noteSans(12)),
                          const SizedBox(height: 4),
                          if (!c.isTombstone)
                            Text(c.body,
                                style: noteSans(12,
                                    color: const Color(0xff525748),
                                    height: 1.9))
                        ])),
                for (final reply in replies)
                  Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 10),
                      color: const Color(0xffe9e8dc),
                      child: NoteButton(
                          label: '回复${reply.author.displayName}',
                          onTap: () => setState(() => _replyTo = reply),
                          child: Text(
                              '${reply.author.displayName}：${reply.body}',
                              style: noteSans(11, height: 1.8)))),
                if (c.replyCount > replies.length)
                  NoteArrow('查看回复',
                      size: 12,
                      underline: false,
                      onTap: () => controller.loadReplies(c,
                          more: state.repliesByRoot.containsKey(c.id)))
              ]))
        ]));
  }
}
