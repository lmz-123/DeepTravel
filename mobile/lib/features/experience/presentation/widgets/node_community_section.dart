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
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (_) => _CommunityComposer(
        policy: policy,
        evidence:
            evidence.where((item) => item.fragmentId == fragment.id).toList(),
        onPublish: (draft) => ref
            .read(communityFeedControllerProvider(key).notifier)
            .publish(draft),
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
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                children: _photos.indexed
                    .map((entry) => Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(entry.$2.path),
                                width: 84, height: 84, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            child: IconButton.filled(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              tooltip: '移除第 ${entry.$1 + 1} 张图片',
                              onPressed: () =>
                                  setState(() => _photos.removeAt(entry.$1)),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ]))
                    .toList(),
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
          ]),
        ),
      );

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
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _CommunityError(
        onRetry: () => ref.invalidate(communityDetailControllerProvider(key)),
      ),
      data: (state) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(children: [
            Expanded(
              child: Text(state.post.category.label,
                  style: const TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w700)),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              onSelected: (value) => _action(value, state, key),
              itemBuilder: (_) => [
                if (state.post.viewerIsAuthor)
                  const PopupMenuItem(value: 'delete', child: Text('删除动态'))
                else
                  const PopupMenuItem(value: 'report', child: Text('举报动态')),
              ],
            ),
          ]),
          if (state.post.title != null) ...[
            const SizedBox(height: 8),
            Text(state.post.title!,
                style: Theme.of(context).textTheme.headlineMedium),
          ],
          const SizedBox(height: 8),
          Text('${state.post.author.displayName} · 旅行者内容'),
          if (state.post.media.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...state.post.media.map((media) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog.fullscreen(
                        backgroundColor: Colors.black,
                        child: Stack(children: [
                          Center(
                            child: InteractiveViewer(
                              minScale: .8,
                              maxScale: 5,
                              child: _CommunityImage(
                                  userId: widget.userId, media: media),
                            ),
                          ),
                          SafeArea(
                            child: IconButton.filled(
                              tooltip: '关闭图片',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _CommunityImage(
                            userId: widget.userId, media: media),
                      ),
                    ),
                  ),
                )),
          ],
          if (state.post.body.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(state.post.body, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 18),
          Row(children: [
            FilledButton.tonalIcon(
              onPressed: state.isMutating
                  ? null
                  : () => ref
                      .read(communityDetailControllerProvider(key).notifier)
                      .toggleLike(),
              icon: Icon(state.post.viewerHasLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded),
              label: Text('${state.post.likeCount} 个赞'),
            ),
            const SizedBox(width: 12),
            Text('${state.post.commentCount} 条评论'),
          ]),
          if (state.likers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('赞过：${state.likers.map((item) => item.displayName).join('、')}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (state.likerCursor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: state.isMutating
                    ? null
                    : () => ref
                        .read(communityDetailControllerProvider(key).notifier)
                        .loadMoreLikers(),
                child: const Text('查看更多点赞者'),
              ),
            ),
          const Divider(height: 32),
          Text('现场回应', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...state.comments.map((comment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded)),
                title: Text(comment.author.displayName),
                subtitle: Text(comment.body),
                trailing: PopupMenuButton<String>(
                  tooltip: '评论操作',
                  onSelected: (action) async {
                    if (action == 'delete') {
                      await ref
                          .read(communityDetailControllerProvider(key).notifier)
                          .deleteComment(comment);
                    } else {
                      final confirmed = await _confirm(
                        '举报这条评论？',
                        '举报后它会从你的视野隐藏，并进入审核。',
                      );
                      if (confirmed == true) {
                        await ref
                            .read(experienceRepositoryProvider)
                            .reportCommunityComment(comment.id, 'other');
                        ref.invalidate(communityDetailControllerProvider(key));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (comment.viewerIsAuthor)
                      const PopupMenuItem(value: 'delete', child: Text('删除评论'))
                    else
                      const PopupMenuItem(value: 'report', child: Text('举报评论')),
                  ],
                ),
              )),
          if (state.commentCursor != null)
            TextButton(
              onPressed: state.isMutating
                  ? null
                  : () => ref
                      .read(communityDetailControllerProvider(key).notifier)
                      .loadMoreComments(),
              child: const Text('加载更多评论'),
            ),
          TextField(
            controller: _comment,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: '友善地补充一句…',
              suffixIcon: IconButton(
                tooltip: '发表评论',
                onPressed: state.isMutating ? null : () => _submitComment(key),
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
          if (state.message != null)
            Text(state.message!,
                style: const TextStyle(color: AppColors.terracotta)),
        ],
      ),
    );
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
