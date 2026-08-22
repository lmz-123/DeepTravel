import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/runtime_log_reporter.dart';
import '../data/api_experience_repository.dart';
import '../data/demo_experience_repository.dart';
import '../data/narration_voice_preference_repository.dart';
import '../data/user_preferences_repository.dart';
import '../domain/experience_repository.dart';
import '../domain/fragment_models.dart';
import '../domain/models.dart';
import '../../auth/presentation/auth_provider.dart';
import 'location_mode_controller.dart';

final dioProvider = Provider<Dio>((ref) {
  final reporter = ref.watch(runtimeLogReporterProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) {
    final uri = error.requestOptions.uri;
    reporter?.error(
      'network',
      '${error.requestOptions.method} ${uri.path} failed',
      error: error,
      context: {
        'status_code': error.response?.statusCode ?? 0,
        'failure_type': error.type.name,
        'host': uri.host,
      },
    );
    handler.next(error);
  }));
  return dio;
});

final experienceRepositoryProvider = Provider<ExperienceRepository>((ref) {
  if (AppConfig.mode == AppMode.api) {
    return ApiExperienceRepository(
      ref.watch(dioProvider),
      ref.watch(authRepositoryProvider),
      onUnauthorized: () => ref.read(authControllerProvider.notifier).expire(),
    );
  }
  return DemoExperienceRepository();
});

final currentUserIdProvider = Provider<String?>(
    (ref) => ref.watch(authControllerProvider).asData?.value?.user.id);

final citiesProvider = FutureProvider<List<CityExperience>>((ref) {
  return ref.watch(experienceRepositoryProvider).cities();
});

class SelectedCityController extends Notifier<String?> {
  @override
  String? build() =>
      AppConfig.defaultCitySlug.isEmpty ? null : AppConfig.defaultCitySlug;

  void select(String citySlug) => state = citySlug;
}

final selectedCityProvider = NotifierProvider<SelectedCityController, String?>(
    SelectedCityController.new);

final activeCityProvider = Provider<CityExperience?>((ref) {
  final available = ref.watch(citiesProvider).asData?.value;
  if (available == null || available.isEmpty) return null;
  final selectedSlug = ref.watch(selectedCityProvider);
  if (selectedSlug == null) return available.first;
  for (final city in available) {
    if (city.slug == selectedSlug) return city;
  }
  return available.first;
});

final cityRoutesProvider = FutureProvider<List<RouteExperience>>((ref) {
  final city = ref.watch(activeCityProvider);
  if (city == null) return const <RouteExperience>[];
  return ref.watch(experienceRepositoryProvider).routesForCity(city.slug);
});

final archivedActiveJourneysProvider =
    FutureProvider<List<ResumableJourney>>((ref) {
  final repository = ref.watch(experienceRepositoryProvider);
  if (repository is ApiExperienceRepository) {
    return repository.archivedActiveJourneys();
  }
  return const <ResumableJourney>[];
});

class UserJourneyFilter {
  const UserJourneyFilter(this.userId, {this.status});

  final String userId;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is UserJourneyFilter &&
      other.userId == userId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(userId, status);
}

class UserJourneyKey {
  const UserJourneyKey(this.userId, this.journeyId);

  final String userId;
  final String journeyId;

  @override
  bool operator ==(Object other) =>
      other is UserJourneyKey &&
      other.userId == userId &&
      other.journeyId == journeyId;

  @override
  int get hashCode => Object.hash(userId, journeyId);
}

class EvidenceBytesKey {
  const EvidenceBytesKey({
    required this.userId,
    required this.journeyId,
    required this.evidence,
  });

  final String userId;
  final String journeyId;
  final EvidenceRecord evidence;

  @override
  bool operator ==(Object other) =>
      other is EvidenceBytesKey &&
      other.userId == userId &&
      other.journeyId == journeyId &&
      other.evidence.id == evidence.id &&
      other.evidence.url == evidence.url;

  @override
  int get hashCode => Object.hash(userId, journeyId, evidence.id, evidence.url);
}

final journeyLibraryProvider =
    FutureProvider.family<List<JourneyLibraryItem>, UserJourneyFilter>(
  (ref, query) =>
      ref.watch(experienceRepositoryProvider).journeys(status: query.status),
);

final journeyContextProvider =
    FutureProvider.family<JourneyContext, UserJourneyKey>(
  (ref, key) =>
      ref.watch(experienceRepositoryProvider).journeyContext(key.journeyId),
);

final journeyEvidenceProvider =
    FutureProvider.family<List<EvidenceRecord>, UserJourneyKey>(
  (ref, key) => ref.watch(experienceRepositoryProvider).evidence(key.journeyId),
);

final evidenceBytesProvider =
    FutureProvider.family<Uint8List, EvidenceBytesKey>((ref, key) {
  return ref
      .watch(experienceRepositoryProvider)
      .evidenceBytes(key.journeyId, key.evidence);
});

final evidencePolicyProvider = FutureProvider.family<EvidencePolicy, String>(
  (ref, userId) => ref.watch(experienceRepositoryProvider).evidencePolicy(),
);

final orbPositionProvider =
    FutureProvider.family<NormalizedOrbPosition, String>((ref, userId) =>
        ref.watch(userPreferencesRepositoryProvider).readOrbPosition(userId));

final currentJourneyLibraryProvider =
    FutureProvider<List<JourneyLibraryItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <JourneyLibraryItem>[];
  return ref.watch(
    journeyLibraryProvider(UserJourneyFilter(userId, status: 'completed'))
        .future,
  );
});

