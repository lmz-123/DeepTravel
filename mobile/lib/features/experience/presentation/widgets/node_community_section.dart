import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/community_models.dart';
import '../../domain/fragment_models.dart';
import '../experience_providers.dart';

class NodeCommunitySection extends ConsumerWidget {
  const NodeCommunitySection({
    required this.userId,
    required this.journeyId,
    required this.fragment,
    this.evidence = const [],
    super.key,
  });

  final String userId;
  final String journeyId;
  final StoryFragment fragment;
  final List<EvidenceRecord> evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!fragment.isRevealed) return const SizedBox.shrink();
    final key = CommunityFeedKey(userId, journeyId, fragment.id);
    final value = ref.watch(communityFeedControllerProvider(key));
    return Column(
      key: ValueKey('node-community-${fragment.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 46),
        Row(children: [
          const Icon(Icons.local_fire_department_outlined,
              color: AppColors.terracotta),
          const SizedBox(width: 9),
          Expanded(
            child:
                Text('见地现场', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Text('这条线索下', style: Theme.of(context).textTheme.labelMedium),
        ]),
        const SizedBox(height: 7),
        const Text('分享机位、行走经验与现场补充。事实补充均为旅行者内容，请自行判断。'),
        const SizedBox(height: 16),
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _CommunityError(
            onRetry: () => ref.invalidate(communityFeedControllerProvider(key)),
          ),
          data: (state) {
            if (!state.policy.enabled) {
              return const _CommunityNotice(message: '见地现场正在准备中，稍后再来看看。');
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ComposerEntry(
                    onTap: () => _showComposer(context, ref, key, state.policy),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _CategoryChip(
                        label: '全部',
                        selected: state.category == null,
                        onTap: () => ref
                            .read(communityFeedControllerProvider(key).notifier)
                            .selectCategory(null),
                      ),
                      ...state.policy.categories
                          .map((category) => _CategoryChip(
                                label: category.label,
                                selected: state.category == category,
                                onTap: () => ref
                                    .read(communityFeedControllerProvider(key)
                                        .notifier)
                                    .selectCategory(category),
                              )),
                    ]),
                  ),
                  if (state.mutationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(state.mutationMessage!,
                          style: const TextStyle(color: AppColors.terracotta)),
                    ),
                  const SizedBox(height: 12),
                  if (state.items.isEmpty)
                    const _CommunityNotice(message: '还没有旅行者留下现场笔记。你可以成为第一个。')
                  else
                    ...state.items.map((post) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PostCard(
                            userId: userId,
                            post: post,
                            onOpen: () =>
                                _showDetail(context, ref, key, post.id),
                            onLike: () => ref
                                .read(communityFeedControllerProvider(key)
                                    .notifier)
                                .toggleLike(post),
                          ),
                        )),
                  if (state.hasMore)
                    Center(
                      child: TextButton(
                        onPressed: state.isLoadingMore
                            ? null
                            : () => ref
                                .read(communityFeedControllerProvider(key)
                                    .notifier)
                                .loadMore(),
                        child: Text(state.isLoadingMore ? '正在加载…' : '查看更多现场笔记'),
                      ),
                    ),
                ]);
          },
        ),
      ],
    );
  }

  Future<void> _showComposer(
    BuildContext context,
    WidgetRef ref,
    CommunityFeedKey key,
    CommunityPolicy policy,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (_) => FractionallySizedBox(
        heightFactor: .96,
        child: _CommunityComposer(
          policy: policy,
          evidence:
              evidence.where((item) => item.fragmentId == fragment.id).toList(),
          onPublish: (draft) => ref
              .read(communityFeedControllerProvider(key).notifier)
              .publish(draft),
        ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    CommunityFeedKey feedKey,
    String postId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (_) => FractionallySizedBox(
        heightFactor: .96,
        child: _PostDetail(userId: userId, postId: postId),
      ),
    );
    ref.invalidate(communityFeedControllerProvider(feedKey));
  }
}

