import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';

void main() {
  test('demo repository completes all five stops', () async {
    final repository = DemoExperienceRepository(latency: Duration.zero);
    final route = await repository.featuredRoute();
    var journey = await repository.startOrResume(route.id);

    for (final stop in route.stops) {
      journey = await repository.arrive(
        journey.id,
        latitude: 31.19967,
        longitude: 121.43876,
      );
      expect(journey.arrivedStopId, stop.id);
      final answer = await repository.answer(
        journey.id,
        stop.id,
        stop.challenge.correctOption!,
      );
      expect(answer.isCorrect, isTrue);
      journey = await repository.advance(journey.id);
    }

    expect(journey.isCompleted, isTrue);
    final recap = await repository.recap(journey.id);
    expect(recap.insights, hasLength(5));
  });

  test('starting the same route resumes active progress', () async {
    final repository = DemoExperienceRepository(latency: Duration.zero);
    final route = await repository.featuredRoute();
    final first = await repository.startOrResume(route.id);
    final resumed = await repository.startOrResume(route.id);
    expect(resumed.id, first.id);
  });
}
