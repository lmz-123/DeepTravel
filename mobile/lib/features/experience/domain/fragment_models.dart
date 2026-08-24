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
      required this.scriptVersion,
      this.checksumSha256});
  final String url;
  final String mimeType;
  final int sizeBytes;
  final String scriptVersion;
  final String? checksumSha256;

  factory NarrationAsset.fromJson(Map<String, dynamic> json) => NarrationAsset(
        url: json['url'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int? ?? 0,
        scriptVersion: json['script_version'] as String,
        checksumSha256: json['checksum_sha256'] as String?,
      );
}

class NarrationVoiceProfile {
  const NarrationVoiceProfile({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.isDefault,
    this.previewAudioUrl,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final bool isDefault;
  final String? previewAudioUrl;

  factory NarrationVoiceProfile.fromJson(Map<String, dynamic> json) =>
      NarrationVoiceProfile(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        isDefault: json['is_default'] as bool? ?? false,
        previewAudioUrl: json['preview_audio_url'] as String?,
      );
}

class NarrationTrack {
  const NarrationTrack({required this.audio, required this.transcriptHash});

  final NarrationAsset audio;
  final String transcriptHash;

  factory NarrationTrack.fromJson(Map<String, dynamic> json) => NarrationTrack(
        audio: NarrationAsset(
          url: json['audio_url'] as String,
          mimeType: json['mime_type'] as String,
          sizeBytes: json['size_bytes'] as int? ?? 0,
          scriptVersion: json['script_version'] as String,
          checksumSha256: json['checksum_sha256'] as String?,
        ),
        transcriptHash: json['transcript_hash'] as String,
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
      required this.auditState,
      this.vantagePoint = '请选择不影响通行、远离车流的安全位置。',
      this.shootingDirection = '面向任务提示中的主体，先观察周围再举起手机。',
      this.compositionTip = '保留主体与周围环境的关系，避开清晰人脸和个人信息。'});
  final String id;
  final String prompt;
  final String fieldSubject;
  final String safetyCopy;
  final String accessibilityAlternative;
  final String authenticityLabel;
  final bool required;
  final String auditState;
  final String vantagePoint;
  final String shootingDirection;
  final String compositionTip;

  factory PhotoMission.fromJson(Map<String, dynamic> json) => PhotoMission(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        fieldSubject: json['field_subject'] as String,
        safetyCopy: json['safety_copy'] as String,
        accessibilityAlternative: json['accessibility_alternative'] as String,
        authenticityLabel: json['authenticity_label'] as String,
        required: json['required'] as bool? ?? true,
        auditState: json['audit_state'] as String,
        vantagePoint:
            _nonEmptyString(json['vantage_point']) ?? '请选择不影响通行、远离车流的安全位置。',
        shootingDirection: _nonEmptyString(json['shooting_direction']) ??
            '面向任务提示中的主体，先观察周围再举起手机。',
        compositionTip: _nonEmptyString(json['composition_tip']) ??
            '保留主体与周围环境的关系，避开清晰人脸和个人信息。',
      );
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
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
    this.narrationTracks = const {},
    this.experienceTags = const [],
    this.displayTheme,
    this.expectedDurationSeconds,
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
  final Map<String, NarrationTrack> narrationTracks;
  final List<String> experienceTags;
  final String? displayTheme;
  final int? expectedDurationSeconds;

  bool get isCollected => state == 'collected';
  bool get isMissionPending => state == 'mission_pending';
  bool get isRevealed => title != null;

  NarrationAsset narrationFor(String? profileId) =>
      narrationTracks[profileId]?.audio ?? audio;

  StoryFragment withNarrationProfile(String? profileId) => StoryFragment(
        id: id,
        position: position,
        safePreview: safePreview,
        interactionType: interactionType,
        reviewState: reviewState,
        triggerRegion: triggerRegion,
        audio: narrationFor(profileId),
        title: title,
        transcript: transcript,
        keyClaim: keyClaim,
        answersQuestion: answersQuestion,
        raisesQuestion: raisesQuestion,
        authenticityLabel: authenticityLabel,
        state: state,
        playbackProgress: playbackProgress,
        mission: mission,
        evidenceId: evidenceId,
        sources: sources,
        dependencyIds: dependencyIds,
        narrationTracks: narrationTracks,
        experienceTags: experienceTags,
        displayTheme: displayTheme,
        expectedDurationSeconds: expectedDurationSeconds,
      );

  StoryFragment asUndiscovered() => StoryFragment(
        id: id,
        position: position,
        safePreview: safePreview,
        interactionType: interactionType,
        reviewState: reviewState,
        triggerRegion: triggerRegion,
        audio: audio,
        state: 'undiscovered',
        mission: mission,
        sources: sources,
        dependencyIds: dependencyIds,
        narrationTracks: narrationTracks,
        experienceTags: experienceTags,
        displayTheme: displayTheme,
        expectedDurationSeconds: expectedDurationSeconds,
      );

  StoryFragment withOfflineState({
    required String state,
    double? playbackProgress,
    String? evidenceId,
  }) =>
      StoryFragment(
        id: id,
        position: position,
        safePreview: safePreview,
        interactionType: interactionType,
        reviewState: reviewState,
        triggerRegion: triggerRegion,
        audio: audio,
        title: title,
        transcript: transcript,
        keyClaim: keyClaim,
        answersQuestion: answersQuestion,
        raisesQuestion: raisesQuestion,
        authenticityLabel: authenticityLabel,
        state: state,
        playbackProgress: playbackProgress ?? this.playbackProgress,
        mission: mission,
        evidenceId: evidenceId ?? this.evidenceId,
        sources: sources,
        dependencyIds: dependencyIds,
        narrationTracks: narrationTracks,
        experienceTags: experienceTags,
        displayTheme: displayTheme,
        expectedDurationSeconds: expectedDurationSeconds,
      );

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
      narrationTracks: (json['narration_tracks'] as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .map((key, value) => MapEntry(
              key, NarrationTrack.fromJson(value as Map<String, dynamic>))),
      experienceTags: List<String>.from(
          json['experience_tags'] as List<dynamic>? ?? const []),
      displayTheme: _nonEmptyString(json['display_theme']),
      expectedDurationSeconds:
          (json['expected_duration_seconds'] as num?)?.round(),
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
      required this.fragments,
      this.defaultNarrationProfileId,
      this.narrationProfiles = const []});
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
  final String? defaultNarrationProfileId;
  final List<NarrationVoiceProfile> narrationProfiles;

