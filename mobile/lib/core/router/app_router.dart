import 'package:go_router/go_router.dart';

import '../../features/experience/presentation/discovery_page.dart';
import '../../features/experience/presentation/footprint_detail_page.dart';
import '../../features/experience/presentation/footprints_page.dart';
import '../../features/experience/presentation/journey_page.dart';
import '../../features/experience/presentation/recap_page.dart';
import '../../features/experience/presentation/route_detail_page.dart';
import '../../features/experience/presentation/settings_page.dart';
import '../../features/experience/presentation/home_story_page.dart';
import '../../features/experience/presentation/traveler_shell.dart';

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => TravelerShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DiscoveryPage()),
        GoRoute(
          path: '/route/:slug',
          builder: (context, state) =>
              RouteDetailPage(slug: state.pathParameters['slug']!),
        ),
        GoRoute(
          path: '/journey/:id',
          builder: (context, state) =>
              JourneyPage(journeyId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/recap/:id',
          builder: (context, state) =>
              RecapPage(journeyId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/footprints',
          builder: (context, state) => const FootprintsPage(),
        ),
        GoRoute(
          path: '/footprints/:id',
          builder: (context, state) =>
              FootprintDetailPage(journeyId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/story',
          builder: (context, state) => const HomeStoryPage(),
        ),
        GoRoute(
          path: '/story/:catalogId',
          builder: (context, state) => HomeStoryPage(
            catalogId: state.pathParameters['catalogId'],
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
