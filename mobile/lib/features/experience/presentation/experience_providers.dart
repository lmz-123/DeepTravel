import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/api_experience_repository.dart';
import '../data/demo_experience_repository.dart';
import '../domain/experience_repository.dart';
import '../domain/models.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
    ),
  );
});

final experienceRepositoryProvider = Provider<ExperienceRepository>((ref) {
  if (AppConfig.mode == AppMode.api) {
    return ApiExperienceRepository(ref.watch(dioProvider));
  }
  return DemoExperienceRepository();
});

final featuredRouteProvider = FutureProvider<RouteExperience>((ref) {
  return ref.watch(experienceRepositoryProvider).featuredRoute();
});

final routeProvider =
    FutureProvider.family<RouteExperience, String>((ref, slug) {
  return ref.watch(experienceRepositoryProvider).routeBySlug(slug);
});

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
