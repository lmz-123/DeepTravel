import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
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
      'content_status': 'published',
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
      'content_status': 'published',
      'is_featured': true,
      'stop_count': 5,
    });

    expect(route.isFeatured, isTrue);
    expect(route.numberOfStops, 5);
    expect(route.stops, isEmpty);
  });

  test('photo mission parses shooting guidance and supplies legacy fallbacks',
      () {
    final guided = PhotoMission.fromJson({
      'id': 'mission-1',
      'prompt': '拍下入口',
      'field_subject': '入口',
      'safety_copy': '留在人行道内',
      'accessibility_alternative': '口述观察',
      'authenticity_label': '现场照片',
      'required': false,
      'audit_state': 'reviewed',
      'vantage_point': '站在树下的宽阔区域',
      'shooting_direction': '朝向牌楼',
      'composition_tip': '牌楼居中并保留街巷',
    });
    final legacy = PhotoMission.fromJson({
      'id': 'mission-old',
      'prompt': '旧任务',
      'field_subject': '旧主体',
      'safety_copy': '注意安全',
      'accessibility_alternative': '跳过',
      'authenticity_label': '旧内容',
      'required': false,
      'audit_state': 'legacy',
    });

    expect(guided.vantagePoint, '站在树下的宽阔区域');
    expect(guided.shootingDirection, '朝向牌楼');
    expect(guided.compositionTip, '牌楼居中并保留街巷');
    expect(legacy.vantagePoint, isNotEmpty);
    expect(legacy.shootingDirection, isNotEmpty);
    expect(legacy.compositionTip, isNotEmpty);
  });
}
