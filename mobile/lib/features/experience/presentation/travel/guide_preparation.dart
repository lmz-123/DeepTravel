import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/community_models.dart';
import '../../data/travel_plan_store.dart';
import '../experience_providers.dart';
import '../offline_package_controller.dart';
import '../community/notes_widgets.dart';
import '../community/notes_controller.dart';
import 'travel_providers.dart';
import 'preparation_visuals.dart';
import '../widgets/discovery_art.dart';

final routeGuidesProvider = FutureProvider.autoDispose
    .family<List<CommunityPost>, String>((ref, slug) async {
  ref.watch(currentUserIdProvider);
  return (await ref.watch(experienceRepositoryProvider).discoverCommunity(
          query: CommunityQuery(
              category: CommunityCategory.guide, routeSlug: slug)))
      .items;
});
final preparationTasksProvider =
    FutureProvider.family<List<Map<String, Object?>>, String>((ref, id) async =>
        await (await ref.watch(travelStoreProvider.future))?.tasks(id) ?? []);
final importedGuidesProvider =
    FutureProvider.family<List<Map<String, Object?>>, String>((ref, id) async =>
        await (await ref.watch(travelStoreProvider.future))?.guides(id) ?? []);

class GuideChecklist extends ConsumerStatefulWidget {
  const GuideChecklist(this.post, {super.key, this.showItems = true});
  final bool showItems;
  final CommunityPost post;
  @override
  ConsumerState<GuideChecklist> createState() => _GuideChecklistState();
}

class _GuideChecklistState extends ConsumerState<GuideChecklist> {
  bool busy = false;
  Future<void> import() async {
    if (busy) return;
    final user = ref.read(currentUserIdProvider);
    setState(() => busy = true);
    try {
      final slug = widget.post.place?.routeSlug;
      if (slug == null || slug.isEmpty) throw const FormatException('地点暂不可用');
      final route = await ref.read(offlineAwareRouteProvider(slug).future);
      final store = await ref.read(travelStoreProvider.future);
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      if (store == null) throw const FormatException('请先登录');
      await store.importGuide(route, widget.post);
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      refreshTravel(ref, route.id);
      ref.invalidate(preparationTasksProvider(route.id));
      ref.invalidate(importedGuidesProvider(route.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: noteInk,
          content: Text('${widget.post.preparationItems.length} 项准备已加入',
              style: noteSans(12, color: notePaper)),
          action: SnackBarAction(
              label: '查看',
              textColor: notePaper,
              onPressed: () {
                if (mounted && user == ref.read(currentUserIdProvider)) {
                  context.push('/travel/${route.id}');
                }
              })));
    } catch (_) {
      if (mounted && user == ref.read(currentUserIdProvider)) {
        noteNotice(context, '暂未加入，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.post.place?.routeSlug;
    final routeId = slug == null
        ? null
        : ref.watch(offlineAwareRouteProvider(slug)).asData?.value.id;
    final imported = routeId != null &&
        (ref.watch(importedGuidesProvider(routeId)).value ?? [])
            .any((g) => g['post_id'] == widget.post.id);
    final action = PreparationLink(
        busy
            ? '正在加入…'
            : imported
                ? '已加入 · 查看'
                : '加入我的准备',
        onTap: busy
            ? null
            : imported
                ? () => context.push('/travel/$routeId')
                : import,
        pencil: true,
        busy: busy,
        icon: imported ? DiscoveryMark.arrowRight : DiscoveryMark.arrowDown);
    if (!widget.showItems) return action;
    return GuidePreparationPaper(widget.post);
  }
}

class GuidePreparationPaper extends StatelessWidget {
  const GuidePreparationPaper(this.post, {super.key});
  final CommunityPost post;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(top: 23, bottom: 16),
      padding: const EdgeInsets.fromLTRB(17, 19, 17, 10),
      decoration: const BoxDecoration(
          color: preparationSheet,
          border: Border(top: BorderSide(color: preparationGreen, width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('出发前准备',
                  style: noteSerif(19, weight: FontWeight.w500, height: 1.6))),
          Text('${post.preparationItems.length} 项',
              style: noteSans(11, color: noteQuiet))
        ]),
        const SizedBox(height: 6),
        for (final (i, item) in post.preparationItems.indexed)
          Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                  border: i == post.preparationItems.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: Color(0xffd7d5c7)))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 18,
                    child: Text('${i + 1}',
                        style: noteItalic(17, color: const Color(0xff7d856e)))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.title,
                          style: noteSans(13)
                              .copyWith(fontWeight: FontWeight.w500)),
                      if (item.body.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(item.body,
                                style: noteSans(11,
                                    color: noteQuiet, height: 1.8))),
                    ])),
              ])),
      ]));
}

class GuideByline extends StatelessWidget {
  const GuideByline(this.post, {super.key});
  final CommunityPost post;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xffdddcc9), shape: BoxShape.circle),
            child: Text(post.author.displayName.characters.lastOrNull ?? '旅',
                style: noteSerif(13, color: Color(0xff636e50)))),
        const SizedBox(width: 8),
        Flexible(
            child: Text('${post.author.displayName} · 攻略',
                style: noteSans(11, color: noteQuiet))),
      ]);
}

