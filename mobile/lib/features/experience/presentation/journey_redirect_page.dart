import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/travel_destinations.dart';
import '../domain/models.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'route_manual/manual_visuals.dart';

/// Compatibility for saved links. Resolving a journey never starts a walk or
/// changes an existing tour; the companion destination owns explicit startup.
class JourneyRedirectPage extends ConsumerStatefulWidget {
  const JourneyRedirectPage({required this.journeyId, super.key});
  final String journeyId;

  @override
  ConsumerState<JourneyRedirectPage> createState() =>
      _JourneyRedirectPageState();
}

class _JourneyRedirectPageState extends ConsumerState<JourneyRedirectPage> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scheduleResolve();
  }

  @override
  void didUpdateWidget(JourneyRedirectPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journeyId != widget.journeyId) _scheduleResolve();
  }

  void _scheduleResolve() {
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve(generation));
  }

  Future<void> _resolve(int generation) async {
    if (!mounted || generation != _generation) return;
    final active = ref.read(activeTourControllerProvider);
    final journey = ref.read(journeyControllerProvider);
    RouteExperience? route;
    if (active.session?.id == widget.journeyId) {
      route = active.route;
    } else if (journey.session?.id == widget.journeyId) {
      route = journey.route;
    }
    final userId = ref.read(currentUserIdProvider);
    bool failed = false;
    if (route == null && userId != null) {
      try {
        final saved = await ref.read(
          journeyContextProvider(UserJourneyKey(userId, widget.journeyId))
              .future,
        );
        route = saved.route;
      } catch (_) {
        failed = true;
      }
    }
    if (!mounted ||
        generation != _generation ||
        ref.read(currentUserIdProvider) != userId) {
      return;
    }
    if (failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('历史旅程暂时无法读取，请在随行中重新选择路线。')),
      );
    }
    final slug = route?.slug;
    if (route != null && !(route.audioTour?.fragments.isNotEmpty ?? false)) {
      context.go(Uri(pathSegments: ['', 'route', slug!]).toString());
    } else {
      context.go(companionLocation(slug));
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: manualPaper,
        body: Center(
          child: CircularProgressIndicator(color: manualRed, strokeWidth: 1.5),
        ),
      );
}
