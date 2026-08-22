import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.onPressed});

  final bool light;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.white : AppColors.ink;
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                light ? AppColors.white.withValues(alpha: 0.16) : AppColors.ink,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.explore_rounded,
              size: 18, color: light ? color : AppColors.gold),
        ),
        const SizedBox(width: 10),
        Text(
          '见地',
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ],
    );
    if (onPressed == null) {
      return Semantics(label: '见地', child: mark);
    }
    return Semantics(
      button: true,
      label: '打开旅行者菜单',
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: mark,
        ),
      ),
    );
  }
}
