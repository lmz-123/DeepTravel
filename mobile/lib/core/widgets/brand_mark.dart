import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false});

  final bool light;

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
              fontFamily: 'Noto Serif SC',
              fontFamilyFallback: const ['serif'],
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
                fontFamily: 'Noto Serif SC',
                fontFamilyFallback: const ['serif'],
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
    return Semantics(label: '见地', child: mark);
  }
}