class _ComposerEntry extends StatelessWidget {
  const _ComposerEntry({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.white,
                child: Icon(Icons.person_outline_rounded),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('在这条线索下，留下你的发现…')),
              Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.terracotta),
            ]),
          ),
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
            label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.userId,
    required this.post,
    required this.onOpen,
    required this.onLike,
  });
  final String userId;
  final CommunityPostSummary post;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label:
            '${post.category.label}，${post.title ?? post.body}，${post.likeCount} 个赞，${post.commentCount} 条评论',
        child: Material(
          color: post.media.isEmpty ? const Color(0xffeee6d8) : AppColors.white,
          elevation: post.media.isEmpty ? 0 : 1,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (post.media.isNotEmpty)
                AspectRatio(
                  aspectRatio: 1.08,
                  child:
                      _CommunityImage(userId: userId, media: post.media.first),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(post.category.label,
                            style: const TextStyle(
                                color: AppColors.terracotta,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(post.author.displayName,
                            style: Theme.of(context).textTheme.labelMedium),
                      ]),
                      if (post.title != null) ...[
                        const SizedBox(height: 8),
                        Text(post.title!,
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                      if (post.body.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(post.body,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        InkWell(
                          onTap: onLike,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 5),
                            child: Row(children: [
                              Icon(
                                post.viewerHasLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: post.viewerHasLiked
                                    ? AppColors.terracotta
                                    : AppColors.ink,
                              ),
                              const SizedBox(width: 5),
                              Text('${post.likeCount}'),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                        const SizedBox(width: 5),
                        Text('${post.commentCount}'),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
      );
}

class _CommunityImage extends ConsumerWidget {
  const _CommunityImage({required this.userId, required this.media});
  final String userId;
  final CommunityMedia media;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref
        .watch(communityMediaBytesProvider(CommunityMediaKey(userId, media)));
    return bytes.when(
      loading: () => const ColoredBox(
        color: AppColors.paperDeep,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const ColoredBox(
        color: AppColors.paperDeep,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
      data: (value) =>
          Image.memory(value, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

class _CommunityComposer extends StatefulWidget {
  const _CommunityComposer({
    required this.policy,
    required this.evidence,
    required this.onPublish,
  });
  final CommunityPolicy policy;
  final List<EvidenceRecord> evidence;
  final Future<bool> Function(CommunityPostDraft) onPublish;

  @override
  State<_CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<_CommunityComposer> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();
  final _photos = <XFile>[];
  final _evidenceIds = <String>{};
  CommunityCategory _category = CommunityCategory.onSite;
  bool _publishing = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          leading: IconButton(
            key: const ValueKey('community-composer-close'),
            tooltip: '关闭发布',
            onPressed: _requestClose,
            icon: const Icon(Icons.close_rounded),
          ),
          title: const Text('发布现场笔记'),
          centerTitle: true,
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          children: [
            Text('留下现场笔记', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('只发布你愿意公开的内容；私人足迹照片会生成一份独立副本。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: widget.policy.categories
                  .map((item) => ChoiceChip(
                        label: Text(item.label),
                        selected: _category == item,
                        onSelected: (_) => setState(() => _category = item),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: widget.policy.titleMaxLength,
              decoration: const InputDecoration(labelText: '短标题（可选）'),
            ),
            TextField(
              controller: _body,
              maxLength: widget.policy.bodyMaxLength,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: '分享机位、经验或补充'),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _photos.indexed.map((entry) {
                  final index = entry.$1;
                  return SizedBox.square(
                    dimension: 92,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(entry.$2.path),
                              fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filled(
                            key: ValueKey('remove-community-photo-$index'),
                            visualDensity: VisualDensity.compact,
                            iconSize: 17,
                            tooltip: '移除第 ${index + 1} 张图片',
                            onPressed: () =>
                                setState(() => _photos.removeAt(index)),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 10, children: [
              OutlinedButton.icon(
                onPressed: _photos.length + _evidenceIds.length >=
                        widget.policy.maxMedia
                    ? null
                    : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('拍摄'),
              ),
              OutlinedButton.icon(
                onPressed: _photos.length + _evidenceIds.length >=
                        widget.policy.maxMedia
                    ? null
                    : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('相册'),
              ),
            ]),
            if (widget.evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('从这条足迹选择留念', style: Theme.of(context).textTheme.titleSmall),
              ...widget.evidence.map((item) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _evidenceIds.contains(item.id),
                    title: Text(
                        _evidenceIds.contains(item.id) ? '已选择公开副本' : '私人足迹照片'),
                    subtitle: const Text('原照片仍保持私密，删除动态不会删除原照片'),
                    onChanged: (selected) => setState(() {
                      if (selected == true &&
                          _photos.length + _evidenceIds.length <
                              widget.policy.maxMedia) {
                        _evidenceIds.add(item.id);
                      } else {
                        _evidenceIds.remove(item.id);
                      }
                    }),
                  )),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.terracotta)),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _publishing ? null : _publish,
                icon: _publishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(_publishing ? '正在发布…' : '发布到见地现场'),
              ),
            ),
          ],
        ),
      );

  Future<void> _requestClose() async {
    final hasDraft = _title.text.trim().isNotEmpty ||
        _body.text.trim().isNotEmpty ||
        _photos.isNotEmpty ||
        _evidenceIds.isNotEmpty;
    if (!hasDraft) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃这条现场笔记？'),
        content: const Text('已经选择的照片和填写的内容不会保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 92);
    if (picked == null || !mounted) return;
    setState(() => _photos.add(picked));
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty &&
        _body.text.trim().isEmpty &&
        _photos.isEmpty &&
        _evidenceIds.isEmpty) {
      setState(() => _error = '请至少写一点内容或选择一张图片');
      return;
    }
    if (_evidenceIds.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('分享到见地现场？'),
          content: const Text('将为所选私人照片创建可被其他旅行者查看的独立副本。原照片仍保持私密。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认分享')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    final success = await widget.onPublish(CommunityPostDraft(
      category: _category,
      idempotencyKey: const Uuid().v4(),
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      body: _body.text.trim().isEmpty ? null : _body.text.trim(),
      photoPaths: _photos.map((item) => item.path).toList(),
      evidenceIds: _evidenceIds.toList(),
    ));
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _publishing = false;
        _error = '发布没有完成，你的内容仍在这里，可以重试';
      });
    }
  }
}

class _PostDetail extends ConsumerStatefulWidget {
  const _PostDetail({required this.userId, required this.postId});
  final String userId;
  final String postId;
  @override
  ConsumerState<_PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends ConsumerState<_PostDetail> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = CommunityPostKey(widget.userId, widget.postId);
    final value = ref.watch(communityDetailControllerProvider(key));
    final detail = value.asData?.value;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          key: const ValueKey('community-detail-close'),
          tooltip: '关闭动态详情',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('现场笔记'),
        centerTitle: true,
        actions: [
          if (detail != null)
            PopupMenuButton<String>(
              tooltip: '更多操作',
              onSelected: (action) => _action(action, detail, key),
              itemBuilder: (_) => [
                if (detail.post.viewerIsAuthor)
                  const PopupMenuItem(value: 'delete', child: Text('删除动态'))
                else
                  const PopupMenuItem(value: 'report', child: Text('举报动态')),
              ],
            ),
        ],
      ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _CommunityError(
              onRetry: () =>
                  ref.invalidate(communityDetailControllerProvider(key)),
            ),
          ),
        ),
        data: (state) => _detailBody(state, key),
      ),
    );
  }

  Widget _detailBody(CommunityDetailState state, CommunityPostKey key) =>
      Column(
        children: [
          Expanded(
            child: CustomScrollView(
              key: const ValueKey('community-detail-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  sliver: SliverList.list(children: [
                    _PostAuthorHeader(post: state.post),
                    if (state.post.title != null) ...[
                      const SizedBox(height: 16),
                      Text(state.post.title!,
                          style: Theme.of(context).textTheme.headlineMedium),
                    ],
                    if (state.post.body.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(state.post.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.65)),
                    ],
                    if (state.post.media.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _DetailMediaGallery(
                        userId: widget.userId,
                        media: state.post.media,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PostInteractionBar(
                      post: state.post,
                      isMutating: state.isMutating,
                      onLike: () => ref
                          .read(communityDetailControllerProvider(key).notifier)
                          .toggleLike(),
                    ),
                    if (state.likers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _LikerSummary(
                        likers: state.likers,
                        hasMore: state.likerCursor != null,
                        onLoadMore: state.isMutating
                            ? null
                            : () => ref
                                .read(communityDetailControllerProvider(key)
                                    .notifier)
                                .loadMoreLikers(),
                      ),
                    ],
                    const Divider(height: 38),
                    Row(children: [
                      Text('现场回应',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 8),
                      Text('${state.post.commentCount}',
                          style: Theme.of(context).textTheme.labelMedium),
                    ]),
                    const SizedBox(height: 6),
                    if (state.comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: Text('还没有回应，留下第一句友善的补充。')),
                      )
                    else
                      ...state.comments.map((comment) => _CommentTile(
                            comment: comment,
                            onDelete: () => ref
                                .read(communityDetailControllerProvider(key)
                                    .notifier)
                                .deleteComment(comment),
                            onReport: () => _reportComment(comment, key),
                          )),
                    if (state.commentCursor != null)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: state.isMutating
                              ? null
                              : () => ref
                                  .read(communityDetailControllerProvider(key)
                                      .notifier)
                                  .loadMoreComments(),
                          child: const Text('加载更多回应'),
                        ),
                      ),
                    if (state.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(state.message!,
                            style:
                                const TextStyle(color: AppColors.terracotta)),
                      ),
                  ]),
                ),
              ],
            ),
          ),
          _CommentComposer(
            controller: _comment,
            enabled: !state.isMutating,
            onSend: () => _submitComment(key),
          ),
        ],
      );

  Future<void> _reportComment(
      CommunityComment comment, CommunityPostKey key) async {
    final confirmed = await _confirm(
      '举报这条评论？',
      '举报后它会从你的视野隐藏，并进入审核。',
    );
    if (confirmed != true) return;
    await ref
        .read(experienceRepositoryProvider)
        .reportCommunityComment(comment.id, 'other');
    ref.invalidate(communityDetailControllerProvider(key));
  }

  Future<void> _submitComment(CommunityPostKey key) async {
    final body = _comment.text.trim();
    if (body.isEmpty) return;
    final success = await ref
        .read(communityDetailControllerProvider(key).notifier)
        .comment(body, const Uuid().v4());
    if (success) _comment.clear();
  }

  Future<void> _action(
    String action,
    CommunityDetailState state,
    CommunityPostKey key,
  ) async {
    final repository = ref.read(experienceRepositoryProvider);
    if (action == 'delete') {
      final confirmed = await _confirm('删除这条动态？', '图片、文字和互动入口将不再显示。');
      if (confirmed != true) return;
      await repository.deleteCommunityPost(state.post.id);
      if (mounted) Navigator.pop(context);
    } else {
      final confirmed = await _confirm('举报这条动态？', '举报后它会立即从你的视野隐藏，并进入审核。');
      if (confirmed != true) return;
      await repository.reportCommunityPost(state.post.id, 'other');
      if (mounted) Navigator.pop(context);
    }
    ref.invalidate(communityDetailControllerProvider(key));
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认')),
          ],
        ),
      );
}

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const _CommunityAvatar(radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.author.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${_formatCommunityTime(post.createdAt)} · 旅行者内容',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.terracotta.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(post.category.label,
                style: const TextStyle(
                    color: AppColors.terracotta,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ],
      );
}

