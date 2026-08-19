import 'models.dart';

abstract interface class ExperienceRepository {
  Future<RouteExperience> featuredRoute();

  Future<RouteExperience> routeBySlug(String slug);

  Future<JourneySession> startOrResume(String routeId);

  Future<JourneySession> arrive(String journeyId, {bool demo = true});

  Future<AnswerFeedback> answer(
    String journeyId,
    String stopId,
    int selectedOption,
  );

  Future<JourneySession> advance(String journeyId);

  Future<JourneyRecap> recap(String journeyId);
}
