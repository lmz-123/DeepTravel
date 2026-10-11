import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
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
                Text('票据仅保存在本机，按账号分别管理',
                    style: manualType(11, color: AppColors.textMuted)),
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
  bool busy = false;
  Future<void> importReceipt() async {
    if (busy) return;
    setState(() => busy = true);
    final user = ref.read(currentUserIdProvider);
    try {
      final store = await ref.read(travelStoreProvider.future);
      if (store == null) return;
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (!mounted ||
          ref.read(currentUserIdProvider) != user ||
          result == null) {
        return;
      }
      final file = result;
      if (file.path == null) throw const FormatException('无法读取所选文件');
      await store.importReceipt(widget.id, file.name, File(file.path!));
      if (!mounted || ref.read(currentUserIdProvider) != user) return;
      refreshTravel(ref, widget.id);
      travelNotice(context, '已添加票据');
    } on FormatException catch (e) {
      if (mounted) travelNotice(context, e.message);
    } catch (_) {
      if (mounted) travelNotice(context, '票据未能保存，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
                content: const Text('本机保存的相关票据和准备清单也会删除。'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
            title: Text('我的出游', style: manualType(13)),
            leading: IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => popOrGo(context, '/travel'))),
        body: ref.watch(travelPlanProvider(widget.id)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => refreshTravel(ref, widget.id),
                    child: const Text('重新加载出游'))),
            data: (plan) {
              if (plan == null) {
                return Center(
                    child: Text('这次出游已移除或属于其他账号',
                        style: manualType(13, color: AppColors.textMuted)));
              }
              final route = ref.watch(offlineAwareRouteProvider(plan.slug));
              final prep = route.asData?.value.travelPreparation;
              final receipts = ref.watch(travelReceiptsProvider(plan.id));
              return RefreshIndicator(
                  onRefresh: () async {
                    refreshTravel(ref, plan.id);
                    ref.invalidate(offlineAwareRouteProvider(plan.slug));
                    await ref.read(travelPlanProvider(plan.id).future);
                  },
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(23, 10, 23, 25),
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(plan.city,
                                  style: manualType(11,
                                      color: AppColors.textMuted))),
                          TextButton(
                              onPressed: () => date(plan),
                              child: Text('出行日期',
                                  style:
                                      manualType(12, color: AppColors.action)))
                        ]),
                        Text('我的出游',
                            style: manualType(32,
                                serif: true, weight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        Text(
                            plan.date == null
                                ? '日期待定'
                                : plan.date!.substring(5).replaceAll('-', '.'),
                            style: TextStyle(
                                fontFamily: plan.date == null
                                    ? 'Noto Serif SC'
                                    : 'Georgia',
                                fontStyle: plan.date == null
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                                fontSize: plan.date == null ? 23 : 48,
                                color: AppColors.ink)),
                        if (plan.date != null)
                          Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                  onPressed: () async {
                                    try {
                                      await (await ref
                                              .read(travelStoreProvider.future))
                                          ?.setDate(plan.id, null);
                                      if (mounted) refreshTravel(ref, plan.id);
                                    } catch (_) {
                                      if (context.mounted) {
                                        travelNotice(context, '日期未能保存');
                                      }
                                    }
                                  },
                                  child: const Text('暂不定日期'))),
                        const SizedBox(height: 23),
                        Text(plan.title,
                            style: manualType(22,
                                serif: true, weight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        if (prep != null && prep.canBook)
                          TravelTicketCard(
                              title: prep.admission == 'reservation'
                                  ? '预约参观'
                                  : '门票与预约',
                              subtitle: prep.channel,
                              action: prep.action,
                              onTap: () => openPreparationLink(
                                  context, prep.purchaseUrl,
                                  external: prep.external),
                              footnote: '在官方渠道完成'),
                        if (prep != null && prep.enabled) PreparationRows(prep),
                        if (route.isLoading)
                          const Padding(
                              padding: EdgeInsets.all(12),
                              child: LinearProgressIndicator()),
                        if (route.hasError)
                          TravelRow('准备信息暂不可用',
                              subtitle: '点此重试',
                              onTap: () => ref.invalidate(
                                  offlineAwareRouteProvider(plan.slug))),
                        MyPreparation(plan.id),
                        TravelHeading('我的票据',
                            trailing: TextButton(
                                onPressed: busy ? null : importReceipt,
                                child: Text(busy ? '正在保存…' : '＋ 添加',
                                    style: manualType(13,
                                        color: AppColors.action)))),
                        receipts.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => TextButton(
                                onPressed: () => ref.invalidate(
                                    travelReceiptsProvider(plan.id)),
                                child: const Text('重新加载票据')),
                            data: (items) => items.isEmpty
                                ? TravelTicketCard(
                                    title: '收好这次出游的票据',
                                    subtitle: '图片 / PDF · 仅保存在本机',
                                    action: '添加票据',
                                    onTap: importReceipt,
                                    footnote: '已在其他平台购买')
                                : Column(children: [
                                    for (final item in items)
                                      TravelRow(item.name,
                                          icon: item.kind == 'pdf'
                                              ? Icons.picture_as_pdf_outlined
                                              : Icons.image_outlined,
                                          subtitle: '本人添加',
                                          onTap: () => context.push(
                                              '/travel/${plan.id}/receipt/${item.id}'))
                                  ])),
                        const SizedBox(height: 12),
                        Text('自行添加的票据不代表平台已核验订单。',
                            style: manualType(11, color: AppColors.textMuted)),
                        const SizedBox(height: 20),
                        RouteCompanionEntry(
                            routeName: plan.title,
                            onTap: () => context.push(companionLocation(
                                plan.slug,
                                requestSelection: true))),
                        TravelRow('景点详情',
                            onTap: () => context.push('/route/${plan.slug}')),
                        TextButton(
                            onPressed: () => removePlan(plan),
                            child: Text('移除这次出游',
                                style: manualType(12,
                                    color: AppColors.textMuted))),
                      ]));
            }));
  }
}