class _DetailMediaGallery extends StatefulWidget {
  const _DetailMediaGallery({required this.userId, required this.media});

  final String userId;
  final List<CommunityMedia> media;

  @override
  State<_DetailMediaGallery> createState() => _DetailMediaGalleryState();
}

class _DetailMediaGalleryState extends State<_DetailMediaGallery> {
  var _page = 0;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: widget.media.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => _openImage(widget.media[index]),
                      child: _CommunityImage(
                          userId: widget.userId, media: widget.media[index]),
                    ),
                  ),
                  if (widget.media.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .58),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text('${_page + 1}/${widget.media.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.media.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.media.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? AppColors.terracotta
                        : AppColors.paperDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      );

  Future<void> _openImage(CommunityMedia media) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Center(
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 5,
                child: _CommunityImage(userId: widget.userId, media: media),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  tooltip: '关闭图片',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _PostInteractionBar extends StatelessWidget {
  const _PostInteractionBar({
    required this.post,
    required this.isMutating,
    required this.onLike,
  });

  final CommunityPost post;
  final bool isMutating;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.paperDeep.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          TextButton.icon(
            onPressed: isMutating ? null : onLike,
            icon: Icon(
              post.viewerHasLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: post.viewerHasLiked ? AppColors.terracotta : AppColors.ink,
            ),
            label: Text('${post.likeCount} 个赞'),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chat_bubble_outline_rounded, size: 19),
          const SizedBox(width: 6),
          Text('${post.commentCount} 条回应'),
        ]),
      );
}

