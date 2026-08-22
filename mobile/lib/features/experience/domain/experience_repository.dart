import 'dart:typed_data';

import 'models.dart';
import 'fragment_models.dart';

abstract interface class ExperienceRepository {
  Future<List<CityExperience>> cities();

  Future<List<RouteExperience>> routesForCity(String citySlug);

  Future<RouteExperience> featuredRoute(String citySlug);

  Future<RouteExperience> routeBySlug(String slug);

  Future<JourneySession> startOrResume(String routeId);

  Future<JourneySession> arrive(String journeyId);

  Future<AnswerFeedback> answer(
    String journeyId,
    String stopId,
    int selectedOption,
  );

  Future<JourneySession> advance(String journeyId);

  Future<JourneyRecap> recap(String journeyId);

  Future<List<JourneyLibraryItem>> journeys({String? status});

  Future<JourneyContext> journeyContext(String journeyId);

  Future<List<EvidenceRecord>> evidence(String journeyId);

  Future<Uint8List> evidenceBytes(String journeyId, EvidenceRecord evidence);

  Future<void> deleteEvidence(String journeyId, String evidenceId);

  Future<EvidencePolicy> evidencePolicy();

  Future<void> startActiveTour(String journeyId);

  Future<void> stopActiveTour(String journeyId);

  Future<StoryFragment> triggerFragment(
    String journeyId,
    String fragmentId, {
    required String method,
    required String idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracyM,
  });

  Future<StoryFragment> acknowledgePlayback(
    String journeyId,
    String fragmentId,
    double progress,
    String idempotencyKey,
  );

  Future<EvidenceRecord> uploadEvidence(
    String journeyId,
    String fragmentId,
    String filePath,
    String idempotencyKey,
  );

  Future<StoryLedger> ledger(String journeyId);

  Future<ReconstructionResult> reconstruct(
    String journeyId,
    List<String> relationships,
  );

  Future<FragmentRecap> fragmentRecap(String journeyId);
}
