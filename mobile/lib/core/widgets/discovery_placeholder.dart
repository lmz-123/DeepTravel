import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The journal's page structure remains visible while public content arrives.
class DiscoveryPlaceholder extends StatelessWidget {
  const DiscoveryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '正在载入发现',
        child: ExcludeSemantics(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(23, 28, 23, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(84, 9),
                const SizedBox(height: 27),
                _line(190, 30),
                const SizedBox(height: 15),
                _line(155, 30),
                const SizedBox(height: 28),
                Container(
                  height: 234,
                  decoration: BoxDecoration(
                    color: AppColors.moss.withValues(alpha: .10),
                    borderRadius:
                        const BorderRadius.only(topRight: Radius.circular(67)),
                  ),
                ),
                const SizedBox(height: 26),
                _line(110, 15),
                const SizedBox(height: 16),
                _line(240, 9),
              ],
            ),
          ),
        ),
      );

  Widget _line(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.moss.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
