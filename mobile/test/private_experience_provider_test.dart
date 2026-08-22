import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/auth/domain/auth_models.dart';
import 'package:jiandi/features/auth/presentation/auth_provider.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  test(
      'private providers change account scope and never render prior user data',
      () async {
    final auth = _SwitchableAuthRepository();
    final repository = _ScopedRepository(auth);
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      experienceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.read(privateExperienceLifecycleProvider);

    await container.read(authControllerProvider.future);
    final first = await container.read(currentJourneyLibraryProvider.future);
    expect(first.single.route.title, 'tester-a 的路线');

    await container
        .read(authControllerProvider.notifier)
        .switchTestUser('tester-b');
    final second = await container.read(currentJourneyLibraryProvider.future);

    expect(second.single.route.title, 'tester-b 的路线');
    expect(second.single.journey.id, 'tester-b-journey');
    expect(repository.requestedUsers.first, 'tester-a');
    expect(repository.requestedUsers.skip(1), everyElement('tester-b'));
  });

  test('one evidence list failure does not discard another journey result',
      () async {
    final auth = _SwitchableAuthRepository();
    final repository = _ScopedRepository(auth);
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    final available = await container.read(
      journeyEvidenceProvider(const UserJourneyKey('tester-a', 'ok')).future,
    );
    expect(available.single.id, 'evidence-ok');

    await expectLater(
      container.read(
        journeyEvidenceProvider(
          const UserJourneyKey('tester-a', 'unavailable'),
        ).future,
      ),
      throwsStateError,
    );
    expect(
      container
          .read(journeyEvidenceProvider(
            const UserJourneyKey('tester-a', 'ok'),
          ))
          .value
          ?.single
          .id,
      'evidence-ok',
    );
  });

  test('authenticated evidence bytes are reloaded after account switch',
      () async {
    final auth = _SwitchableAuthRepository();
    final repository = _ScopedRepository(auth);
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      experienceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.read(privateExperienceLifecycleProvider);
    await container.read(authControllerProvider.future);
    const evidence = EvidenceRecord(id: 'evidence-ok', url: '/private/photo');

    final first = await container.read(evidenceBytesProvider(
      const EvidenceBytesKey(
        userId: 'tester-a',
        journeyId: 'tester-a-journey',
        evidence: evidence,
      ),
    ).future);
    await container
        .read(authControllerProvider.notifier)
        .switchTestUser('tester-b');
    final second = await container.read(evidenceBytesProvider(
      const EvidenceBytesKey(
        userId: 'tester-b',
        journeyId: 'tester-b-journey',
        evidence: evidence,
      ),
    ).future);

    expect(first, [1]);
    expect(second, [2]);
    expect(repository.requestedByteUsers, ['tester-a', 'tester-b']);
  });
}

class _SwitchableAuthRepository extends AuthRepository {
  _SwitchableAuthRepository() : super(Dio());

  AuthSession _current = _session('tester-a');

  String get currentUserId => _current.user.id;

  @override
  AuthSession? get session => _current;

  @override
  String? get token => _current.token;

  @override
  Future<AuthSession?> restore() async => _current;

  @override
  Future<AuthSession> testLogin(String alias) async =>
      _current = _session(alias);
}

class _ScopedRepository extends DemoExperienceRepository {
  _ScopedRepository(this.auth) : super(latency: Duration.zero);

  final _SwitchableAuthRepository auth;
  final List<String> requestedUsers = [];
  final List<String> requestedByteUsers = [];

  @override
  Future<List<JourneyLibraryItem>> journeys({String? status}) async {
    final userId = auth.currentUserId;
    requestedUsers.add(userId);
    return [_libraryItem(userId)];
  }

  @override
  Future<List<EvidenceRecord>> evidence(String journeyId) async {
    if (journeyId == 'unavailable') throw StateError('照片列表暂时不可用');
    return const [
      EvidenceRecord(
        id: 'evidence-ok',
        url: '/journeys/ok/evidence/evidence-ok',
      ),
    ];
  }

  @override
  Future<Uint8List> evidenceBytes(
      String journeyId, EvidenceRecord evidence) async {
    final userId = auth.currentUserId;
    requestedByteUsers.add(userId);
    return Uint8List.fromList([userId == 'tester-a' ? 1 : 2]);
  }
}

AuthSession _session(String userId) => AuthSession(
      user: AuthUser(id: userId, username: userId, accountKind: 'test'),
      token: '$userId-token',
    );

JourneyLibraryItem _libraryItem(String userId) => JourneyLibraryItem(
      journey: JourneySession(
        id: '$userId-journey',
        routeId: '$userId-route',
        status: 'completed',
        currentStopPosition: 1,
        arrivedStopId: null,
        answeredStopIds: const {},
        progress: 1,
      ),
      route: RouteExperience(
        id: '$userId-route',
        slug: '$userId-route',
        title: '$userId 的路线',
        subtitle: '足迹',
        description: '账户隔离测试',
        durationMinutes: 10,
        distanceKm: 1,
        difficulty: '轻松',
        theme: '测试',
        heroImage: '',
        contentStatus: 'published',
        stops: const [],
      ),
      journeyKind: 'legacy',
      collectedCount: 1,
      totalCount: 1,
      evidenceCount: 0,
    );
