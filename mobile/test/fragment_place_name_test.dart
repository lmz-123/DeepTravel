import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';

void main() {
  test('public location is independent of story disclosure', () {
    final locked = StoryFragment.fromJson(_fragmentJson());
    expect(locked.publicPlaceName, '南头古城南门');
    expect(locked.stopId, 'stop-a');
    expect(locked.title, isNull);
    expect(locked.transcript, isNull);

    final revealed = StoryFragment.fromJson({
      ..._fragmentJson(),
      'title': '城市为何拥有两个起点',
      'transcript': '尚未到达时不可展示的故事正文',
    });
    expect(revealed.publicPlaceName, locked.publicPlaceName);
  });

  test('voice and offline state changes retain the public place', () {
    final fragment = StoryFragment.fromJson({
      ..._fragmentJson(),
      'title': '城市为何拥有两个起点',
      'transcript': '尚未到达时不可展示的故事正文',
    });
    final updated = fragment
        .withNarrationProfile(null)
        .withOfflineState(state: 'collected', playbackProgress: 1);
    expect(updated.publicPlaceName, '南头古城南门');
    expect(updated.stopId, 'stop-a');
    final locked = updated.asUndiscovered();
    expect(locked.publicPlaceName, '南头古城南门');
    expect(locked.stopId, 'stop-a');
    expect(locked.title, isNull);
    expect(locked.transcript, isNull);
  });

  test('older manifests can use an already public short place preview', () {
    final json = _fragmentJson()
      ..remove('place_name')
      ..remove('stop_id')
      ..['safe_preview'] = '  中山公园  '
      ..['title'] = '不得作为地点展示的标题';
    final fragment = StoryFragment.fromJson(json);
    expect(fragment.publicPlaceName, '中山公园');
    expect(fragment.stopId, isNull);
  });

  test('missing places do not fall back to locked or revealed story titles',
      () {
    for (final preview in [
      '',
      '第一条线索',
      '尚未发现',
      '走到这里，看看城市的前世今生。',
      '这是一段太长的公开预览文字不应该拿来当作地名',
    ]) {
      final fragment = StoryFragment.fromJson({
        ..._fragmentJson(),
        'place_name': '   ',
        'safe_preview': preview,
        'title': '不应泄漏的故事标题',
      });
      expect(fragment.publicPlaceName, '地点 01');
    }
  });
}

Map<String, dynamic> _fragmentJson() => {
      'id': 'fragment-a',
      'position': 1,
      'safe_preview': '从南门辨认一座城市为何会拥有两个起点。',
      'place_name': '南头古城南门',
      'stop_id': 'stop-a',
      'interaction_type': 'passive',
      'review_state': 'reviewed',
      'trigger_region': {
        'latitude': 22.5,
        'longitude': 114.0,
        'entry_radius_m': 50,
        'exit_radius_m': 80,
        'max_accuracy_m': 35,
        'qualifying_samples': 2,
        'sample_window_seconds': 15,
        'cooldown_seconds': 120,
        'audit_state': 'reviewed',
      },
      'audio': {
        'url': 'https://cdn.example.test/fragment-a.m4a',
        'mime_type': 'audio/mp4',
        'script_version': 'v1',
      },
    };
