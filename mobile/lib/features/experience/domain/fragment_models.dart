class TriggerRegion {
  const TriggerRegion({
    required this.latitude,
    required this.longitude,
    required this.entryRadiusM,
    required this.exitRadiusM,
    required this.maxAccuracyM,
    required this.qualifyingSamples,
    required this.sampleWindowSeconds,
    required this.cooldownSeconds,
    required this.auditState,
  });

  final double latitude;
  final double longitude;
  final int entryRadiusM;
  final int exitRadiusM;
  final int maxAccuracyM;
  final int qualifyingSamples;
  final int sampleWindowSeconds;
  final int cooldownSeconds;
  final String auditState;

  factory TriggerRegion.fromJson(Map<String, dynamic> json) => TriggerRegion(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        entryRadiusM: json['entry_radius_m'] as int,
        exitRadiusM: json['exit_radius_m'] as int,
        maxAccuracyM: json['max_accuracy_m'] as int,
        qualifyingSamples: json['qualifying_samples'] as int,
        sampleWindowSeconds: json['sample_window_seconds'] as int,
        cooldownSeconds: json['cooldown_seconds'] as int,
        auditState: json['audit_state'] as String,
      );
}

class NarrationAsset {
  const NarrationAsset(
      {required this.url,
      required this.mimeType,
      required this.sizeBytes,
      required this.scriptVersion});
  final String url;
  final String mimeType;
  final int sizeBytes;
  final String scriptVersion;

  factory NarrationAsset.fromJson(Map<String, dynamic> json) => NarrationAsset(
        url: json['url'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int? ?? 0,
        scriptVersion: json['script_version'] as String,
      );
}

class PhotoMission {
  const PhotoMission(
      {required this.id,
      required this.prompt,
      required this.fieldSubject,
      required this.safetyCopy,
      required this.accessibilityAlternative,
      required this.authenticityLabel,
      required this.required,
      required this.auditState});
  final String id;
  final String prompt;
  final String fieldSubject;
  final String safetyCopy;
  final String accessibilityAlternative;
  final String authenticityLabel;
  final bool required;
  final String auditState;

  factory PhotoMission.fromJson(Map<String, dynamic> json) => PhotoMission(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        fieldSubject: json['field_subject'] as String,
        safetyCopy: json['safety_copy'] as String,
        accessibilityAlternative: json['accessibility_alternative'] as String,
        authenticityLabel: json['authenticity_label'] as String,
        required: json['required'] as bool? ?? true,
        auditState: json['audit_state'] as String,
      );
}

class HistoricalSource {
  const HistoricalSource(
      {required this.title,
      required this.publisher,
      required this.url,
      required this.summary,
      required this.reviewState});
  final String title;
  final String publisher;
  final String url;
  final String summary;
  final String reviewState;

  factory HistoricalSource.fromJson(Map<String, dynamic> json) =>
      HistoricalSource(
        title: json['title'] as String,
        publisher: json['publisher'] as String,
        url: json['url'] as String,
        summary: json['summary'] as String,
        reviewState: json['review_state'] as String,
      );
}

class StoryFragment {
  const StoryFragment({
    required this.id,
    required this.position,
    required this.safePreview,
    required this.interactionType,
    required this.reviewState,
    required this.triggerRegion,
    required this.audio,
    this.title,
    this.transcript,
    this.keyClaim,
    this.answersQuestion,
    this.raisesQuestion,
    this.authenticityLabel,
    this.state = 'undiscovered',
    this.playbackProgress = 0,
    this.mission,
    this.evidenceId,
    this.sources = const [],
    this.dependencyIds = const [],
  });

  final String id;
  final int position;
  final String safePreview;
  final String interactionType;
  final String reviewState;
  final TriggerRegion triggerRegion;
  final NarrationAsset audio;
  final String? title;
  final String? transcript;
  final String? keyClaim;
  final String? answersQuestion;
  final String? raisesQuestion;
  final String? authenticityLabel;
  final String state;
  final double playbackProgress;
  final PhotoMission? mission;
  final String? evidenceId;
  final List<HistoricalSource> sources;
  final List<String> dependencyIds;

  bool get isCollected => state == 'collected';
  bool get isMissionPending => state == 'mission_pending';
  bool get isRevealed => title != null;

