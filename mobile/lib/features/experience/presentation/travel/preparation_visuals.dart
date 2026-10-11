import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../community/notes_widgets.dart';
import '../widgets/discovery_art.dart';

const preparationRed = Color(0xffbc4432);
const preparationSheet = Color(0xffeeebdf);
const preparationGreen = Color(0xff78826b);

/// Layout measurements come from travel-shared-guides.html. The footer follows
/// long content and sits at the bottom when the document fits on one screen.
class PreparationScaffold extends StatelessWidget {
  const PreparationScaffold(
      {super.key,
      required this.title,
      required this.child,
      this.trailing,
      this.footer,
      this.onBack,
      this.onRefresh});
  final String title;
  final Widget child;
  final Widget? trailing, footer;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: notePaper,
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final inset = preparationInset(context);
        final scroll = SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: RepaintBoundary(
                key: const ValueKey('preparation-document'),
                child: ColoredBox(
                    color: notePaper,
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: inset),
                                  child: PreparationTop(title,
                                      trailing: trailing, onBack: onBack)),
                              Expanded(
                                  child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          inset, 8, inset, 24),
                                      child: child)),
                              if (footer != null)
                                Container(
                                    margin:
                                        EdgeInsets.symmetric(horizontal: inset),
                                    constraints:
                                        const BoxConstraints(minHeight: 80),
                                    padding: const EdgeInsets.only(
                                        top: 14, bottom: 20),
                                    decoration: const BoxDecoration(
                                        border: Border(
                                            top: BorderSide(color: noteLine))),
                                    child: footer),
                            ]))))));
        return onRefresh == null
            ? scroll
            : RefreshIndicator(onRefresh: onRefresh!, child: scroll);
      })));
}

double preparationInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 350 ? 19 : 23;

class PreparationTop extends StatelessWidget {
  const PreparationTop(this.title, {super.key, this.trailing, this.onBack});
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 66,
      child: Row(children: [
        Expanded(
            child: NoteButton(
                label: '返回',
                onTap: onBack ??
                    () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/?tab=community');
                      }
                    },
                child: SizedBox(
                    height: 44,
                    child: Row(children: [
                      const DiscoveryIcon(DiscoveryMark.arrowLeft,
                          size: 17, color: noteQuiet),
                      const SizedBox(width: 9),
                      Text(title, style: noteSans(12)),
                    ])))),
        if (trailing != null) trailing!,
      ]));
}

class PreparationLink extends StatelessWidget {
  const PreparationLink(this.label,
      {super.key,
      this.onTap,
      this.icon = DiscoveryMark.arrowUpRight,
      this.pencil = false,
      this.busy = false,
      this.leadingIcon = false,
      this.size = 13});
  final String label;
  final VoidCallback? onTap;
  final DiscoveryMark icon;
  final bool pencil, busy, leadingIcon;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: busy,
      child: NoteButton(
          label: label,
          onTap: onTap,
          child: Opacity(
              opacity: onTap == null && !busy ? .45 : 1,
              child: CustomPaint(
                  painter: pencil ? const _Pencil() : null,
                  child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: EdgeInsets.only(
                          left: pencil ? 2 : 0,
                          right: pencil ? 2 : 0,
                          bottom: pencil ? 5 : 0),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (leadingIcon) ...[
                          DiscoveryIcon(icon, size: 17, color: preparationRed),
                          const SizedBox(width: 7)
                        ],
                        Text(label,
                            style: noteSerif(pencil ? 14 : size,
                                color: preparationRed,
                                weight: FontWeight.w500)),
                        if (!leadingIcon || busy) const SizedBox(width: 7),
                        if (busy)
                          const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.4, color: preparationRed))
                        else if (!leadingIcon)
                          DiscoveryIcon(icon, size: 17, color: preparationRed),
                      ]))))));
}

class _Pencil extends CustomPainter {
  const _Pencil();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xa0bc4432)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - 5)
          ..cubicTo(size.width * .25, size.height - 11, size.width * .67,
              size.height - 10, size.width, size.height - 7),
        p);
    p.color = const Color(0x68bc4432);
    canvas.drawPath(
        Path()
          ..moveTo(10, size.height - 2)
          ..quadraticBezierTo(size.width * .6, size.height - 8, size.width - 5,
              size.height - 4),
        p);
  }

  @override
  bool shouldRepaint(covariant _Pencil oldDelegate) => false;
}

class PreparationOutline extends StatelessWidget {
  const PreparationOutline(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => NoteButton(
      label: label,
      onTap: onTap,
      child: Container(
          constraints: const BoxConstraints(minHeight: 47),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border.all(color: noteLine),
              borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Text(label, style: noteSans(13))));
}

class PreparationFacts extends StatelessWidget {
  const PreparationFacts(
      {super.key,
      required this.left,
      required this.right,
      required this.onLeft,
      required this.onRight});
  final String left, right;
  final VoidCallback onLeft, onRight;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(top: 11),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: noteLine))),
      child: Row(children: [
        Expanded(child: _entry(left, onLeft)),
        const SizedBox(width: 20),
        Expanded(child: _entry(right, onRight))
      ]));
  Widget _entry(String text, VoidCallback tap) => NoteButton(
      label: text,
      onTap: tap,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Row(children: [
                Expanded(child: Text(text, style: noteSans(12))),
                const Icon(Icons.chevron_right, size: 13, color: noteQuiet)
              ]))));
}

/// Editorial titles break at the first clause instead of leaving a lone last word.
String preparationTitle(String title) {
  final comma = title.indexOf('，');
  if (comma > 0 && title.length > 14 && comma <= 14) {
    return '${title.substring(0, comma + 1)}\n${title.substring(comma + 1)}';
  }
  return title;
}