class RouteGuideList extends ConsumerWidget {
  const RouteGuideList(this.slug, {super.key});
  final String slug;
  Future<void> write(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserIdProvider);
    try {
      final places = await ref.read(notesPlacesProvider.future);
      if (!context.mounted || user != ref.read(currentUserIdProvider)) return;
      final place = places.where((p) => p.routeSlug == slug).firstOrNull;
      if (place == null) {
        noteNotice(context, '地点暂不可用，请稍后重试');
        return;
      }
      context.push(
          '/community/write?category=guide&fragment=${Uri.encodeComponent(place.fragmentId)}');
    } catch (_) {
      if (context.mounted) noteNotice(context, '地点暂不可用，请重试');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 26, bottom: 15),
            child: Row(children: [
              Expanded(
                  child: Text('大家的攻略',
                      style: noteSerif(23, weight: FontWeight.w500))),
              PreparationLink('写一份',
                  icon: DiscoveryMark.pen, onTap: () => write(context, ref)),
            ])),
        ref.watch(routeGuidesProvider(slug)).when(
            loading: () => const LinearProgressIndicator(minHeight: 1),
            error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(routeGuidesProvider(slug)),
                child: const Text('重新加载攻略')),
            data: (posts) => posts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('还没有攻略，来分享你的准备吧',
                        style: noteSans(12, color: noteQuiet)))
                : Column(children: [
                    for (final (index, post) in posts.indexed)
                      if (index == 0)
                        Container(
                            decoration: const BoxDecoration(
                                border:
                                    Border(top: BorderSide(color: noteLine))),
                            padding: const EdgeInsets.only(top: 19, bottom: 13),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GuideByline(post),
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: 12, bottom: 8),
                                      child: NoteButton(
                                          label: '查看攻略',
                                          onTap: () => context.push(
                                              '/community/post/${post.id}'),
                                          child: Text(
                                              preparationTitle(
                                                  post.title ?? '攻略'),
                                              style: noteSerif(
                                                      MediaQuery.sizeOf(context)
                                                                  .width <
                                                              350
                                                          ? 20
                                                          : 22,
                                                      weight: FontWeight.w500,
                                                      height: 1.6)
                                                  .copyWith(
                                                      letterSpacing: -.35)))),
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: 6, bottom: 16),
                                      child: Text(post.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: noteSans(12,
                                              color: noteQuiet, height: 1.9))),
                                  SizedBox(
                                      width: double.infinity,
                                      child: Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 12,
                                          children: [
                                            Text(
                                                '${post.preparationItems.length} 项准备${post.createdAt == null ? '' : ' · ${post.createdAt!.month.toString().padLeft(2, '0')} 月 ${post.createdAt!.day.toString().padLeft(2, '0')} 日'}',
                                                style: noteSans(11,
                                                    color: noteQuiet)),
                                            GuideChecklist(post,
                                                showItems: false),
                                          ])),
                                ]))
                      else
                        Container(
                            margin: const EdgeInsets.only(top: 13),
                            padding: const EdgeInsets.only(top: 18),
                            decoration: const BoxDecoration(
                                border:
                                    Border(top: BorderSide(color: noteLine))),
                            child: NoteButton(
                                label: '查看攻略',
                                onTap: () =>
                                    context.push('/community/post/${post.id}'),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(post.title ?? '攻略',
                                            style: noteSerif(17,
                                                weight: FontWeight.w500)),
                                        const SizedBox(height: 6),
                                        Text(
                                            '${post.author.displayName} · ${post.preparationItems.length} 项准备',
                                            style:
                                                noteSans(11, color: noteQuiet)),
                                      ])),
                                  const SizedBox(width: 15),
                                  const DiscoveryIcon(
                                      DiscoveryMark.arrowUpRight,
                                      size: 17,
                                      color: noteInk)
                                ]))),
                  ])),
      ]);
}

class MyPreparation extends ConsumerStatefulWidget {
  const MyPreparation(this.routeId, {super.key, this.onBrowse});
  final VoidCallback? onBrowse;
  final String routeId;
  @override
  ConsumerState<MyPreparation> createState() => _MyPreparationState();
}

