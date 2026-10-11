import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/travel_preparation.dart';
import '../route_manual/manual_visuals.dart';
import '../community/notes_widgets.dart';
import 'preparation_visuals.dart';

void travelNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<bool> openPreparationLink(BuildContext context, String value,
    {bool external = false}) async {
  final uri = safePreparationUri(value);
  if (uri == null) {
    travelNotice(context, '入口暂不可用');
    return false;
  }
  bool opened = false;
  if (!external) {
    try {
      opened = await launchUrl(uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true));
    } catch (_) {/* Some devices have no custom-tab browser. */}
  }
  if (!opened) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) travelNotice(context, '暂时无法打开，请稍后重试或检查浏览器');
  return opened;
}

class TravelRow extends StatelessWidget {
  const TravelRow(this.title,
      {super.key, this.subtitle, this.onTap, this.icon});
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xffd7d2c5)))),
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 10)
                ],
                Expanded(child: Text(title, style: manualType(13))),
                if (subtitle != null)
                  Flexible(
                      child: Text(subtitle!,
                          textAlign: TextAlign.right,
                          style: manualType(11, color: AppColors.textMuted))),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textMuted)
                ],
              ]))));
}

class TravelTicketCard extends StatelessWidget {
  const TravelTicketCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.action,
      required this.onTap,
      this.footnote = '日期、票种与入园要求'});
  final String title, subtitle, action, footnote;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ClipPath(
      clipper: const _TicketClip(),
      child: Container(
          decoration: const BoxDecoration(
              color: Color(0xffebe8db),
              border: Border(
                  top: BorderSide(color: Color(0xffc7cbb8)),
                  bottom: BorderSide(color: Color(0xffc7cbb8)))),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 7),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: noteSerif(18, weight: FontWeight.w500, height: 1.6)),
            Text(subtitle, style: noteSans(11, color: noteQuiet)),
            const SizedBox(height: 16),
            const SizedBox(
                height: 1,
                width: double.infinity,
                child: CustomPaint(painter: _TicketRule())),
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(children: [
                  Expanded(
                      child: Text(footnote,
                          style: noteSans(11, color: noteQuiet))),
                  const SizedBox(width: 8),
                  PreparationLink(action, onTap: onTap),
                ])),
          ])));
}

/// Both compact fact entries retain all CMS-configured fields in a sheet.
Future<void> showPreparationFacts(BuildContext context, TravelPreparation prep,
    {bool notices = false}) async {
  final items = prep.items
      .where((item) => notices ? item.title == '入园须知' : item.title != '入园须知')
      .toList();
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: notePaper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(28))),
      builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(23),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(notices ? '入园须知' : '开放与交通',
                              style: noteSerif(23))),
                      IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close, size: 18))
                    ]),
                    if (items.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('信息待补充',
                              style: noteSans(13, color: noteQuiet))),
                    for (final item in items) ...[
                      if (!notices)
                        Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 8),
                            child: Text(item.title, style: noteSerif(18))),
                      if (item.body.isNotEmpty)
                        SelectableText(item.body,
                            style: noteSans(13, height: 1.9)),
                      if (safePreparationUri(item.url) != null)
                        PreparationLink('查看官方详情',
                            onTap: () => openPreparationLink(sheet, item.url,
                                external: prep.external)),
                    ],
                    if (safePreparationUri(prep.text('source_url')) != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: TravelRow('信息来源',
                              subtitle: prep.text('verified_on'),
                              onTap: () => openPreparationLink(
                                  sheet, prep.text('source_url')))),
                  ]))));
}

class _TicketClip extends CustomClipper<Path> {
  const _TicketClip();
  @override
  Path getClip(Size size) => Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addOval(
            Rect.fromCircle(center: Offset(0, size.height - 56), radius: 7))
        ..addOval(Rect.fromCircle(
            center: Offset(size.width, size.height - 56), radius: 7)));
  @override
  bool shouldReclip(_TicketClip oldClipper) => false;
}

class _TicketRule extends CustomPainter {
  const _TicketRule();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffbfc3af)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + 3).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_TicketRule oldDelegate) => false;
}
