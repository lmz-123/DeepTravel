import 'package:flutter/material.dart';

class EditorialImage extends StatelessWidget {
  const EditorialImage({
    required this.source,
    super.key,
    this.height,
    this.borderRadius = 0,
    this.child,
    this.heroTag,
  });

  final String source;
  final double? height;
  final double borderRadius;
  final Widget? child;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget image = SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (source.isEmpty)
            const ColoredBox(color: Color(0xFFB9B6AA))
          else
            Image.network(
              source,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(
                  color: Color(0xFFB9B6AA),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: Color(0xFFB9B6AA),
                child: Center(child: Icon(Icons.image_not_supported_outlined)),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB8142B33)],
                stops: [0.34, 1],
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
    image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius), child: image);
    return heroTag == null ? image : Hero(tag: heroTag!, child: image);
  }
}