class _MyPreparationState extends ConsumerState<MyPreparation> {
  bool busy = false;
  Future<void> change(
      Future<void> Function(TravelPlanStore store) action) async {
    if (busy) return;
    final user = ref.read(currentUserIdProvider);
    setState(() => busy = true);
    try {
      final store = await ref.read(travelStoreProvider.future);
      if (!mounted ||
          user != ref.read(currentUserIdProvider) ||
          store == null) {
        return;
      }
      await action(store);
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      ref.invalidate(preparationTasksProvider(widget.routeId));
    } catch (_) {
      if (mounted) noteNotice(context, '准备未能保存，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  final _custom = TextEditingController();
  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final title = _custom.text.trim();
    if (title.isEmpty || busy) return;
    await change((store) async {
      await store.addTask(widget.routeId, title);
      if (mounted) _custom.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(preparationTasksProvider(widget.routeId));
    final guides = ref.watch(importedGuidesProvider(widget.routeId));
    final rows = tasks.value ?? <Map<String, Object?>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 15),
          child: Row(children: [
            Expanded(
                child: Text('出发前准备',
                    style: noteSerif(23, weight: FontWeight.w500))),
            Text(
                '${rows.where((r) => r['done'] == 1).length} / ${rows.length} 已备好',
                style: noteSans(11, color: noteQuiet)),
          ])),
      if (tasks.isLoading || guides.isLoading)
        const LinearProgressIndicator(minHeight: 1),
      if (tasks.hasError || guides.hasError)
        TextButton(
            onPressed: () {
              ref.invalidate(preparationTasksProvider(widget.routeId));
              ref.invalidate(importedGuidesProvider(widget.routeId));
            },
            child: const Text('重新加载准备')),
      if (tasks.hasValue && guides.hasValue && rows.isEmpty)
        Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 10),
            width: double.infinity,
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: noteLine))),
            child: Column(children: [
              Text('还没有准备清单', style: noteSans(13, color: noteQuiet)),
              PreparationLink('看看大家怎么准备',
                  pencil: true,
                  icon: DiscoveryMark.arrowRight,
                  onTap: widget.onBrowse)
            ])),
      for (final guide in guides.value ?? <Map<String, Object?>>[]) ...[
        Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: noteLine))),
            child: Row(children: [
              Expanded(
                  child: Text('来自${guide['author']}的攻略',
                      style: noteSans(11, color: noteQuiet))),
              NoteButton(
                  label: '查看原文',
                  onTap: () =>
                      context.push('/community/post/${guide['post_id']}'),
                  child: SizedBox(
                      height: 44,
                      child: Center(
                          child: Text('查看原文 ↗',
                              style: noteSans(11, color: noteQuiet).copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationColor: noteQuiet))))),
            ])),
        for (final row in rows.where((r) => r['post_id'] == guide['post_id']))
          _task(row),
      ],
      for (final row in rows.where((r) => r['post_id'] == null)) _task(row),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(children: [
            Expanded(
                child: TextField(
                    key: const ValueKey('preparation-custom-input'),
                    controller: _custom,
                    enabled: !busy,
                    maxLength: 60,
                    onSubmitted: (_) => add(),
                    style: noteSans(16, height: 1.7),
                    decoration: InputDecoration(
                        hintText: '补充一项自己的准备',
                        hintStyle: noteSans(16, color: noteQuiet),
                        counterText: '',
                        filled: false,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: noteLine)),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: noteLine)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: preparationGreen))))),
            const SizedBox(width: 10),
            IconButton(
                key: const ValueKey('preparation-custom-add'),
                tooltip: '添加准备事项',
                onPressed: busy ? null : add,
                icon: const DiscoveryIcon(DiscoveryMark.plus,
                    size: 17, color: preparationRed)),
          ])),
    ]);
  }

  Widget _task(Map<String, Object?> row) {
    final checked = row['done'] == 1;
    return Semantics(
        checked: checked,
        label: row['title'] as String,
        child: GestureDetector(
            onLongPress: row['post_id'] != null || busy
                ? null
                : () async {
                    final user = ref.read(currentUserIdProvider);
                    final remove = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                                backgroundColor: notePaper,
                                title: Text('移除这项准备？', style: noteSerif(22)),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('保留')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('移除'))
                                ]));
                    if (remove == true &&
                        mounted &&
                        user == ref.read(currentUserIdProvider)) {
                      await change((s) => s.removeTask(row['id'] as String));
                    }
                  },
            child: NoteButton(
                key: ValueKey('preparation-task-${row['id']}'),
                label: row['title'] as String,
                onTap: busy
                    ? null
                    : () => change(
                        (s) => s.checkTask(row['id'] as String, !checked)),
                child: Container(
                    constraints: const BoxConstraints(minHeight: 62),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: noteLine))),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 19,
                              height: 19,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                  color: checked
                                      ? const Color(0xff6b785d)
                                      : Colors.transparent,
                                  border: Border.all(
                                      color: checked
                                          ? const Color(0xff6b785d)
                                          : const Color(0xff979d89)),
                                  borderRadius: BorderRadius.circular(2)),
                              child: checked
                                  ? const DiscoveryIcon(DiscoveryMark.check,
                                      size: 14, color: notePaper)
                                  : null),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(row['title'] as String,
                                    style: noteSerif(15,
                                            color:
                                                checked ? noteQuiet : noteInk)
                                        .copyWith(
                                            decoration: checked
                                                ? TextDecoration.lineThrough
                                                : null)),
                                if ((row['body'] as String).isNotEmpty ||
                                    row['post_id'] == null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                          row['post_id'] == null
                                              ? '自己补充'
                                              : row['body'] as String,
                                          style:
                                              noteSans(11, color: noteQuiet))),
                              ])),
                        ])))));
  }
}
