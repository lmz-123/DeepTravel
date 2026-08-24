import 'home_story.dart';

class CityStoryHome {
  const CityStoryHome({
    required this.modules,
    required this.isEmpty,
    required this.fallbackCities,
    this.emptyReason,
  });

  final List<CityStoryModule> modules;
  final bool isEmpty;
  final String? emptyReason;
  final List<CityStoryFallbackCity> fallbackCities;

  factory CityStoryHome.fromJson(Map<String, dynamic> json) => CityStoryHome(
        modules: (json['modules'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => CityStoryModule.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false),
        isEmpty: json['empty'] as bool? ?? true,
        emptyReason: json['empty_reason'] as String?,
        fallbackCities: (json['fallback_cities'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => CityStoryFallbackCity.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false),
      );

  static const empty = CityStoryHome(
    modules: [],
    isEmpty: true,
    fallbackCities: [],
  );
}

class CityStoryModule {
  const CityStoryModule({
    required this.key,
    required this.title,
    required this.primary,
    required this.items,
  });

  final String key;
  final String title;
  final bool primary;
  final List<CityStoryCard> items;

  factory CityStoryModule.fromJson(Map<String, dynamic> json) =>
      CityStoryModule(
        key: _text(json['key']),
        title: _text(json['title']),
        primary: json['primary'] as bool? ?? false,
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => CityStoryCard.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false),
      );
}

class CityStoryCard {
  const CityStoryCard({
    required this.story,
    required this.contentType,
    required this.themes,
    required this.placeContext,
    required this.observableDetail,
    required this.factStatus,
    this.district,
    this.attentionHint,
  });

  final HomeStory story;
  final String contentType;
  final List<String> themes;
  final String placeContext;
  final String observableDetail;
  final String factStatus;
  final String? district;
  final String? attentionHint;

