import 'dart:typed_data';

class FootprintSummaryOption {
  const FootprintSummaryOption({required this.id, required this.text});

  final String id;
  final String text;

  factory FootprintSummaryOption.fromJson(Map<String, dynamic> json) =>
      FootprintSummaryOption(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}

class FootprintPhoto {
  const FootprintPhoto({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String mimeType;
  final int width;
  final int height;
  final DateTime createdAt;

  factory FootprintPhoto.fromJson(Map<String, dynamic> json) => FootprintPhoto(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? 'image/jpeg',
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class FootprintEntry {
  const FootprintEntry({
    required this.id,
    required this.journeyId,
    required this.cityId,
    required this.citySlug,
    required this.cityName,
    required this.sceneId,
    required this.sceneTitle,
    required this.storyTitle,
    required this.editorialSummary,
    required this.summaryOptions,
    required this.themes,
    required this.organizationState,
    required this.journeyState,
    required this.createdAt,
    required this.updatedAt,
    this.selectedSummaryId,
    this.selectedSummaryText,
    this.observation,
    this.sentence,
    this.photo,
  });

  final String id;
  final String journeyId;
  final String cityId;
  final String citySlug;
  final String cityName;
  final String sceneId;
  final String sceneTitle;
  final String storyTitle;
  final String editorialSummary;
  final List<FootprintSummaryOption> summaryOptions;
  final List<String> themes;
  final String organizationState;
  final String journeyState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? selectedSummaryId;
  final String? selectedSummaryText;
  final String? observation;
  final String? sentence;
  final FootprintPhoto? photo;

  bool get needsOrganization => organizationState == 'draft';
  bool get isPartialJourney => journeyState == 'partial';

  factory FootprintEntry.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as Map<String, dynamic>? ?? const {};
    final scene = json['scene'] as Map<String, dynamic>? ?? const {};
    final narrative =
        json['jian_di_narrative'] as Map<String, dynamic>? ?? const {};
    final saw = json['what_i_saw'] as Map<String, dynamic>? ?? const {};
    final left = json['what_i_left'] as Map<String, dynamic>? ?? const {};
    final rawPhoto = saw['photo'];
    return FootprintEntry(
      id: json['id'] as String,
      journeyId: json['journey_id'] as String,
      cityId: city['id'] as String? ?? '',
      citySlug: city['slug'] as String? ?? '',
      cityName: city['name'] as String? ?? '',
      sceneId: scene['id'] as String? ?? '',
      sceneTitle: scene['title'] as String? ?? '',
      storyTitle: json['story_title'] as String? ?? '',
      editorialSummary: narrative['editorial_summary'] as String? ?? '',
      summaryOptions:
          (narrative['summary_options'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(FootprintSummaryOption.fromJson)
              .toList(growable: false),
      themes: (json['themes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      organizationState: json['organization_state'] as String? ?? 'draft',
      journeyState: json['journey_state'] as String? ?? 'partial',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      selectedSummaryId: left['selected_summary_id'] as String?,
      selectedSummaryText: left['selected_summary_text'] as String?,
      observation: saw['observation'] as String?,
      sentence: left['sentence'] as String?,
      photo: rawPhoto is Map<String, dynamic>
          ? FootprintPhoto.fromJson(rawPhoto)
          : null,
    );
  }
}

class FootprintCityFacet {
  const FootprintCityFacet({
    required this.slug,
    required this.name,
    required this.count,
  });
  final String slug;
  final String name;
  final int count;
}

class FootprintThemeFacet {
  const FootprintThemeFacet({required this.name, required this.count});
  final String name;
  final int count;
}

class FootprintTimeFacet {
  const FootprintTimeFacet({
    required this.key,
    required this.label,
    required this.count,
  });
  final String key;
  final String label;
  final int count;
}

class FootprintPageResult {
  const FootprintPageResult({
    required this.items,
    required this.cities,
    required this.themes,
    required this.months,
    required this.total,
    this.nextCursor,
  });

  final List<FootprintEntry> items;
  final List<FootprintCityFacet> cities;
  final List<FootprintThemeFacet> themes;
  final List<FootprintTimeFacet> months;
  final int total;
  final String? nextCursor;

  factory FootprintPageResult.fromJson(Map<String, dynamic> json) {
    final facets = json['facets'] as Map<String, dynamic>? ?? const {};
    return FootprintPageResult(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FootprintEntry.fromJson)
          .toList(growable: false),
      cities: (facets['cities'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => FootprintCityFacet(
                slug: item['slug'] as String? ?? '',
                name: item['name'] as String? ?? '',
                count: item['count'] as int? ?? 0,
              ))
          .toList(growable: false),
      themes: (facets['themes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => FootprintThemeFacet(
                name: item['name'] as String? ?? '',
                count: item['count'] as int? ?? 0,
              ))
          .toList(growable: false),
      months: (facets['months'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => FootprintTimeFacet(
                key: item['key'] as String? ?? '',
                label: item['label'] as String? ?? '',
                count: item['count'] as int? ?? 0,
              ))
          .toList(growable: false),
      total: json['total'] as int? ?? 0,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

class FootprintFilter {
  const FootprintFilter({
    this.citySlug,
    this.theme,
    this.journeyState,
    this.organizationState,
    this.month,
    this.order = 'recent',
  });
  final String? citySlug;
  final String? theme;
  final String? journeyState;
  final String? organizationState;
  final String? month;
  final String order;

  @override
  bool operator ==(Object other) =>
      other is FootprintFilter &&
      other.citySlug == citySlug &&
      other.theme == theme &&
      other.journeyState == journeyState &&
      other.organizationState == organizationState &&
      other.month == month &&
      other.order == order;

  @override
  int get hashCode => Object.hash(
      citySlug, theme, journeyState, organizationState, month, order);
}

class FootprintDraft {
  const FootprintDraft({
    this.selectedSummaryId,
    this.observation,
    this.sentence,
    this.deferOrganization = false,
  });
  final String? selectedSummaryId;
  final String? observation;
  final String? sentence;
  final bool deferOrganization;

  Map<String, dynamic> toJson() => {
        'selected_summary_id': selectedSummaryId,
        'user_observation': observation,
        'user_sentence': sentence,
        'defer_organization': deferOrganization,
      };
}

class RelatedCityContent {
  const RelatedCityContent({
    required this.id,
    required this.citySlug,
    required this.title,
    required this.summary,
    required this.coverImage,
    required this.themes,
    required this.contentType,
  });
  final String id;
  final String citySlug;
  final String title;
  final String summary;
  final String coverImage;
  final List<String> themes;
  final String contentType;

  factory RelatedCityContent.fromJson(Map<String, dynamic> json) =>
      RelatedCityContent(
        id: json['id'] as String,
        citySlug: json['city_slug'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        coverImage: json['cover_image'] as String? ?? '',
        themes: (json['themes'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        contentType: json['content_type'] as String? ?? '',
      );
}

class DemoFootprintPhotoBytes {
  const DemoFootprintPhotoBytes(this.photo, this.bytes);
  final FootprintPhoto photo;
  final Uint8List bytes;
}
