import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/route_back.dart';
import '../../../../core/router/travel_destinations.dart';
import '../../domain/models.dart';
import '../offline_package_controller.dart';
import '../experience_providers.dart';
import '../route_manual/manual_visuals.dart';
import '../route_manual/route_companion_entry.dart';
import 'travel_providers.dart';
import 'travel_widgets.dart';
import 'guide_preparation.dart';

class PreparationPage extends ConsumerWidget {
  const PreparationPage({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(offlineAwareRouteProvider(slug));
    return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
            title: Text('游玩准备', style: manualType(13)),
            leading: IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => popOrGo(context, '/route/$slug'))),
        body: route.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(offlineAwareRouteProvider(slug)),
                    child: const Text('重新加载景点'))),
            data: (r) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(offlineAwareRouteProvider(slug));
                  ref.invalidate(routeGuidesProvider(slug));
                  await ref.read(offlineAwareRouteProvider(slug).future);
                },
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(23, 10, 23, 24),
                    child: PreparationBody(route: r)))));
  }
}

class PreparationBody extends ConsumerStatefulWidget {
  const PreparationBody({super.key, required this.route});
  final RouteExperience route;
  @override
  ConsumerState<PreparationBody> createState() => _PreparationBodyState();
}

class _PreparationBodyState extends ConsumerState<PreparationBody> {
  bool _busy = false;
  bool _opened = false;
  Future<void> _save({bool navigate = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final user = ref.read(currentUserIdProvider);
    try {
      final store = await ref.read(travelStoreProvider.future);
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      if (store == null) {
        travelNotice(context, '账号尚未就绪，请稍后重试');
        return;
      }
      await store.add(widget.route);
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      refreshTravel(ref, widget.route.id);
      if (navigate) context.push('/travel/${widget.route.id}');
    } catch (_) {
      if (mounted) travelNotice(context, '出游未能保存，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _book() async {
    if (_busy) return;
    final p = widget.route.travelPreparation;
    // Saving a plan records intent, never a ticket purchase.
    await _save(navigate: false);
    if (!mounted) return;
    final opened =
        await openPreparationLink(context, p.purchaseUrl, external: p.external);
    if (mounted && opened) setState(() => _opened = true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route, p = r.travelPreparation;
    final saved = ref.watch(travelPlanProvider(r.id)).asData?.value != null;
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next && mounted) setState(() => _opened = false);
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                [r.cityName, r.district].where((s) => s.isNotEmpty).join(' · '),
                style: manualType(11, color: AppColors.textMuted))),
        Text(r.mapCategory == 'park' ? '公园' : r.theme,
            style: manualType(11, color: AppColors.textMuted))
      ]),
      const SizedBox(height: 13),
      Text(r.title,
          style: manualType(32,
              serif: true, weight: FontWeight.w500, height: 1.4, spacing: -.8)),
      const SizedBox(height: 10),
      Text(r.subtitle, style: manualType(12, color: AppColors.textMuted)),
      const SizedBox(height: 19),
      ClipRRect(
          borderRadius: const BorderRadius.only(topRight: Radius.circular(45)),
          child: SizedBox(
              height: 136,
              width: double.infinity,
              child: r.heroImage.isNotEmpty
                  ? Image.network(r.heroImage,
                      fit: BoxFit.cover,
                      color: Colors.white,
                      colorBlendMode: BlendMode.modulate,
                      errorBuilder: (_, __, ___) => _cover(r))
                  : _cover(r))),
      const TravelHeading('游玩准备'),
      if (p.enabled) ...[
        if (p.canBook)
          TravelTicketCard(
              title: p.admission == 'reservation' ? '预约参观' : '门票与预约',
              subtitle: p.channel,
              action: _opened ? '继续办理' : p.action,
              onTap: _book,
              footnote: '在官方渠道完成'),
        if (p.admission == 'free')
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('无需门票', style: manualType(14, serif: true))),
        PreparationRows(p),
        if (p.text('source_url').isNotEmpty)
          TravelRow('信息来源',
              subtitle: p.text('verified_on').isEmpty
                  ? '查看来源'
                  : '${p.text('verified_on')} 核实',
              onTap: () => openPreparationLink(context, p.text('source_url'))),
        if (!p.canBook && p.items.isEmpty && p.admission != 'free')
          Text('准备信息待补充', style: manualType(13, color: AppColors.textMuted)),
      ] else
        Text('准备信息待补充', style: manualType(13, color: AppColors.textMuted)),
      RouteGuideList(r.slug),
      if (_opened)
        TravelRow('添加已购票据', subtitle: '图片 / PDF', onTap: () => _save()),
      const SizedBox(height: 22),
      const Divider(height: 1),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _busy ? null : () => _save(),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(49),
                    side: const BorderSide(color: Color(0xffd7d2c5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4))),
                child: Text(
                    _busy
                        ? '正在保存…'
                        : saved
                            ? '查看我的出游'
                            : '＋ 加入出游',
                    style: manualType(13)))),
        const SizedBox(width: 20),
        RouteCompanionLink(
            onTap: () =>
                context.push(companionLocation(r.slug, requestSelection: true)))
      ]),
    ]);
  }

  Widget _cover(RouteExperience r) => ColoredBox(
      color: const Color(0xffdce0c9),
      child: Center(
          child: Text(r.title.characters.firstOrNull ?? '',
              style: manualType(70,
                  serif: true, color: const Color(0xff687355)))));
}

/// Existing scenic cover and companion layout remain intact; new logistics entry.
class RoutePreparationEntry extends StatelessWidget {
  const RoutePreparationEntry({super.key, required this.route});
  final RouteExperience route;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: TravelRow('游玩准备',
          subtitle: route.travelPreparation.canBook ? '门票、预约与交通' : '开放、交通与须知',
          onTap: () => context.push('/route/${route.slug}/prepare')));
}
