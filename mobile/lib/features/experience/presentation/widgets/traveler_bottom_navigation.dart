import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../active_tour_controller.dart';

enum TravelerSection { discovery, journey, footprints }

class TravelerBottomNavigation extends ConsumerWidget {
  const TravelerBottomNavigation({
    required this.active,
    super.key,
    this.journeyId,
  });

  final TravelerSection active;
  final String? journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .13),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              _Destination(
                active: active == TravelerSection.discovery,
                icon: Icons.explore_outlined,
                label: '发现',
                onTap: () => context.go('/'),
              ),
              _Destination(
                active: active == TravelerSection.journey,
                icon: Icons.radar_rounded,
                label: '行走',
                onTap: () => _openJourney(context, ref),
              ),
              _Destination(
                active: active == TravelerSection.footprints,
                icon: Icons.auto_stories_outlined,
                label: '足迹',
                onTap: () => context.go('/footprints'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openJourney(BuildContext context, WidgetRef ref) {
    final id = journeyId ?? ref.read(activeTourControllerProvider).session?.id;
    if (id != null) {
      context.go('/journey/$id');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('先打开一本城市手册，再开始行走')),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 52,
              decoration: BoxDecoration(
                color: active ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: active ? AppColors.white : AppColors.textMuted,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? AppColors.white : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
