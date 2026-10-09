import 'package:go_router/go_router.dart';
import '../../features/experience/presentation/community/note_detail_page.dart';
import '../../features/experience/presentation/community/note_compose_page.dart';

import '../../features/experience/presentation/discovery_page.dart';
import '../../features/experience/presentation/footprint_detail_page.dart';
import '../../features/experience/presentation/footprints_page.dart';
import '../../features/experience/presentation/journey_redirect_page.dart';
import '../../features/experience/presentation/recap_page.dart';
import '../../features/experience/presentation/route_detail_page.dart';
import '../../features/experience/presentation/settings_page.dart';
import '../../features/experience/presentation/home_story_page.dart';
import '../../features/experience/presentation/profile_page.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
        path: '/community/write',
        builder: (context, state) =>
            NoteComposePage(fragmentId: state.uri.queryParameters['fragment'])),
    GoRoute(
        path: '/community/post/:id',
        builder: (context, state) =>
            NoteDetailPage(postId: state.pathParameters['id']!)),
    GoRoute(
      path: '/',
      builder: (context, state) => DiscoveryPage(
        initialTab: state.uri.queryParameters['tab'],
        initialCompanionFragmentId: state.uri.queryParameters['fragment'],
        initialCompanionRouteSlug: state.uri.queryParameters['route'],
        initialCompanionRequestId: state.uri.queryParameters['selection'],
      ),
    ),
    GoRoute(
      path: '/route/:slug',
      builder: (context, state) =>
          RouteDetailPage(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/journey/:id',
      builder: (context, state) =>
          JourneyRedirectPage(journeyId: state.pathParameters['id']!),
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
          FootprintDetailPage(footprintId: state.pathParameters['id']!),
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
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
  ],
);
