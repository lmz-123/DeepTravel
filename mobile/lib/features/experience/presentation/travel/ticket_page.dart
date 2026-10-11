import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/travel_preparation.dart';
import '../community/notes_widgets.dart';
import 'preparation_visuals.dart';
import 'travel_widgets.dart';

class TicketPage extends StatefulWidget {
  const TicketPage({super.key, required this.route, required this.ticket});
  final RouteExperience route;
  final TicketOption ticket;
  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  bool _opening = false;
  Future<void> _buy() async {
    if (_opening) return;
    setState(() => _opening = true);
    final prep = widget.route.travelPreparation;
    final url =
        safePreparationUri(widget.ticket.text('purchase_url'))?.toString() ??
            prep.purchaseUrl;
    try {
      await openPreparationLink(context, url, external: prep.external);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return PreparationScaffold(
        title: '全部票种',
        onBack: () => Navigator.pop(context),
        footer: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: const Color(0xff354638),
                    foregroundColor: notePaper,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2))),
                onPressed: _opening ? null : _buy,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_opening) ...[
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 1, color: notePaper)),
                    const SizedBox(width: 10)
                  ],
                  Text(_opening ? '正在打开' : '前往购买',
                      style: noteSerif(16, color: notePaper)),
                  const SizedBox(width: 13),
                  const Icon(Icons.north_east, size: 18)
                ]))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.route.title, style: noteSans(12, color: noteQuiet)),
          Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(t.title, style: noteSerif(34))),
          if (t.text('subtitle').isNotEmpty)
            Text(t.text('subtitle'), style: noteSans(12, color: noteQuiet)),
          Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0xffe6e5d3),
                  border: Border(
                      top: BorderSide(color: Color(0xffc6c9b7)),
                      bottom: BorderSide(color: Color(0xffc6c9b7)))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.price.isEmpty ? '票务信息' : '参考票价',
                        style: noteSans(11, color: noteQuiet)),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(t.price.isEmpty ? '查看当日票价' : '¥${t.price}',
                            style: t.price.isEmpty
                                ? noteSerif(25)
                                : noteItalic(43, color: noteInk))),
                    const Divider(color: Color(0xffbabfa8)),
                    Text('日期、余票与支付在购票渠道确认',
                        style: noteSans(11, color: noteQuiet))
                  ])),
          for (final entry in {
            'description': '票种说明',
            'audience': '适用人群',
            'entry_time': '入园时间',
            'refund_policy': '退改规则'
          }.entries)
            if (t.text(entry.key).isNotEmpty)
              Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: noteLine))),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 82,
                            child: Text(entry.value,
                                style: noteSans(12, color: noteQuiet))),
                        Expanded(
                            child: Text(t.text(entry.key),
                                style: noteSans(12, height: 1.8)))
                      ])),
          TravelRow('票务来源与更新',
              subtitle: widget.route.travelPreparation.channel,
              onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: notePaper,
                  builder: (c) => SafeArea(
                      child: Padding(
                          padding: const EdgeInsets.all(23),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('票务信息', style: noteSerif(23)),
                                const SizedBox(height: 18),
                                Text('实际票价与余票以购票页面为准。',
                                    style: noteSans(13, height: 1.8)),
                                if (t.text('checked_at').isNotEmpty)
                                  Text(t.text('checked_at'),
                                      style: noteSans(11, color: noteQuiet)),
                                PreparationLink('查看来源',
                                    onTap: () => openPreparationLink(
                                        c,
                                        t.text('source_url').isEmpty
                                            ? widget.route.travelPreparation
                                                .text('source_url')
                                            : t.text('source_url')))
                              ]))))),
        ]));
  }
}
