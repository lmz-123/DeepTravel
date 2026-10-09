import 'dart:convert';
import 'dart:io';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';

/// Test-only content from the approved prototype; production uses its API.
Future<List<RouteExperience>> approvedRoutes({bool companion = false}) async {
  final data = jsonDecode(
          await File('test/fixtures/city_atlas/places.json').readAsString())
      as List;
  return data
      .map((p) => RouteExperience(
            id: p['id'],
            slug: p['id'],
            title: p['title'],
            subtitle: p['subtitle'],
            description: p['description'],
            durationMinutes: p['minutes'],
            distanceKm: (p['distance'] as num).toDouble(),
            difficulty: '轻松',
            theme: p['theme'],
            district: p['district'],
            citySlug: 'shenzhen',
            cityName: '深圳',
            centerLatitude: (p['coord'][1] as num).toDouble(),
            centerLongitude: (p['coord'][0] as num).toDouble(),
            heroImage:
                p['image'] == '' ? '' : 'https://fixture.test/${p['image']}',
            contentStatus: 'published',
            stops: const [],
            isFeatured: p['image'] != '',
            stopCount: (p['chapters'] as List).length,
            manualChapters: _chapters(p),
            audioTour: companion
                ? AudioTourManifest(
                    title: p['title'],
                    centralQuestion: '城市与日常',
                    scriptVersion: 'v1',
                    reviewState: 'reviewed',
                    fieldAuditState: 'reviewed',
                    productionReady: true,
                    demoLabel: '',
                    contentMethod: 'field',
                    downloadSizeBytes: 0,
                    fragments: _chapters(p))
                : null,
          ))
      .toList();
}

List<StoryFragment> _chapters(dynamic p) => [
      for (var i = 0; i < (p['chapters'] as List).length; i++)
        StoryFragment(
          id: '${p['id']}-$i',
          position: i + 1,
          title: p['chapters'][i],
          transcript: '景区故事正文。',
          safePreview: '景区故事',
          interactionType: 'passive',
          reviewState: 'reviewed',
          triggerRegion: TriggerRegion(
              latitude: (p['coord'][1] as num).toDouble(),
              longitude: (p['coord'][0] as num).toDouble(),
              entryRadiusM: 50,
              exitRadiusM: 80,
              maxAccuracyM: 35,
              qualifyingSamples: 2,
              sampleWindowSeconds: 15,
              cooldownSeconds: 120,
              auditState: 'reviewed'),
          audio: const NarrationAsset(
              url: '',
              mimeType: 'audio/mp4',
              sizeBytes: 0,
              scriptVersion: 'v1'),
        )
    ];
