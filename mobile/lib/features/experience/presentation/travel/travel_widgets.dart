import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/travel_preparation.dart';
import '../route_manual/manual_visuals.dart';

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

class TravelHeading extends StatelessWidget {
  const TravelHeading(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 15),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: manualType(23, serif: true, weight: FontWeight.w500))),
        if (trailing != null) trailing!
      ]));
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
          padding: const EdgeInsets.fromLTRB(19, 18, 19, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: manualType(19,
                          serif: true, weight: FontWeight.w500))),
              const Icon(Icons.confirmation_number_outlined,
                  size: 24, color: Color(0xff66745b))
            ]),
            const SizedBox(height: 7),
            Text(subtitle, style: manualType(11, color: AppColors.textMuted)),
            const SizedBox(height: 17),
            const SizedBox(
                height: 1,
                width: double.infinity,
                child: CustomPaint(painter: _TicketRule())),
            Row(children: [
              Expanded(
                  child: Text(footnote,
                      style: manualType(11, color: AppColors.textMuted))),
              const SizedBox(width: 8),
              TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.action,
                      padding: EdgeInsets.zero),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(action,
                        style: manualType(13,
                            serif: true, color: AppColors.action)),
                    const SizedBox(width: 7),
                    const Icon(Icons.arrow_outward, size: 16)
                  ]))
            ]),
          ])));
}

Future<void> showPreparationItem(BuildContext context, PreparationItem item,
    {bool external = false}) async {
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(28), topLeft: Radius.circular(4))),
      builder: (sheet) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(23),
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(item.title,
                              style: manualType(23, serif: true))),
                      IconButton(
                          onPressed: () => Navigator.pop(sheet),
                          tooltip: '关闭',
                          icon: const Icon(Icons.close))
                    ]),
                    const SizedBox(height: 16),
                    if (item.body.isNotEmpty)
                      SelectableText(item.body,
                          style: manualType(14, height: 1.9)),
                    if (safePreparationUri(item.url) != null) ...[
                      const SizedBox(height: 22),
                      Text(Uri.parse(item.url).host,
                          style: manualType(11, color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      ManualPaperAction(
                          label: '查看官方详情',
                          onPressed: () => openPreparationLink(sheet, item.url,
                              external: external))
                    ],
                  ])))));
}

class PreparationRows extends StatelessWidget {
  const PreparationRows(this.preparation, {super.key});
  final TravelPreparation preparation;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final item in preparation.items)
          TravelRow(item.title,
              subtitle: item.url.isNotEmpty ? '查看详情' : null,
              onTap: () => showPreparationItem(context, item,
                  external: preparation.external)),
      ]);
}

class _TicketClip extends CustomClipper<Path> {
  const _TicketClip();
  @override
  Path getClip(Size size) => Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addOval(
            Rect.fromCircle(center: Offset(0, size.height - 57), radius: 7))
        ..addOval(Rect.fromCircle(
            center: Offset(size.width, size.height - 57), radius: 7)));
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
