import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/app.dart';
import 'package:jiandi/core/router/app_router.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  testWidgets('featured route can start in two taps', (tester) async {
    appRouter.go('/');
    final repository = DemoExperienceRepository(latency: Duration.zero);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('梧桐树下的城市切片'), findsOneWidget);
    await tester.ensureVisible(find.text('梧桐树下的城市切片'));
    await tester.tap(find.text('梧桐树下的城市切片'));
    await tester.pumpAndSettle();

    expect(find.text('开始这段探索'), findsOneWidget);
    await tester.tap(find.text('开始这段探索'));
    await tester.pumpAndSettle();

    expect(find.text('我已到达，开始观察'), findsOneWidget);
  });

  testWidgets('arrival reveals story and observation challenge',
      (tester) async {
    appRouter.go('/');
    final repository = DemoExperienceRepository(latency: Duration.zero);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('梧桐树下的城市切片'));
    await tester.tap(find.text('梧桐树下的城市切片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始这段探索'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('我已到达，开始观察'));
    await tester.tap(find.text('我已到达，开始观察'));
    await tester.pumpAndSettle();

    expect(find.text('一栋顺着街角生长的建筑'), findsOneWidget);
    expect(find.text('观察一下'), findsOneWidget);
    expect(find.textContaining('一艘停靠街角的船'), findsOneWidget);
  });

  testWidgets('defaults to Shenzhen and reloads after selecting Shanghai',
      (tester) async {
    appRouter.go('/');
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深圳'), findsOneWidget);
    expect(repository.requestedCity, 'shenzhen');

    await tester.tap(find.byTooltip('选择城市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上海').last);
    await tester.pumpAndSettle();

    expect(find.text('上海'), findsOneWidget);
    expect(repository.requestedCity, 'shanghai');
  });
}

class _RecordingRepository extends DemoExperienceRepository {
  _RecordingRepository() : super(latency: Duration.zero);

  String? requestedCity;

  @override
  Future<RouteExperience> featuredRoute(String citySlug) {
    requestedCity = citySlug;
    return super.featuredRoute(citySlug);
  }
}