  factory CityStoryCard.fromJson(Map<String, dynamic> json) => CityStoryCard(
        story: HomeStory.fromJson(json),
        contentType: _text(json['content_type'], '城市故事'),
        themes: _strings(json['themes']),
        placeContext: _text(json['place_context']),
        observableDetail: _text(json['observable_detail']),
        factStatus: _text(json['fact_status']),
        district: json['district'] as String?,
        attentionHint: json['attention_hint'] as String?,
      );
}

class CityStoryFallbackCity {
  const CityStoryFallbackCity({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory CityStoryFallbackCity.fromJson(Map<String, dynamic> json) =>
      CityStoryFallbackCity(
        id: _text(json['id']),
        slug: _text(json['slug']),
        name: _text(json['name']),
      );
}

class PretripExperience {
  const PretripExperience({
    required this.available,
    required this.storyDirections,
    required this.companionTags,
    required this.tips,
    required this.offlineResources,
    required this.version,
    this.themeStory,
    this.predeparture,
  });

  final bool available;
  final CityStoryCard? themeStory;
  final PredepartureIntroduction? predeparture;
  final List<PretripStoryDirection> storyDirections;
  final List<String> companionTags;
  final PretripTips tips;
  final List<OfflineStoryResource> offlineResources;
  final int version;

  factory PretripExperience.fromJson(Map<String, dynamic> json) =>
      PretripExperience(
        available: json['available'] as bool? ?? false,
        themeStory: json['theme_story'] is Map
            ? CityStoryCard.fromJson(
                Map<String, dynamic>.from(json['theme_story'] as Map),
              )
            : null,
        predeparture: json['predeparture'] is Map
            ? PredepartureIntroduction.fromJson(
                Map<String, dynamic>.from(json['predeparture'] as Map),
              )
            : null,
        storyDirections:
            (json['story_directions'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((value) => PretripStoryDirection.fromJson(
                      Map<String, dynamic>.from(value),
                    ))
                .toList(growable: false),
        companionTags: _strings(json['companion_tags']),
        tips: PretripTips.fromJson(
          json['tips'] is Map
              ? Map<String, dynamic>.from(json['tips'] as Map)
              : const {},
        ),
        offlineResources:
            (json['offline_resources'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((value) => OfflineStoryResource.fromJson(
                      Map<String, dynamic>.from(value),
                    ))
                .toList(growable: false),
        version: _integer(json['version']),
      );
}

class PredepartureIntroduction {
  const PredepartureIntroduction({
    required this.text,
    required this.scriptVersion,
    required this.transcriptHash,
    required this.audio,
    required this.narratorName,
  });

  final String text;
  final String scriptVersion;
  final String transcriptHash;
  final PredepartureAudio audio;
  final String narratorName;

  bool get available => text.isNotEmpty && audio.url.isNotEmpty;

  factory PredepartureIntroduction.fromJson(Map<String, dynamic> json) {
    final audio = json['audio'] is Map
        ? Map<String, dynamic>.from(json['audio'] as Map)
        : const <String, dynamic>{};
    final profile = json['narration_profile'] is Map
        ? Map<String, dynamic>.from(json['narration_profile'] as Map)
        : const <String, dynamic>{};
    return PredepartureIntroduction(
      text: _text(json['text']),
      scriptVersion: _text(json['script_version']),
      transcriptHash: _text(json['transcript_hash']),
      audio: PredepartureAudio.fromJson(audio),
      narratorName: _text(profile['display_name'], '见地讲述者'),
    );
  }
}

class PredepartureAudio {
  const PredepartureAudio({
    required this.trackId,
    required this.url,
    required this.mimeType,
    required this.sizeBytes,
    required this.duration,
    this.checksumSha256,
  });

  final String trackId;
  final String url;
  final String mimeType;
  final int sizeBytes;
  final Duration duration;
  final String? checksumSha256;

  factory PredepartureAudio.fromJson(Map<String, dynamic> json) =>
      PredepartureAudio(
        trackId: _text(json['track_id']),
        url: _text(json['url']),
        mimeType: _text(json['mime_type']),
        sizeBytes: _integer(json['size_bytes']),
        duration: Duration(milliseconds: _integer(json['duration_ms'])),
        checksumSha256: json['checksum_sha256'] as String?,
      );
}

class PretripStoryDirection {
  const PretripStoryDirection({
    required this.catalogId,
    required this.title,
    required this.summary,
    required this.order,
    required this.story,
  });

  final String catalogId;
  final String title;
  final String summary;
  final int order;
  final CityStoryCard story;

  factory PretripStoryDirection.fromJson(Map<String, dynamic> json) =>
      PretripStoryDirection(
        catalogId: _text(json['catalog_id']),
        title: _text(json['title']),
        summary: _text(json['summary']),
        order: _integer(json['order']),
        story: CityStoryCard.fromJson(
          Map<String, dynamic>.from(json['story'] as Map),
        ),
      );
}

class PretripTips {
  const PretripTips({
    required this.safety,
    required this.rest,
    required this.accessibility,
    required this.weatherAdaptation,
  });

  final List<String> safety;
  final List<String> rest;
  final List<String> accessibility;
  final List<String> weatherAdaptation;

  factory PretripTips.fromJson(Map<String, dynamic> json) => PretripTips(
        safety: _strings(json['safety']),
        rest: _strings(json['rest']),
        accessibility: _strings(json['accessibility']),
        weatherAdaptation: _strings(json['weather_adaptation']),
      );
}

class OfflineStoryResource {
  const OfflineStoryResource({
    required this.id,
    required this.kind,
    required this.url,
    required this.version,
    required this.sizeBytes,
    this.checksumSha256,
  });

  final String id;
  final String kind;
  final String url;
  final String version;
  final int sizeBytes;
  final String? checksumSha256;

  factory OfflineStoryResource.fromJson(Map<String, dynamic> json) =>
      OfflineStoryResource(
        id: _text(json['id']),
        kind: _text(json['kind']),
        url: _text(json['url']),
        version: _text(json['version']),
        sizeBytes: _integer(json['size_bytes']),
        checksumSha256: json['checksum_sha256'] as String?,
      );
}

class TravelerFavorite {
  const TravelerFavorite({
    required this.kind,
    required this.targetId,
    required this.available,
    required this.label,
  });

  final String kind;
  final String targetId;
  final bool available;
  final String label;

  factory TravelerFavorite.fromJson(Map<String, dynamic> json) =>
      TravelerFavorite(
        kind: _text(json['target_kind']),
        targetId: _text(json['target_id']),
        available: json['available'] as bool? ?? false,
        label: _text(json['label'], '内容暂不可用'),
      );
}

List<String> _strings(Object? value) => value is List
    ? value
        .whereType<String>()
        .map((item) => item.trim())
        .toList(growable: false)
    : const [];

String _text(Object? value, [String fallback = '']) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

int _integer(Object? value) => value is num ? value.toInt() : 0;
