import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/travel_destinations.dart';
import '../../../../core/theme/app_theme.dart';
import '../active_tour_controller.dart';
import 'discovery_art.dart';

// Legacy destinations stay available to existing journey and footprint screens.
enum TravelerSection {
  discovery,
  journey,
  footprints,
  journal,
  atlas,
  companion,
  shelf,
}

class TravelerBottomNavigation extends ConsumerWidget {
  const TravelerBottomNavigation({
    required this.active,
    super.key,
    this.journeyId,
    this.onSelected,
    this.editorial = false,
  });
  final TravelerSection active;
  final String? journeyId;
  final bool editorial;
  final ValueChanged<TravelerSection>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizontal = MediaQuery.sizeOf(context).width <= 360 ? 20.0 : 23.0;
    final entries = [
      (TravelerSection.journal, DiscoveryMark.book, '随刊'),
      (
        TravelerSection.atlas,
        editorial ? DiscoveryMark.compass : DiscoveryMark.search,
        '路线'
      ),
      (TravelerSection.companion, DiscoveryMark.pin, '随行'),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        MediaQuery.paddingOf(context)
            .bottom
            .clamp(editorial ? 20.0 : 15.0, double.infinity)
            .toDouble(),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x4db9b7a8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0a27291d),
                  offset: Offset(0, 5),
                  blurRadius: 26,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: const Color(0xeff7f3ea),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: entries.map((entry) {
                      final selected = active == entry.$1 ||
                          active == TravelerSection.discovery &&
                              entry.$1 == TravelerSection.journal;
                      final color = selected
                          ? AppColors.terracotta
                          : const Color(0xff87806f);
                      return Expanded(
                        child: DiscoveryTouch(
                          label: entry.$3,
                          selected: selected,
                          tint: true,
                          onTap: () => _select(context, ref, entry.$1),
                          child: SizedBox(
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DiscoveryIcon(
                                      entry.$2,
                                      size: 19,
                                      color: color,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      entry.$3,
                                      style: discoverySans(12, color: color),
                                    ),
                                  ],
                                ),
                                if (selected)
                                  Positioned(
                                    bottom: 7,
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: AppColors.terracotta,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          if (!editorial)
            Positioned(
              top: -1,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xffdbe782),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _select(BuildContext context, WidgetRef ref, TravelerSection section) {
    if (onSelected != null) {
      onSelected!(section);
      return;
    }
    if (section == TravelerSection.journey) {
      context.go(companionLocation(
          ref.read(activeTourControllerProvider).route?.slug));
      return;
    }
    if (section == TravelerSection.footprints) {
      context.go('/footprints');
      return;
    }
    context.go(
      section == TravelerSection.journal ? '/' : '/?tab=${section.name}',
    );
  }
}
