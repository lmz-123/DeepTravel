import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/tour_runtime.dart';

class LocationModeSelector extends StatelessWidget {
  const LocationModeSelector({
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    super.key,
  });

  final TourLocationMode value;
  final ValueChanged<TourLocationMode> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ModeButton(
              key: ValueKey('$keyPrefix-real'),
              icon: Icons.directions_walk_rounded,
              label: '真实行走模式',
              selected: value == TourLocationMode.real,
              onPressed: () => onChanged(TourLocationMode.real),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              key: ValueKey('$keyPrefix-simulated'),
              icon: Icons.explore_outlined,
              label: '模拟预览模式',
              selected: value == TourLocationMode.simulated,
              onPressed: () => onChanged(TourLocationMode.simulated),
            ),
          ),
        ],
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? AppColors.moss : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: selected
                      ? AppColors.moss
                      : AppColors.ink.withValues(alpha: .14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? AppColors.white : AppColors.ink,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: selected ? AppColors.white : AppColors.ink,
                            fontSize: 9,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
