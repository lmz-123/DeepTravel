import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_back.dart';
import '../../domain/models.dart';
import '../offline_package_controller.dart';
import '../experience_providers.dart';
import 'travel_providers.dart';
import 'travel_widgets.dart';
import 'ticket_page.dart';
import '../city_atlas.dart';
import '../../domain/travel_preparation.dart';
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

  Future<void> _book(TicketOption ticket) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TicketPage(route: widget.route, ticket: ticket)));
    if (mounted) setState(() => _opened = true);
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
                borderRadius:
                    const BorderRadius.only(topRight: Radius.circular(20)),
                child: SizedBox(
                    width: 72,
                    height: 86,
                    child: ScenicThumbnail(url: r.heroImage, label: r.title))),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      [r.cityName, r.district]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: noteSans(11, color: noteQuiet)),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(r.title,
                          style: noteSerif(30, weight: FontWeight.w500))),
                  Text(cityAtlasCategory(r),
                      style: noteSans(11, color: noteQuiet))
                ]))
          ]),
          Padding(
              padding: const EdgeInsets.only(top: 38, bottom: 18),
              child: Row(children: [
                Expanded(
                    child: Text(
                        p.admission == 'ticket'
                            ? '选一张门票'
                            : p.admission == 'reservation'
                                ? '参观预约'
                                : '游玩信息',
                        style: noteSerif(23))),
                Text(p.admission == 'ticket' ? 'ADMISSION' : 'BEFORE YOU GO',
                    style: noteItalic(12, color: noteQuiet))
              ])),
          if (p.canBook) ...[
            for (final ticket in p.tickets.isEmpty
                ? [
                    TicketOption({
                      'description': p.text('notices'),
                      'title': p.admission == 'reservation' ? '参观预约' : '景区门票'
                    })
                  ]
                : p.tickets)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TravelTicketCard(
                      title: ticket.title,
                      subtitle: ticket.text('subtitle').isEmpty
                          ? p.channel
                          : ticket.text('subtitle'),
                      price: ticket.price,
                      action: '查看票种',
                      onTap: () => _book(ticket),
                      footnote: _opened ? '继续查看' : '日期、余票以购票渠道为准')),
          ],
          if (p.enabled && p.admission == 'free')
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('无需门票', style: noteSerif(18))),
          if (p.tickets.any((t) => t.price.isNotEmpty))
            Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Text('参考价格可能随日期调整，实际票价与规则请在购买时确认。',
                    style: noteSans(11, color: noteQuiet, height: 1.8))),
          _PreparationRow('开放与入园须知',
              subtitle: '交通、开放时间与参观规则',
              onTap: () => showPreparationFacts(context, p, all: true)),
          RouteGuideList(r.slug),
          _PreparationRow(_busy ? '正在保存…' : '我的准备',
              onTap: _busy ? null : () => _save()),
        ]));
  }
}

/// Existing scenic cover and companion layout remain intact; new logistics entry.
class RoutePreparationEntry extends StatelessWidget {
  const RoutePreparationEntry({super.key, required this.route});
  final RouteExperience route;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      child: ClipPath(
          clipper: const _PreparationFold(),
          child: Material(
              color: const Color(0xffebe8dc),
              child: InkWell(
                  onTap: () => context.push('/route/${route.slug}/prepare'),
                  child: Stack(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 54, 25),
                        child: SizedBox(
                            width: double.infinity,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('游玩准备',
                                      style: noteSerif(26,
                                              weight: FontWeight.w500,
                                              height: 1.4)
                                          .copyWith(letterSpacing: 1)),
                                  const SizedBox(height: 9),
                                  Text(
                                      route.travelPreparation.canBook
                                          ? '门票 · 入园须知 · 交通'
                                          : '开放时间 · 交通 · 攻略',
                                      style: noteSans(11, color: noteQuiet))
                                ]))),
                    const Positioned(
                        right: 23,
                        top: 43,
                        child: DiscoveryIcon(DiscoveryMark.arrowUpRight,
                            size: 24, color: preparationRed)),
                    Positioned(
                        right: 0,
                        top: 0,
                        child: CustomPaint(
                            size: const Size(24, 24), painter: _FoldPainter())),
                    const Positioned(
                        left: 22,
                        right: 22,
                        bottom: 14,
                        child: Divider(
                            height: 1,
                            color: Color(0xffc8c7b6),
                            thickness: .5)),
                  ])))));
}

class _PreparationFold extends CustomClipper<Path> {
  const _PreparationFold();
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width - 24, 0)
    ..lineTo(s.width, 24)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_PreparationFold oldClipper) => false;
}

class _FoldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) => canvas.drawPath(
      Path()
        ..lineTo(0, 24)
        ..lineTo(24, 24)
        ..close(),
      Paint()..color = const Color(0xffd5d5c1));
  @override
  bool shouldRepaint(_FoldPainter oldDelegate) => false;
}

class _PreparationRow extends StatelessWidget {
  const _PreparationRow(this.title, {this.subtitle, this.onTap});
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: noteLine))),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: noteSerif(19)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: noteSans(11, color: noteQuiet))
                  ]
                ])),
            const DiscoveryIcon(DiscoveryMark.arrowUpRight,
                size: 17, color: preparationRed)
          ])));
}