class TravelReceiptPage extends ConsumerStatefulWidget {
  const TravelReceiptPage(
      {super.key, required this.planId, required this.receiptId});
  final String planId, receiptId;
  @override
  ConsumerState<TravelReceiptPage> createState() => _TravelReceiptPageState();
}

class _TravelReceiptPageState extends ConsumerState<TravelReceiptPage> {
  bool busy = false;
  Future<void> remove(TravelReceipt receipt) async {
    final user = ref.read(currentUserIdProvider);
    if (busy) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('删除这份票据？'),
                content: const Text('删除后需重新添加原文件。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('删除'))
                ]));
    if (yes != true || !mounted || user != ref.read(currentUserIdProvider)) {
      return;
    }
    setState(() => busy = true);
    try {
      await (await ref.read(travelStoreProvider.future))
          ?.removeReceipt(receipt);
      if (mounted) {
        refreshTravel(ref, widget.planId);
        popOrGo(context, '/travel/${widget.planId}');
      }
    } catch (_) {
      if (mounted) travelNotice(context, '删除失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(travelStoreProvider).asData?.value;
    return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: Text('我的票据', style: manualType(13))),
        body: ref.watch(travelReceiptsProvider(widget.planId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(travelReceiptsProvider(widget.planId)),
                    child: const Text('重新加载票据'))),
            data: (items) {
              final matches = items.where((r) => r.id == widget.receiptId);
              if (store == null || matches.isEmpty) {
                return const Center(child: Text('票据不存在'));
              }
              final receipt = matches.first, file = store.file(receipt);
              return ListView(padding: const EdgeInsets.all(23), children: [
                Text('本人添加', style: manualType(11, color: AppColors.action)),
                const SizedBox(height: 15),
                Text(receipt.name, style: manualType(24, serif: true)),
                const SizedBox(height: 20),
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: Color(0xffeeebdf),
                        border: Border(
                            top: BorderSide(color: AppColors.moss, width: 2)),
                        borderRadius:
                            BorderRadius.only(topRight: Radius.circular(28))),
                    child: receipt.kind == 'pdf'
                        ? Column(children: [
                            const Icon(Icons.picture_as_pdf_outlined,
                                size: 48, color: AppColors.moss),
                            const SizedBox(height: 20),
                            ManualPaperAction(
                                label: '打开 PDF 票据',
                                onPressed: () async {
                                  try {
                                    final result = await OpenFilex.open(
                                        file.path,
                                        type: 'application/pdf');
                                    if (result.type != ResultType.done &&
                                        context.mounted) {
                                      travelNotice(
                                          context, '未找到可用的 PDF 阅读器或文件已丢失');
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      travelNotice(context, '无法打开票据');
                                    }
                                  }
                                })
                          ])
                        : SizedBox(
                            height: 360,
                            child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 5,
                                child: Image.file(file,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Text('图片无法读取，请重新添加')))))),
                const SizedBox(height: 16),
                Text('请按官方要求出示原始票据。平台未核验此文件。',
                    style: manualType(12, color: AppColors.textMuted)),
                const SizedBox(height: 24),
                OutlinedButton(
                    onPressed: busy ? null : () => remove(receipt),
                    child: const Text('删除票据')),
              ]);
            }));
  }
}
