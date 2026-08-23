class HomeStory {
  const HomeStory({
    required this.id,
    required this.arcId,
    required this.title,
    required this.introduction,
    required this.coverImage,
    required this.duration,
    required this.transcript,
    required this.audioUrl,
    required this.cityName,
    required this.citySlug,
    required this.routeTitle,
    required this.routeSlug,
    required this.narratorName,
    this.contentType = '城市故事',
    this.themes = const [],
    this.placeContext = '',
    this.observableDetail = '',
    this.attentionHint,
    this.factStatus = '',
  });

  final String id;
  final String arcId;
  final String title;
  final String introduction;
  final String coverImage;
  final Duration duration;
  final String transcript;
  final String audioUrl;
  final String cityName;
  final String citySlug;
  final String routeTitle;
  final String routeSlug;
  final String narratorName;
  final String contentType;
  final List<String> themes;
  final String placeContext;
  final String observableDetail;
  final String? attentionHint;
  final String factStatus;

  factory HomeStory.fromJson(Map<String, dynamic> json) {
    final city = _storyMap(json['city']);
    final route = _storyMap(json['route']);
    final profile = _storyMap(json['narration_profile']);
    return HomeStory(
      id: _storyText(json['id']),
      arcId: _storyText(json['arc_id']),
      title: _storyText(json['title']),
      introduction: _storyText(json['introduction']),
      coverImage: _storyText(json['cover_image_url']),
      duration: Duration(milliseconds: _storyInt(json['duration_ms'])),
      transcript: _storyText(json['transcript']),
      audioUrl: _storyText(json['audio_url']),
      cityName: _storyText(city['name']),
      citySlug: _storyText(city['slug']),
      routeTitle: _storyText(route['title']),
      routeSlug: _storyText(route['slug']),
      narratorName: _storyText(profile['display_name'], '见地讲述者'),
      contentType: _storyText(json['content_type'], '城市故事'),
      themes: (json['themes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      placeContext: _storyText(json['place_context']),
      observableDetail: _storyText(json['observable_detail']),
      attentionHint: json['attention_hint'] as String?,
      factStatus: _storyText(json['fact_status']),
    );
  }
}

Map<String, dynamic> _storyMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _storyText(Object? value, [String fallback = '']) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

int _storyInt(Object? value) => value is num ? value.toInt() : 0;
