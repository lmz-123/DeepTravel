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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
                light ? AppColors.white.withValues(alpha: 0.16) : AppColors.ink,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '见',
            style: TextStyle(
              color: light ? color : AppColors.gold,
              fontFamily: 'Songti SC',
              fontFamilyFallback: const ['STSong', 'serif'],
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '见地',
              style: TextStyle(
                color: color,
                fontFamily: 'Songti SC',
                fontFamilyFallback: const ['STSong', 'serif'],
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'JIAN · DI',
              style: TextStyle(
                color: color.withValues(alpha: .62),
                fontSize: 7,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.7,
              ),
            ),
          ],
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
