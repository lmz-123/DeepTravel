import 'fragment_models.dart';

class CityExperience {
  const CityExperience({
    required this.id,
    required this.slug,
    required this.name,
    required this.subtitle,
    required this.heroImage,
  });

  final String id;
  final String slug;
  final String name;
  final String subtitle;
  final String heroImage;

  factory CityExperience.fromJson(Map<String, dynamic> json) => CityExperience(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        subtitle: json['subtitle'] as String,
        heroImage: json['hero_image'] as String,
      );
}

class Challenge {
  const Challenge({
    required this.id,
    required this.prompt,
    required this.hint,
    required this.options,
    this.correctOption,
  });

  final String id;
  final String prompt;
  final String hint;
  final List<String> options;
  final int? correctOption;

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        hint: json['hint'] as String,
        options: List<String>.from(json['options'] as List),
      );
}

class ExperienceStop {
  const ExperienceStop({
    required this.id,
    required this.position,
    required this.title,
    required this.kicker,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.storyTitle,
    required this.storyBody,
    required this.image,
    required this.insight,
    required this.challenge,
  });

  final String id;
  final int position;
  final String title;
  final String kicker;
  final String address;
  final double latitude;
  final double longitude;
  final String storyTitle;
  final String storyBody;
  final String image;
  final String insight;
  final Challenge challenge;

  factory ExperienceStop.fromJson(Map<String, dynamic> json) => ExperienceStop(
        id: json['id'] as String,
        position: json['position'] as int,
        title: json['title'] as String,
        kicker: json['kicker'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        storyTitle: json['story_title'] as String,
        storyBody: json['story_body'] as String,
        image: json['image'] as String,
        insight: json['insight'] as String,
        challenge: json['challenge'] is Map<String, dynamic>
            ? Challenge.fromJson(json['challenge'] as Map<String, dynamic>)
            : const Challenge(id: '', prompt: '', hint: '', options: []),
      );
}

class RouteExperience {
  const RouteExperience({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.durationMinutes,
    required this.distanceKm,
    required this.difficulty,
    required this.theme,
    required this.heroImage,
    required this.contentStatus,
    required this.stops,
    this.isFeatured = false,
    this.stopCount,
    this.audioTour,
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final int durationMinutes;
  final double distanceKm;
  final String difficulty;
  final String theme;
  final String heroImage;
  final String contentStatus;
  final List<ExperienceStop> stops;
  final bool isFeatured;
  final int? stopCount;
  final AudioTourManifest? audioTour;

  bool get isVerified => contentStatus == 'verified';
  int get numberOfStops =>
      stopCount ?? audioTour?.fragments.length ?? stops.length;

  factory RouteExperience.fromJson(Map<String, dynamic> json) =>
      RouteExperience(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        description: json['description'] as String,
        durationMinutes: json['duration_minutes'] as int,
        distanceKm: (json['distance_km'] as num).toDouble(),
        difficulty: json['difficulty'] as String,
        theme: json['theme'] as String,
        heroImage: json['hero_image'] as String,
        contentStatus: json['content_status'] as String,
        isFeatured: json['is_featured'] as bool? ?? false,
        stopCount: json['stop_count'] as int?,
        stops: (json['stops'] as List<dynamic>? ?? const [])
            .map(
                (item) => ExperienceStop.fromJson(item as Map<String, dynamic>))
            .toList(),
        audioTour: json['audio_tour'] is Map<String, dynamic>
            ? AudioTourManifest.fromJson(
                json['audio_tour'] as Map<String, dynamic>,
              )
            : null,
      );
}

class JourneySession {
  const JourneySession({
    required this.id,
    required this.routeId,
    required this.status,
    required this.currentStopPosition,
    required this.arrivedStopId,
    required this.answeredStopIds,
    required this.progress,
  });

  final String id;
  final String routeId;
  final String status;
  final int currentStopPosition;
  final String? arrivedStopId;
  final Set<String> answeredStopIds;
  final double progress;

  bool get isCompleted => status == 'completed';

  JourneySession copyWith({
    String? status,
    int? currentStopPosition,
    String? arrivedStopId,
    bool clearArrival = false,
    Set<String>? answeredStopIds,
    double? progress,
  }) =>
      JourneySession(
        id: id,
        routeId: routeId,
        status: status ?? this.status,
        currentStopPosition: currentStopPosition ?? this.currentStopPosition,
        arrivedStopId:
            clearArrival ? null : arrivedStopId ?? this.arrivedStopId,
        answeredStopIds: answeredStopIds ?? this.answeredStopIds,
        progress: progress ?? this.progress,
      );

  factory JourneySession.fromJson(Map<String, dynamic> json) => JourneySession(
        id: json['id'] as String,
        routeId: json['route_id'] as String,
        status: json['status'] as String,
        currentStopPosition: json['current_stop_position'] as int,
        arrivedStopId: json['arrived_stop_id'] as String?,
        answeredStopIds: Set<String>.from(json['answered_stop_ids'] as List),
        progress: (json['progress'] as num).toDouble(),
      );
}

class AnswerFeedback {
  const AnswerFeedback({
    required this.stopId,
    required this.selectedOption,
    required this.isCorrect,
    required this.explanation,
    required this.insight,
  });

  final String stopId;
  final int selectedOption;
  final bool isCorrect;
  final String explanation;
  final String insight;

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) => AnswerFeedback(
        stopId: json['stop_id'] as String,
        selectedOption: json['selected_option'] as int,
        isCorrect: json['is_correct'] as bool,
        explanation: json['explanation'] as String,
        insight: json['insight'] as String,
      );
}

class JourneyRecap {
  const JourneyRecap({required this.route, required this.insights});

  final RouteExperience route;
  final List<RecapInsight> insights;
}

class RecapInsight {
  const RecapInsight({
    required this.stopId,
    required this.title,
    required this.insight,
    required this.isCorrect,
  });

  final String stopId;
  final String title;
  final String insight;
  final bool isCorrect;
}
