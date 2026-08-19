import 'package:go_router/go_router.dart';

import '../../features/experience/presentation/discovery_page.dart';
import '../../features/experience/presentation/journey_page.dart';
import '../../features/experience/presentation/recap_page.dart';
import '../../features/experience/presentation/route_detail_page.dart';

final appRouter = GoRouter(
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
  ],
);