final currentAllJourneysProvider =
    FutureProvider<List<JourneyLibraryItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <JourneyLibraryItem>[];
  return ref.watch(
    journeyLibraryProvider(UserJourneyFilter(userId)).future,
  );
});

final routeJourneyIndexProvider =
    FutureProvider<Map<String, JourneyLibraryItem>>((ref) async {
  final items = await ref.watch(currentAllJourneysProvider.future);
  final result = <String, JourneyLibraryItem>{};
  for (final item in items) {
    final current = result[item.route.id];
    if (current == null ||
        item.journey.status == 'active' && current.journey.status != 'active') {
      result[item.route.id] = item;
    }
  }
  return result;
});

void invalidatePrivateExperience(Ref ref) {
  ref.invalidate(journeyLibraryProvider);
  ref.invalidate(journeyContextProvider);
  ref.invalidate(journeyEvidenceProvider);
  ref.invalidate(evidenceBytesProvider);
  ref.invalidate(evidencePolicyProvider);
  ref.invalidate(currentJourneyLibraryProvider);
  ref.invalidate(currentAllJourneysProvider);
  ref.invalidate(routeJourneyIndexProvider);
}

void invalidatePrivateExperienceFromWidget(WidgetRef ref) {
  ref.invalidate(journeyLibraryProvider);
  ref.invalidate(journeyContextProvider);
  ref.invalidate(journeyEvidenceProvider);
  ref.invalidate(evidenceBytesProvider);
  ref.invalidate(evidencePolicyProvider);
  ref.invalidate(currentJourneyLibraryProvider);
  ref.invalidate(currentAllJourneysProvider);
  ref.invalidate(routeJourneyIndexProvider);
}

final privateExperienceLifecycleProvider = Provider<void>((ref) {
  ref.listen(authControllerProvider, (previous, next) {
    final previousId = previous?.asData?.value?.user.id;
    final nextId = next.asData?.value?.user.id;
    if (previousId != nextId) invalidatePrivateExperience(ref);
  });
});

final routeProvider =
    FutureProvider.autoDispose.family<RouteExperience, String>((ref, slug) {
  return ref.watch(experienceRepositoryProvider).routeBySlug(slug);
});

final narrationVoicePreferenceRepositoryProvider =
    Provider<NarrationVoicePreferenceRepository>(
        (ref) => NarrationVoicePreferenceRepository());

final narrationVoicePreferenceProvider =
    FutureProvider.family<String?, NarrationVoicePreferenceKey>((ref, key) =>
        ref.watch(narrationVoicePreferenceRepositoryProvider).read(key));

final recapProvider =
    FutureProvider.family<JourneyRecap, String>((ref, journeyId) {
  return ref.watch(experienceRepositoryProvider).recap(journeyId);
});

class JourneyUiState {
  const JourneyUiState({
    this.route,
    this.session,
    this.feedback,
    this.isBusy = false,
    this.errorMessage,
  });

  final RouteExperience? route;
  final JourneySession? session;
  final AnswerFeedback? feedback;
  final bool isBusy;
  final String? errorMessage;

  JourneyUiState copyWith({
    RouteExperience? route,
    JourneySession? session,
    AnswerFeedback? feedback,
    bool clearFeedback = false,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) =>
      JourneyUiState(
        route: route ?? this.route,
        session: session ?? this.session,
        feedback: clearFeedback ? null : feedback ?? this.feedback,
        isBusy: isBusy ?? this.isBusy,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class JourneyController extends Notifier<JourneyUiState> {
  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);

  @override
  JourneyUiState build() => const JourneyUiState();

  Future<String?> start(RouteExperience route) async {
    state = JourneyUiState(route: route, isBusy: true);
    try {
      final session = await _repository.startOrResume(route.id);
      state = JourneyUiState(route: route, session: session);
      return session.id;
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _message(error));
      return null;
    }
  }

  String resume(RouteExperience route, JourneySession session) {
    state = JourneyUiState(route: route, session: session);
    return session.id;
  }

  Future<void> arrive() async {
    final session = state.session;
    if (session == null) return;
    await _perform(() async {
      final updated = await _repository.arrive(session.id);
      state = state.copyWith(session: updated, isBusy: false, clearError: true);
    });
  }

  Future<void> answer(int selectedOption) async {
    final session = state.session;
    final route = state.route;
    if (session == null || route == null) return;
    final stop = route.stops[session.currentStopPosition - 1];
    await _perform(() async {
      final feedback = await _repository.answer(
        session.id,
        stop.id,
        selectedOption,
      );
      final answered = {...session.answeredStopIds, stop.id};
      state = state.copyWith(
        session: session.copyWith(
          answeredStopIds: answered,
          progress: answered.length / route.stops.length,
        ),
        feedback: feedback,
        isBusy: false,
        clearError: true,
      );
    });
  }

  Future<bool> advance() async {
    final session = state.session;
    if (session == null) return false;
    var completed = false;
    await _perform(() async {
      final updated = await _repository.advance(session.id);
      completed = updated.isCompleted;
      state = state.copyWith(
        session: updated,
        isBusy: false,
        clearFeedback: true,
        clearError: true,
      );
      ref.invalidate(journeyLibraryProvider);
      ref.invalidate(journeyContextProvider);
    });
    return completed;
  }

  Future<void> _perform(Future<void> Function() action) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await action();
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _message(error));
    }
  }

  String _message(Object error) {
    if (error is ExperienceFailure) return error.message;
    if (error is StateError) return error.message;
    return '刚才的操作没有完成，请再试一次';
  }
}

final journeyControllerProvider =
    NotifierProvider<JourneyController, JourneyUiState>(JourneyController.new);