  NarrationVoiceProfile? profile(String? id) {
    for (final profile in narrationProfiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  String? effectiveProfileId(String? preferredId) =>
      profile(preferredId)?.id ??
      profile(defaultNarrationProfileId)?.id ??
      (narrationProfiles.isEmpty ? null : narrationProfiles.first.id);

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
        defaultNarrationProfileId:
            json['default_narration_profile_id'] as String?,
        narrationProfiles: (json['narration_profiles'] as List<dynamic>? ??
                const [])
            .map((value) =>
                NarrationVoiceProfile.fromJson(value as Map<String, dynamic>))
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
      this.reconstructionItems = const [],
      this.defaultNarrationProfileId,
      this.narrationProfiles = const []});
  final String centralQuestion;
  final int collectedCount;
  final int totalCount;
  final bool reconstructionUnlocked;
  final List<StoryFragment> entries;
  final List<ReconstructionItem> reconstructionItems;
  final String? defaultNarrationProfileId;
  final List<NarrationVoiceProfile> narrationProfiles;

  bool get reconstructionCompleted =>
      entries.isNotEmpty &&
      entries.every((entry) => entry.state == 'reconstructed');

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
        defaultNarrationProfileId:
            json['default_narration_profile_id'] as String?,
        narrationProfiles: (json['narration_profiles'] as List<dynamic>? ??
                const [])
            .map((value) =>
                NarrationVoiceProfile.fromJson(value as Map<String, dynamic>))
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
  const EvidenceRecord({
    required this.id,
    required this.url,
    this.journeyId,
    this.fragmentId,
    this.missionId,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.capturedAt,
    this.uploadedAt,
    this.expiresAt,
    this.isExpired = false,
  });

  final String id;
  final String url;
  final String? journeyId;
  final String? fragmentId;
  final String? missionId;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final DateTime? capturedAt;
  final DateTime? uploadedAt;
  final DateTime? expiresAt;
  final bool isExpired;

  factory EvidenceRecord.fromJson(Map<String, dynamic> json) => EvidenceRecord(
        id: json['id'] as String,
        url: json['url'] as String,
        journeyId: json['journey_id'] as String?,
        fragmentId: json['fragment_id'] as String?,
        missionId: json['mission_id'] as String?,
        mimeType: json['mime_type'] as String?,
        sizeBytes: json['size_bytes'] as int?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        capturedAt: _dateTime(json['captured_at']),
        uploadedAt: _dateTime(json['uploaded_at']),
        expiresAt: _dateTime(json['expires_at']),
        isExpired: json['is_expired'] as bool? ?? false,
      );
}

DateTime? _dateTime(Object? value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

class EvidencePolicy {
  const EvidencePolicy({
    required this.uploadEnabled,
    required this.retentionDays,
    required this.maxBytes,
    required this.maxEdgePixels,
    required this.allowedMimeTypes,
    required this.privateAccess,
    required this.exifRemoved,
    required this.normalizedOnUpload,
  });

  final bool uploadEnabled;
  final int retentionDays;
  final int maxBytes;
  final int maxEdgePixels;
  final List<String> allowedMimeTypes;
  final bool privateAccess;
  final bool exifRemoved;
  final bool normalizedOnUpload;

  factory EvidencePolicy.fromJson(Map<String, dynamic> json) => EvidencePolicy(
        uploadEnabled: json['upload_enabled'] as bool,
        retentionDays: json['retention_days'] as int,
        maxBytes: json['max_bytes'] as int,
        maxEdgePixels: json['max_edge_pixels'] as int,
        allowedMimeTypes: List<String>.from(json['allowed_mime_types'] as List),
        privateAccess: json['private_access'] as bool,
        exifRemoved: json['exif_removed'] as bool,
        normalizedOnUpload: json['normalized_on_upload'] as bool,
      );
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
