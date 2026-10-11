import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_back.dart';
import '../../../../core/router/travel_destinations.dart';
import '../../domain/models.dart';
import '../offline_package_controller.dart';
import '../experience_providers.dart';
import '../route_manual/route_companion_entry.dart';
import 'travel_providers.dart';
import 'travel_widgets.dart';
import 'guide_preparation.dart';
import 'preparation_visuals.dart';
import '../community/notes_widgets.dart';
import '../widgets/favorite_button.dart';
import '../widgets/discovery_art.dart';

class PreparationPage extends ConsumerWidget {
  const PreparationPage({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(offlineAwareRouteProvider(slug));
    return route.when(
        loading: () => const PreparationScaffold(
            title: '游玩准备',
            child: Center(child: CircularProgressIndicator(strokeWidth: 1))),
        error: (_, __) => PreparationScaffold(
            title: '游玩准备',
            child: Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(offlineAwareRouteProvider(slug)),
                    child: const Text('重新加载景点')))),
        data: (r) => PreparationBody(route: r));
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
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next && mounted) setState(() => _opened = false);
    });
    return PreparationScaffold(
        title: '游玩准备',
        onBack: () => popOrGo(context, '/route/${r.slug}'),
        trailing: FavoriteButton(
            kind: 'route',
            targetId: r.id,
            color: noteInk,
            mark: DiscoveryMark.bookmark),
        onRefresh: () async {
          ref.invalidate(offlineAwareRouteProvider(r.slug));
          ref.invalidate(routeGuidesProvider(r.slug));
          await ref.read(offlineAwareRouteProvider(r.slug).future);
        },
        footer: Row(children: [
          Expanded(
              child: PreparationOutline(_busy ? '正在保存…' : '我的准备',
                  onTap: _busy ? null : () => _save())),
          const SizedBox(width: 18),
          RouteCompanionLink(
              onTap: () => context
                  .push(companionLocation(r.slug, requestSelection: true))),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    [r.cityName, r.district]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: noteSans(11, color: noteQuiet))),
            Text(r.mapCategory == 'park' ? '公园' : r.theme,
                style: noteSans(11, color: noteQuiet))
          ]),
          Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 21),
              child: Text(r.title,
                  style: noteSerif(
                          MediaQuery.sizeOf(context).width < 350 ? 27 : 30,
                          weight: FontWeight.w500)
                      .copyWith(letterSpacing: -.7))),
          if (p.canBook)
            TravelTicketCard(
                title: p.admission == 'reservation' ? '预约参观' : '门票与预约',
                subtitle: p.channel,
                action: _opened ? '继续办理' : p.action,
                onTap: _book,
                footnote: '按游玩日期查看'),
          if (p.enabled && p.admission == 'free')
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('无需门票', style: noteSerif(18))),
          PreparationFacts(
              left: '开放与交通',
              right: '入园须知',
              onLeft: () => showPreparationFacts(context, p),
              onRight: () => showPreparationFacts(context, p, notices: true)),
          RouteGuideList(r.slug),
          if (_opened)
            TravelRow('添加已购票据', subtitle: '图片 / PDF', onTap: () => _save()),
        ]));
  }
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
