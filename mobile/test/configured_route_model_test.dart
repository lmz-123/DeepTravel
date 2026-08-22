import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/models.dart';

void main() {
  test('fragmented route accepts backend stops without legacy challenges', () {
    final route = RouteExperience.fromJson({
      'id': 'route-configured',
      'slug': 'configured-route',
      'title': '后台配置路线',
      'subtitle': '测试',
      'description': '测试完整内容图',
      'duration_minutes': 30,
      'distance_km': 1.2,
      'difficulty': '轻松',
      'theme': '历史',
      'hero_image': 'https://example.test/cover.png',
      'content_status': 'verified',
      'stops': [
        {
          'id': 'stop-1',
          'position': 1,
          'title': '第一站',
          'kicker': '开始',
          'address': '公共区域',
          'latitude': 22.6,
          'longitude': 114.3,
          'story_title': '第一条线索',
          'story_body': '正文',
          'image': 'https://example.test/cover.png',
          'insight': '洞见',
          'challenge': null,
        }
      ],
      'audio_tour': {
        'title': '碎片导览',
        'central_question': '这里如何改变？',
        'script_version': 'v1',
        'review_state': 'in_review',
        'field_audit_state': 'required',
        'production_ready': false,
        'demo_label': '研究预览',
        'content_method': '来源支持',
        'download_size_bytes': 0,
        'fragments': <Map<String, dynamic>>[],
      }
    });

    expect(route.audioTour, isNotNull);
    expect(route.stops.single.challenge.options, isEmpty);
  });

  test('catalog summary keeps backend featuring and stop count', () {
    final route = RouteExperience.fromJson({
      'id': 'route-summary',
      'slug': 'configured-summary',
      'title': '后台路线摘要',
      'subtitle': '测试',
      'description': '不依赖前端目的地常量',
      'duration_minutes': 42,
      'distance_km': 2.4,
      'difficulty': '轻松',
      'theme': '城市故事',
      'hero_image': 'https://example.test/cover.png',
      'content_status': 'verified',
      'is_featured': true,
      'stop_count': 5,
    });

    expect(route.isFeatured, isTrue);
    expect(route.numberOfStops, 5);
    expect(route.stops, isEmpty);
  });
}
