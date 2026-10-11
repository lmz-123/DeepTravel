import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/route_back.dart';
import '../../../../core/router/travel_destinations.dart';
import '../../data/travel_plan_store.dart';
import '../experience_providers.dart';
import '../offline_package_controller.dart';
import '../route_manual/manual_visuals.dart';
import '../route_manual/route_companion_entry.dart';
import 'travel_providers.dart';
import 'travel_widgets.dart';
import 'guide_preparation.dart';
import 'preparation_visuals.dart';
import '../community/notes_widgets.dart';
import '../widgets/discovery_art.dart';

class TravelPlansPage extends ConsumerWidget {
  const TravelPlansPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
          leading: IconButton(
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => popOrGo(context, '/profile'))),
      body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(travelPlansProvider);
            await ref.read(travelPlansProvider.future);
          },
          child: ListView(
              padding: const EdgeInsets.all(23),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text('我的出游',
                    style:
                        manualType(32, serif: true, weight: FontWeight.w500)),
                const SizedBox(height: 9),
                const SizedBox(height: 25),
                ref.watch(travelPlansProvider).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => TextButton(
                        onPressed: () => ref.invalidate(travelPlansProvider),
                        child: const Text('重新加载出游')),
                    data: (plans) => plans.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 45),
                            child: Column(children: [
                              const Icon(Icons.luggage_outlined,
                                  size: 35, color: AppColors.moss),
                              const SizedBox(height: 20),
                              Text('还没有安排出游',
                                  style: manualType(20, serif: true)),
                              const SizedBox(height: 10),
                              Text('在景点的游玩准备中，加入想去的地方。',
                                  style: manualType(12,
                                      color: AppColors.textMuted)),
                              TextButton(
                                  onPressed: () => context.go('/'),
                                  child: const Text('去发现'))
                            ]))
                        : Column(children: [
                            for (final plan in plans)
                              TravelRow(plan.title,
                                  subtitle: plan.date ?? '日期待定',
                                  onTap: () =>
                                      context.push('/travel/${plan.id}'))
                          ])),
              ])));
}

class TravelPlanPage extends ConsumerStatefulWidget {
  const TravelPlanPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TravelPlanPage> createState() => _TravelPlanPageState();
}

