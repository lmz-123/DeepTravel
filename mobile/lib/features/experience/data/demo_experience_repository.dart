import '../domain/experience_repository.dart';
import '../domain/models.dart';
import 'demo_content.dart';

class DemoExperienceRepository implements ExperienceRepository {
  DemoExperienceRepository({this.latency = const Duration(milliseconds: 180)});

  final Duration latency;
  JourneySession? _journey;
  final Map<String, AnswerFeedback> _answers = {};

  Future<void> _pause() => Future<void>.delayed(latency);

  @override
  Future<RouteExperience> featuredRoute() async {
    await _pause();
    return demoRoute;
  }

  @override
  Future<RouteExperience> routeBySlug(String slug) async {
    await _pause();
    if (slug != demoRoute.slug) throw StateError('路线不存在');
    return demoRoute;
  }

  @override
  Future<JourneySession> startOrResume(String routeId) async {
    await _pause();
    if (_journey != null && !_journey!.isCompleted) return _journey!;
    _answers.clear();
    _journey = JourneySession(
      id: 'demo-journey',
      routeId: routeId,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
    );
    return _journey!;
  }

  @override
  Future<JourneySession> arrive(String journeyId, {bool demo = true}) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    final stop = demoRoute.stops[journey.currentStopPosition - 1];
    _journey = journey.copyWith(arrivedStopId: stop.id);
    return _journey!;
  }

  @override
  Future<AnswerFeedback> answer(
    String journeyId,
    String stopId,
    int selectedOption,
  ) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    if (_answers.containsKey(stopId)) return _answers[stopId]!;
    final stop = demoRoute.stops.firstWhere((item) => item.id == stopId);
    if (journey.arrivedStopId != stopId) throw StateError('请先到达站点');
    final isCorrect = selectedOption == stop.challenge.correctOption;
    final feedback = AnswerFeedback(
      stopId: stopId,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      explanation: isCorrect
          ? '你观察到了关键线索。地点的形态，往往比一串年代更容易被记住。'
          : '再看一眼现场关系。重要的不是猜中，而是发现刚才忽略的细节。',
      insight: stop.insight,
    );
    _answers[stopId] = feedback;
    final answered = {...journey.answeredStopIds, stopId};
    _journey = journey.copyWith(
      answeredStopIds: answered,
      progress: answered.length / demoRoute.stops.length,
    );
    return feedback;
  }

  @override
  Future<JourneySession> advance(String journeyId) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    final stop = demoRoute.stops[journey.currentStopPosition - 1];
    if (!journey.answeredStopIds.contains(stop.id)) throw StateError('请先完成观察');
    if (journey.currentStopPosition == demoRoute.stops.length) {
      _journey = journey.copyWith(
        status: 'completed',
        clearArrival: true,
        progress: 1,
      );
    } else {
      _journey = journey.copyWith(
        currentStopPosition: journey.currentStopPosition + 1,
        clearArrival: true,
      );
    }
    return _journey!;
  }

  @override
  Future<JourneyRecap> recap(String journeyId) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    if (!journey.isCompleted) throw StateError('旅程尚未完成');
    return JourneyRecap(
      route: demoRoute,
      insights: demoRoute.stops.map((stop) {
        final answer = _answers[stop.id]!;
        return RecapInsight(
          stopId: stop.id,
          title: stop.title,
          insight: stop.insight,
          isCorrect: answer.isCorrect,
        );
      }).toList(),
    );
  }

  JourneySession _requireJourney(String journeyId) {
    if (_journey == null || _journey!.id != journeyId) {
      throw StateError('旅程不存在');
    }
    return _journey!;
  }
}
