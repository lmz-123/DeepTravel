import 'package:flutter/material.dart';

const manualPaper = Color(0xFFF5F0E7);
const manualInk = Color(0xFF252824);
const manualRed = Color(0xFFCF432F);
const manualLime = Color(0xFFDBE782);
const manualMuted = Color(0xFF797C70);
const manualSerif = 'Noto Serif SC';

TextStyle manualType(
  double size, {
  Color color = manualInk,
  double height = 1.5,
  bool serif = false,
  FontWeight weight = FontWeight.w400,
  double spacing = 0,
}) =>
    TextStyle(
      fontFamily: serif ? manualSerif : null,
      fontSize: size,
      color: color,
      height: height,
      fontWeight: weight,
      letterSpacing: spacing,
    );

class ManualPaperAction extends StatelessWidget {
  const ManualPaperAction({
    required this.label,
    required this.onPressed,
    this.folio,
    this.subtitle,
    this.play = false,
    super.key,
  });
  final String label;
  final String? folio;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool play;

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width <= 375;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: subtitle == null
            ? null
            : const [BoxShadow(color: Color(0xFFDEC9B8), offset: Offset(0, 4))],
      ),
      child: Material(
        color: const Color(0xFFBC4432),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle == null ? 60 : 70),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: small ? 13 : 17,
                vertical: 11,
              ),
              child: Row(
                children: [
                  if (folio != null) ...[
                    Container(
                      padding: EdgeInsets.only(right: small ? 12 : 15),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0x47FFF8E9)),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            folio!,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 28,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFFFF8E9),
                              height: 1,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'INDEX',
                              style: manualType(
                                7,
                                color: const Color(0xFFFFF8E9),
                                spacing: 1.12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: small ? 11 : 15),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: manualType(
                            small ? 17 : 18,
                            serif: true,
                            color: const Color(0xFFFFF8E9),
                            height: 1.35,
                            weight: FontWeight.w500,
                            spacing: -.45,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            style: manualType(
                              10,
                              color: const Color(0xFFFFEDDB),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 33,
                    height: 33,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x6BFFF8E9)),
                    ),
                    child: Icon(
                      play
                          ? Icons.play_arrow_rounded
                          : Icons.arrow_forward_rounded,
                      color: const Color(0xFFFFF8E9),
                      size: play ? 21 : 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManualPhoto extends StatelessWidget {
  const ManualPhoto({required this.source, this.height, super.key});
  final String source;
  final double? height;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: source.isEmpty
            ? const ColoredBox(color: Color(0xFFD9DDC2))
            : Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFFD9DDC2)),
              ),
      );
}

class ManualCircledNumber extends StatelessWidget {
  const ManualCircledNumber({
    required this.text,
    this.selected = false,
    super.key,
  });
  final String text;
  final bool selected;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (selected)
              Transform.rotate(
                angle: -.297,
                child: Container(
                  width: 45,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: manualRed, width: 1.5),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 26,
                fontStyle: FontStyle.italic,
                color: selected ? manualRed : const Color(0xFF858979),
                height: 1,
              ),
            ),
          ],
        ),
      );
}