class _TravelPlanPageState extends ConsumerState<TravelPlanPage> {
  Future<void> date(TravelPlan plan) async {
    final user = ref.read(currentUserIdProvider);
    final now = DateTime.now(), existing = DateTime.tryParse(plan.date ?? '');
    final selected = await showDatePicker(
        context: context,
        initialDate: existing ?? now,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 5),
        helpText: '选择出行日期',
        cancelText: '取消',
        confirmText: '保存');
    if (selected == null ||
        !mounted ||
        user != ref.read(currentUserIdProvider)) {
      return;
    }
    try {
      await (await ref.read(travelStoreProvider.future))
          ?.setDate(plan.id, selected);
      if (mounted) refreshTravel(ref, plan.id);
    } catch (_) {
      if (mounted) travelNotice(context, '日期未能保存');
    }
  }

  Future<void> removePlan(TravelPlan plan) async {
    final user = ref.read(currentUserIdProvider);
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('移除这次出游？'),
                content: const Text('本机保存的准备清单也会删除。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('移除'))
                ]));
    if (yes != true || !mounted || user != ref.read(currentUserIdProvider)) {
      return;
    }
    try {
      await (await ref.read(travelStoreProvider.future))?.removePlan(plan.id);
      if (mounted) {
        refreshTravel(ref, plan.id);
        context.go('/travel');
      }
    } catch (_) {
      if (mounted) travelNotice(context, '未能移除，请重试');
    }
  }

  Future<void> tripOptions(TravelPlan plan) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: notePaper,
      builder: (sheet) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(23),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TravelRow('修改出行日期', onTap: () {
                  Navigator.pop(sheet);
                  date(plan);
                }),
                TravelRow('暂不定日期', onTap: () async {
                  final user = ref.read(currentUserIdProvider);
                  Navigator.pop(sheet);
                  try {
                    final store = await ref.read(travelStoreProvider.future);
                    if (!mounted || user != ref.read(currentUserIdProvider)) {
                      return;
                    }
                    await store?.setDate(plan.id, null);
                    if (mounted) refreshTravel(ref, plan.id);
                  } catch (_) {
                    if (mounted) travelNotice(context, '日期未能保存');
                  }
                }),
                TravelRow('移除这次出游', onTap: () {
                  Navigator.pop(sheet);
                  removePlan(plan);
                }),
              ]))));

  @override
  Widget build(BuildContext context) =>
      ref.watch(travelPlanProvider(widget.id)).when(
          loading: () => const PreparationScaffold(
              title: '我的准备',
              child: Center(child: CircularProgressIndicator(strokeWidth: 1))),
          error: (_, __) => PreparationScaffold(
              title: '我的准备',
              child: Center(
                  child: TextButton(
                      onPressed: () => refreshTravel(ref, widget.id),
                      child: const Text('重新加载出游')))),
          data: (plan) {
            if (plan == null) {
              return PreparationScaffold(
                  title: '我的准备',
                  child: Center(
                      child: Text('这次出游已移除或属于其他账号',
                          style: noteSans(13, color: noteQuiet))));
            }
            final route = ref.watch(offlineAwareRouteProvider(plan.slug));
            final prep = route.asData?.value.travelPreparation;
            final visit = DateTime.tryParse(plan.date ?? '');
            final region = [plan.city, route.asData?.value.district ?? '']
                .where((s) => s.isNotEmpty)
                .join(' · ');
            return PreparationScaffold(
                title: '我的准备',
                onBack: () => popOrGo(context, '/travel'),
                trailing: PreparationLink('写攻略',
                    icon: DiscoveryMark.pen,
                    onTap: () => RouteGuideList(plan.slug).write(context, ref)),
                onRefresh: () async {
                  refreshTravel(ref, plan.id);
                  ref.invalidate(preparationTasksProvider(plan.id));
                  ref.invalidate(importedGuidesProvider(plan.id));
                  ref.invalidate(offlineAwareRouteProvider(plan.slug));
                  await ref.read(travelPlanProvider(plan.id).future);
                },
                footer: Row(children: [
                  Expanded(
                      child: PreparationOutline('游玩准备',
                          onTap: () =>
                              context.push('/route/${plan.slug}/prepare'))),
                  const SizedBox(width: 18),
                  RouteCompanionLink(
                      onTap: () => context.push(
                          companionLocation(plan.slug, requestSelection: true)))
                ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(region,
                                style: noteSans(11, color: noteQuiet))),
                        NoteButton(
                            label: '管理我的出游',
                            onTap: () => tripOptions(plan),
                            child: Text('我的出游',
                                style: noteSans(11, color: noteQuiet)))
                      ]),
                      Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 24),
                          child: NoteButton(
                              label: '选择出行日期',
                              onTap: () => date(plan),
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                        visit == null
                                            ? '日期待定'
                                            : '${visit.month.toString().padLeft(2, '0')}.${visit.day.toString().padLeft(2, '0')}',
                                        style: visit == null
                                            ? noteSerif(25)
                                            : noteItalic(36, color: noteInk)
                                                .copyWith(height: 1.2)),
                                    const SizedBox(width: 12),
                                    Text(
                                        visit == null
                                            ? '选择日期'
                                            : [
                                                '星期一',
                                                '星期二',
                                                '星期三',
                                                '星期四',
                                                '星期五',
                                                '星期六',
                                                '星期日'
                                              ][visit.weekday - 1],
                                        style: noteSans(11, color: noteQuiet)),
                                  ]))),
                      Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(plan.title,
                              style: noteSerif(20,
                                  height: 1.6, weight: FontWeight.w500))),
                      if (prep?.canBook == true)
                        TravelTicketCard(
                            title: prep!.admission == 'reservation'
                                ? '预约参观'
                                : '门票与预约',
                            subtitle: prep.channel,
                            action: '查看票种',
                            footnote: '按游玩日期查看',
                            onTap: () =>
                                context.push('/route/${plan.slug}/prepare')),
                      if (prep?.enabled == true && prep?.admission == 'free')
                        Text('无需门票', style: noteSerif(18)),
                      if (route.isLoading)
                        const LinearProgressIndicator(minHeight: 1),
                      if (route.hasError)
                        TravelRow('准备信息暂不可用',
                            subtitle: '点此重试',
                            onTap: () => ref.invalidate(
                                offlineAwareRouteProvider(plan.slug))),
                      MyPreparation(plan.id,
                          onBrowse: () =>
                              context.push('/route/${plan.slug}/prepare')),
                      PreparationFacts(
                          left: '开放与交通',
                          right: '入园须知',
                          onLeft: () {
                            if (prep != null) {
                              showPreparationFacts(context, prep);
                            }
                          },
                          onRight: () {
                            if (prep != null) {
                              showPreparationFacts(context, prep,
                                  notices: true);
                            } else {
                              travelNotice(context, '景点信息暂不可用，请稍后重试');
                            }
                          }),
                    ]));
          });
}
