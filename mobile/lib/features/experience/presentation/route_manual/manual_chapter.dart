import '../../domain/fragment_models.dart';
import '../../domain/models.dart';

/// Reading a chapter is deliberately independent of an on-site journey.
class ManualChapter {
  const ManualChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.place,
    required this.body,
    required this.image,
    this.fragment,
    this.duration = Duration.zero,
  });

  final String id;
  final int number;
  final String title;
  final String place;
  final String body;
  final String image;
  final StoryFragment? fragment;
  final Duration duration;
  bool get hasAudio => fragment?.audio.url.isNotEmpty ?? false;
  String get folio => number.toString().padLeft(2, '0');
  String get durationLabel => hasAudio ? manualTime(duration) : '文字';
}

List<ManualChapter> routeManualChapters(RouteExperience route) {
  final fragments = [
    ...(route.manualChapters.isNotEmpty
        ? route.manualChapters
        : route.audioTour?.fragments.where(
              (item) =>
                  item.title != null && (item.transcript?.isNotEmpty ?? false),
            ) ??
            const <StoryFragment>[]),
  ]..sort((a, b) => a.position.compareTo(b.position));
  if (fragments.isNotEmpty) {
    return fragments.map((fragment) {
      final stop = route.stops
          .where((stop) => stop.position == fragment.position)
          .firstOrNull;
      return ManualChapter(
        id: fragment.id,
        number: fragment.position,
        title: fragment.title ?? stop?.storyTitle ?? fragment.safePreview,
        place: stop?.title ?? route.title,
        body: fragment.transcript ?? stop?.storyBody ?? fragment.safePreview,
        image:
            (stop?.image.isNotEmpty ?? false) ? stop!.image : route.heroImage,
        fragment: fragment,
        duration: Duration(seconds: fragment.expectedDurationSeconds ?? 0),
      );
    }).toList(growable: false);
  }
  return ([...route.stops]..sort((a, b) => a.position.compareTo(b.position)))
      .map(
        (stop) => ManualChapter(
          id: stop.id,
          number: stop.position,
          title: stop.storyTitle,
          place: stop.title,
          body: stop.storyBody,
          image: stop.image.isEmpty ? route.heroImage : stop.image,
        ),
      )
      .toList(growable: false);
}

String manualTime(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

enum ManualChapterMode { audio, text, directory }

class ManualChapterChoice {
  const ManualChapterChoice(this.chapter, this.mode);
  final ManualChapter chapter;
  final ManualChapterMode mode;
}
