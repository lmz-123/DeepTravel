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
      context.push('/travel/${route.id}');
      noteNotice(context, '已加入我的准备');
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
    final action = NoteArrow(
        busy
            ? '正在加入…'
            : imported
                ? '查看我的准备'
                : '加入我的准备',
        onTap: busy
            ? null
            : imported
                ? () => context.push('/travel/$routeId')
                : import);
    if (!widget.showItems) return action;
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 23),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
            color: Color(0xffeee9dd),
            border: Border(
                top: BorderSide(color: noteLine),
                bottom: BorderSide(color: noteLine))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('出发前准备', style: noteSerif(22)),
          const SizedBox(height: 12),
          for (final (index, item) in widget.post.preparationItems.indexed)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${index + 1}'.padLeft(2, '0'),
                          style: noteItalic(14)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.title, style: noteSerif(16)),
                            if (item.body.isNotEmpty)
                              Text(item.body,
                                  style: noteSans(12, color: noteQuiet)),
                          ])),
                    ])),
          const SizedBox(height: 12),
          action,
        ]));
  }
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
  Widget build(BuildContext context, WidgetRef ref) => Padding(
      padding: const EdgeInsets.only(top: 25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('大家的攻略', style: noteSerif(23))),
          NoteArrow('写一份',
              size: 13, underline: false, onTap: () => write(context, ref))
        ]),
        const Divider(color: noteLine),
        ref.watch(routeGuidesProvider(slug)).when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
            error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(routeGuidesProvider(slug)),
                child: const Text('重新加载攻略')),
            data: (posts) => posts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text('还没有攻略，来分享你的准备吧',
                        style: noteSans(12, color: noteQuiet)))
                : Column(children: [
                    for (final (index, post) in posts.indexed)
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NoteButton(
                                label: '查看攻略',
                                onTap: () =>
                                    context.push('/community/post/${post.id}'),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${post.author.displayName} · 攻略',
                                              style: noteSans(11,
                                                  color: noteQuiet)),
                                          const SizedBox(height: 10),
                                          Text(post.title ?? '攻略',
                                              style: noteSerif(
                                                  index == 0 ? 23 : 18)),
                                          if (index == 0) ...[
                                            const SizedBox(height: 10),
                                            Text(post.body,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: noteSans(12,
                                                    color: noteQuiet)),
                                          ],
                                        ]))),
                            if (index == 0)
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        '${post.preparationItems.length} 项准备',
                                        style: noteSans(11, color: noteQuiet))),
                                GuideChecklist(post, showItems: false)
                              ]),
                            const Divider(height: 30, color: noteLine),
                          ]),
                  ])),
      ]));
}

class MyPreparation extends ConsumerStatefulWidget {
  const MyPreparation(this.routeId, {super.key});
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

  Future<void> add() async {
    final user = ref.read(currentUserIdProvider);
    var entered = '';
    final title = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                backgroundColor: notePaper,
                title: Text('添一项准备', style: noteSerif(22)),
                content: TextFormField(
                    onChanged: (value) => entered = value,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(hintText: '需要准备什么')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () {
                        if (entered.trim().isNotEmpty) {
                          Navigator.pop(c, entered.trim());
                        }
                      },
                      child: const Text('添加'))
                ]));
    if (title != null && mounted && user == ref.read(currentUserIdProvider)) {
      await change((store) => store.addTask(widget.routeId, title));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(preparationTasksProvider(widget.routeId));
    final guides = ref.watch(importedGuidesProvider(widget.routeId));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('我的准备', style: noteSerif(23)),
          tasks.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => TextButton(
                  onPressed: () =>
                      ref.invalidate(preparationTasksProvider(widget.routeId)),
                  child: const Text('重新加载准备')),
              data: (rows) => Column(children: [
                    if (rows.isNotEmpty)
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                  '已备好 ${rows.where((r) => r['done'] == 1).length} / ${rows.length}',
                                  style: noteSans(11, color: noteQuiet)))),
                    for (final row in rows)
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                                value: row['done'] == 1,
                                activeColor: noteInk,
                                onChanged: busy
                                    ? null
                                    : (v) => change((s) => s.checkTask(
                                        row['id'] as String, v ?? false))),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(row['title'] as String,
                                              style: noteSerif(16).copyWith(
                                                  decoration: row['done'] == 1
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null)),
                                          if ((row['body'] as String)
                                              .isNotEmpty)
                                            Text(row['body'] as String,
                                                style: noteSans(12,
                                                    color: noteQuiet)),
                                        ]))),
                            if (row['post_id'] == null)
                              IconButton(
                                  tooltip: '移除准备项',
                                  onPressed: busy
                                      ? null
                                      : () => change((s) =>
                                          s.removeTask(row['id'] as String)),
                                  icon: const Icon(Icons.close, size: 16)),
                          ]),
                  ])),
          for (final guide in guides.value ?? <Map<String, Object?>>[])
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  Expanded(
                      child: Text('来自 ${guide['author']}',
                          style: noteSans(11, color: noteQuiet))),
                  NoteArrow('查看原文',
                      size: 12,
                      underline: false,
                      onTap: () =>
                          context.push('/community/post/${guide['post_id']}')),
                ])),
          NoteArrow('添一项准备', size: 14, onTap: busy ? null : add),
        ]));
  }
}