class _LikerSummary extends StatelessWidget {
  const _LikerSummary({
    required this.likers,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<CommunityAuthor> likers;
  final bool hasMore;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.people_alt_outlined,
                size: 18, color: AppColors.moss),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${likers.map((item) => item.displayName).join('、')} 赞过',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (hasMore)
            TextButton(onPressed: onLoadMore, child: const Text('更多')),
        ],
      );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onDelete,
    required this.onReport,
  });

  final CommunityComment comment;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CommunityAvatar(radius: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(comment.author.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(_formatCommunityTime(comment.createdAt),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 6),
                  Text(comment.body,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.5)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '评论操作',
              iconSize: 20,
              onSelected: (action) =>
                  action == 'delete' ? onDelete() : onReport(),
              itemBuilder: (_) => [
                if (comment.viewerIsAuthor)
                  const PopupMenuItem(value: 'delete', child: Text('删除评论'))
                else
                  const PopupMenuItem(value: 'report', child: Text('举报评论')),
              ],
            ),
          ],
        ),
      );
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.paper,
        elevation: 12,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              const _CommunityAvatar(radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: '友善地回应这条现场笔记…',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.paperDeep,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '发表评论',
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ]),
          ),
        ),
      );
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.moss.withValues(alpha: .14),
        foregroundColor: AppColors.moss,
        child: const Icon(Icons.person_outline_rounded),
      );
}

String _formatCommunityTime(DateTime? value) {
  if (value == null) return '刚刚';
  final local = value.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
  if (difference.inDays < 1) return '${difference.inHours} 小时前';
  if (difference.inDays < 7) return '${difference.inDays} 天前';
  return '${local.month}月${local.day}日';
}

class _CommunityNotice extends StatelessWidget {
  const _CommunityNotice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(message),
      );
}

class _CommunityError extends StatelessWidget {
  const _CommunityError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          const Expanded(child: Text('现场笔记暂时没有加载出来。')),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ]),
      );
}