  factory StoryFragment.fromJson(Map<String, dynamic> json) {
    final missionJson = json['mission'];
    return StoryFragment(
      id: json['id'] as String,
      position: json['position'] as int,
      safePreview: json['safe_preview'] as String,
      interactionType: json['interaction_type'] as String,
      reviewState: json['review_state'] as String,
      triggerRegion: TriggerRegion.fromJson(
          json['trigger_region'] as Map<String, dynamic>),
      audio: NarrationAsset.fromJson(json['audio'] as Map<String, dynamic>),
      title: json['title'] as String?,
      transcript: json['transcript'] as String?,
      keyClaim: json['key_claim'] as String?,
      answersQuestion: json['answers_question'] as String?,
      raisesQuestion: json['raises_question'] as String?,
      authenticityLabel: json['authenticity_label'] as String?,
      state: json['state'] as String? ?? 'undiscovered',
      playbackProgress: (json['playback_progress'] as num?)?.toDouble() ?? 0,
      mission: missionJson is Map<String, dynamic>
          ? PhotoMission.fromJson(missionJson)
          : null,
      evidenceId: json['evidence_id'] as String?,
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((value) =>
              HistoricalSource.fromJson(value as Map<String, dynamic>))
          .toList(),
      dependencyIds: List<String>.from(
          json['dependency_ids'] as List<dynamic>? ?? const []),
    );
  }
}

class AudioTourManifest {
  const AudioTourManifest(
      {required this.title,
      required this.centralQuestion,
      required this.scriptVersion,
      required this.reviewState,
      required this.fieldAuditState,
      required this.productionReady,
      required this.demoLabel,
      required this.contentMethod,
      required this.downloadSizeBytes,
      required this.fragments});
  final String title;
  final String centralQuestion;
  final String scriptVersion;
  final String reviewState;
  final String fieldAuditState;
  final bool productionReady;
  final String? demoLabel;
  final String contentMethod;
  final int downloadSizeBytes;
  final List<StoryFragment> fragments;

  int get photoMissionCount =>
      fragments.where((value) => value.interactionType == 'photo').length;

  factory AudioTourManifest.fromJson(Map<String, dynamic> json) =>
      AudioTourManifest(
        title: json['title'] as String,
        centralQuestion: json['central_question'] as String,
        scriptVersion: json['script_version'] as String,
        reviewState: json['review_state'] as String,
        fieldAuditState: json['field_audit_state'] as String,
        productionReady: json['production_ready'] as bool,
        demoLabel: json['demo_label'] as String?,
        contentMethod: json['content_method'] as String,
        downloadSizeBytes: json['download_size_bytes'] as int? ?? 0,
        fragments: (json['fragments'] as List<dynamic>)
            .map((value) =>
                StoryFragment.fromJson(value as Map<String, dynamic>))
            .toList(),
      );
}

class StoryLedger {
  const StoryLedger(
      {required this.centralQuestion,
      required this.collectedCount,
      required this.totalCount,
      required this.reconstructionUnlocked,
      required this.entries,
      this.reconstructionItems = const []});
  final String centralQuestion;
  final int collectedCount;
  final int totalCount;
  final bool reconstructionUnlocked;
  final List<StoryFragment> entries;
  final List<ReconstructionItem> reconstructionItems;

  factory StoryLedger.fromJson(Map<String, dynamic> json) => StoryLedger(
        centralQuestion: json['central_question'] as String,
        collectedCount: json['collected_count'] as int,
        totalCount: json['total_count'] as int,
        reconstructionUnlocked: json['reconstruction_unlocked'] as bool,
        reconstructionItems:
            (json['reconstruction_items'] as List<dynamic>? ?? const [])
                .map((value) =>
                    ReconstructionItem.fromJson(value as Map<String, dynamic>))
                .toList(),
        entries: (json['entries'] as List<dynamic>)
            .map((value) =>
                StoryFragment.fromJson(value as Map<String, dynamic>))
            .toList(),
      );
}

class ReconstructionItem {
  const ReconstructionItem({required this.id, required this.text});
  final String id;
  final String text;

  factory ReconstructionItem.fromJson(Map<String, dynamic> json) =>
      ReconstructionItem(
          id: json['id'] as String, text: json['text'] as String);
}

class EvidenceRecord {
  const EvidenceRecord({required this.id, required this.url});
  final String id;
  final String url;
  factory EvidenceRecord.fromJson(Map<String, dynamic> json) =>
      EvidenceRecord(id: json['id'] as String, url: json['url'] as String);
}

class ReconstructionResult {
  const ReconstructionResult(
      {required this.correct,
      required this.feedback,
      required this.completeStoryUnlocked});
  final bool correct;
  final List<Map<String, dynamic>> feedback;
  final bool completeStoryUnlocked;
  factory ReconstructionResult.fromJson(Map<String, dynamic> json) =>
      ReconstructionResult(
          correct: json['correct'] as bool,
          feedback:
              (json['feedback'] as List<dynamic>).cast<Map<String, dynamic>>(),
          completeStoryUnlocked: json['complete_story_unlocked'] as bool);
}

class FragmentRecap {
  const FragmentRecap(
      {required this.title,
      required this.centralQuestion,
      required this.completeStory,
      required this.causalModel,
      required this.fragments});
  final String title;
  final String centralQuestion;
  final String completeStory;
  final List<String> causalModel;
  final List<StoryFragment> fragments;
  factory FragmentRecap.fromJson(Map<String, dynamic> json) => FragmentRecap(
      title: json['title'] as String,
      centralQuestion: json['central_question'] as String,
      completeStory: json['complete_story'] as String,
      causalModel: List<String>.from(json['causal_model'] as List),
      fragments: (json['fragments'] as List<dynamic>)
          .map((value) => StoryFragment.fromJson(value as Map<String, dynamic>))
          .toList());
}
