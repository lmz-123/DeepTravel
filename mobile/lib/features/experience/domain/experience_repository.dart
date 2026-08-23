import 'dart:typed_data';

import 'community_models.dart';
import 'city_story.dart';
import 'fragment_models.dart';
import 'footprint_models.dart';
import 'models.dart';
import 'home_story.dart';

abstract interface class ExperienceRepository {
  Future<List<CityExperience>> cities();

  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug);

  Future<RouteExperience> featuredRoute(String citySlug);

  Future<RouteExperience> routeBySlug(String slug);

  Future<HomeStory> randomHomeStory({
    String? citySlug,
    String? excludeId,
  });

  Future<CityStoryHome> cityStoryHome(String citySlug);

  Future<HomeStory> cityStory(String catalogId);

  Future<List<TravelerFavorite>> favorites();

  Future<TravelerFavorite> addFavorite(String kind, String targetId);

  Future<void> removeFavorite(String kind, String targetId);

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

  Future<FootprintPageResult> footprints(FootprintFilter filter,
      {String? cursor});

  Future<FootprintEntry?> footprintResumeCandidate();

  Future<FootprintEntry> footprint(String footprintId);

  Future<FootprintEntry> updateFootprint(
      String footprintId, FootprintDraft draft);

  Future<List<RelatedCityContent>> footprintRelatedContent(String footprintId);

  Future<FootprintPhoto> uploadFootprintPhoto(
      String footprintId, String filePath);

  Future<Uint8List> footprintPhotoBytes(
      String footprintId, FootprintPhoto photo);

  Future<void> deleteFootprintPhoto(String footprintId);

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

  Future<CommunityPolicy> communityPolicy();

  Future<CommunityPage<CommunityPostSummary>> communityFeed(
    String journeyId,
    String fragmentId, {
    CommunityCategory? category,
    String? cursor,
    int limit = 12,
  });

  Future<CommunityPostDetail> communityPost(String postId);

  Future<CommunityPage<CommunityAuthor>> communityLikers(
    String postId, {
    String? cursor,
    int limit = 20,
  });

  Future<CommunityPage<CommunityComment>> communityComments(
    String postId, {
    String? cursor,
    int limit = 20,
  });

  Future<CommunityPostDetail> createCommunityPost(
    String journeyId,
    String fragmentId,
    CommunityPostDraft draft,
  );

  Future<CommunityPage<CommunityComment>> communityReplies(
    String rootCommentId, {
    String? cursor,
    int limit = 20,
  });

  Future<Uint8List> communityMediaBytes(CommunityMedia media);

  Future<CommunityLikeResult> setCommunityLike(String postId, bool liked);

  Future<CommunityComment> createCommunityComment(
    String postId,
    String body,
    String idempotencyKey, {
    String? replyToCommentId,
  });

  Future<void> deleteCommunityPost(String postId);

  Future<void> deleteCommunityComment(String commentId);

  Future<void> reportCommunityPost(String postId, String reason);

  Future<void> reportCommunityComment(String commentId, String reason);
}
