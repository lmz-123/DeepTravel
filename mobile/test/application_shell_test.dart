import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/auth/domain/auth_models.dart';
import 'package:jiandi/features/auth/presentation/auth_provider.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/profile_page.dart';

void main() {
  testWidgets('personal file owns navigation without a legacy drawer',
      (tester) async {
    final player = _Player();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(
        DemoExperienceRepository(latency: Duration.zero),
      ),
      narrationPlayerProvider.overrideWithValue(player),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const DiscoveryPage()),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: '/footprints',
        builder: (_, __) => const Scaffold(body: Text('足迹页已打开')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('设置页已打开')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    final originalPlayer = container.read(narrationPlayerProvider);

    final profileTrigger = find.bySemanticsLabel(RegExp('打开个人档案'));
    expect(profileTrigger, findsOneWidget);
    await tester.tap(profileTrigger);
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE FILE / 见地档案'), findsOneWidget);
    expect(find.byTooltip('打开旅行者菜单'), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byIcon(Icons.menu_rounded), findsNothing);

    await tester.dragFrom(const Offset(1, 300), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('PRIVATE FILE / 见地档案'), findsOneWidget);

    final footprints = find.text('还没有留下足迹');
    await tester.ensureVisible(footprints);
    await tester.pumpAndSettle();
    await tester.tap(footprints);
    await tester.pumpAndSettle();
    expect(find.text('足迹页已打开'), findsOneWidget);
    expect(container.read(narrationPlayerProvider), same(originalPlayer));

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('足迹页已打开'), findsNothing);
    await tester.scrollUntilVisible(find.byTooltip('设置'), -300);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置页已打开'), findsOneWidget);
    expect(container.read(narrationPlayerProvider), same(originalPlayer));

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('设置页已打开'), findsNothing);
  });

  testWidgets(
      'personal file account switch and logout clear private local state',
      (tester) async {
    final auth = _Auth();
    final store = _Store();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      experienceRepositoryProvider.overrideWithValue(
        DemoExperienceRepository(latency: Duration.zero),
      ),
      narrationPlayerProvider.overrideWithValue(_Player()),
      tourStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const DiscoveryPage()),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfilePage(),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await container.read(authControllerProvider.future);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('打开个人档案')));
    await tester.pumpAndSettle();
    expect(find.text('tester-a'), findsOneWidget);
    await tester.ensureVisible(find.text('切换测试账号 B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换测试账号 B'));
    await tester.pumpAndSettle();
    expect(auth.session?.user.id, 'tester-b');
    expect(store.clearCalls, 1);

    await tester.tap(find.bySemanticsLabel(RegExp('打开个人档案')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('退出这个账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出这个账号'));
    await tester.pumpAndSettle();
    expect(auth.session, isNull);
    expect(store.clearCalls, 2);
  });
}

class _Auth extends AuthRepository {
  _Auth() : super(Dio());

  AuthSession? _current = _authSession('tester-a');

  @override
  AuthSession? get session => _current;

  @override
  String? get token => _current?.token;

  @override
  Future<AuthSession?> restore() async => _current;

  @override
  Future<AuthSession> testLogin(String alias) async =>
      _current = _authSession(alias);

  @override
  Future<void> logout() async => _current = null;
}

AuthSession _authSession(String id) => AuthSession(
      user: AuthUser(id: id, username: id, accountKind: 'test'),
      token: '$id-token',
    );

class _Store implements TourStore {
  int clearCalls = 0;

  @override
  Future<void> clearPrivateData() async => clearCalls += 1;

  @override
  Future<void> acknowledge(String id) async {}

  @override
  Future<void> enqueue(OutboxEvent event) async {}

  @override
  Future<List<OutboxEvent>> pending() async => const [];

  @override
  Future<String?> preparedAsset(
          String url, String version, int sizeBytes) async =>
      null;

  @override
  Future<List<PreparedAssetRecord>> preparedAssets() async => const [];

  @override
  Future<void> removePreparedAsset(String url) async {}

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => null;

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {}

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}

class _Player implements NarrationPlayer {
  @override
  Stream<bool> get completedStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}
