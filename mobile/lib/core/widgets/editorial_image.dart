import 'package:flutter/material.dart';

class EditorialImage extends StatelessWidget {
  const EditorialImage({
    required this.asset,
    super.key,
    this.height,
    this.borderRadius = 0,
    this.child,
    this.heroTag,
  });

  final String asset;
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
          Image.asset(asset, fit: BoxFit.cover),
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
