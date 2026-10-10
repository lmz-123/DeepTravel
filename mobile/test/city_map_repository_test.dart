import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/city_map_repository.dart';
import 'package:jiandi/features/experience/domain/city_map.dart';

Map<String, dynamic> geometry(String name) => {
      'type': 'FeatureCollection',
      'features': [
        {
          'properties': {
            'name': name,
            'center': [120, 30]
          },
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [120, 30],
                [121, 30],
                [121, 31],
                [120, 30]
              ]
            ]
          }
        }
      ]
    };

class Cache implements CityMapCache {
  final entries = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    entries[key] = value;
  }
}

void main() {
  test(
      'new city downloads, caches across restart and refreshes changed version',
      () async {
    final cache = Cache();
    var bytes = Uint8List.fromList(utf8.encode(jsonEncode(geometry('上城区'))));
    var downloads = 0;
    var offline = false;
    CityMapRepository repository() => CityMapRepository(
        scope: 'api',
        cache: cache,
        bundled: (_) async => [],
        manifest: (_) async {
          if (offline) throw StateError('offline');
          return {
            'status': 'ready',
            'version': sha256.convert(bytes).toString(),
            'url': 'https://oss.example/map'
          };
        },
        download: (_) async {
          downloads++;
          return bytes;
        });
    var events = await repository().watch('hangzhou').toList();
    expect(events.first, isEmpty);
    expect(events.last.single.name, '上城区');
    offline = true;
    events = await repository().watch('hangzhou').toList();
    expect(events.single.single.name, '上城区');
    offline = false;
    await repository().watch('hangzhou').toList();
    expect(downloads, 1);
    bytes = Uint8List.fromList(utf8.encode(jsonEncode(geometry('拱墅区'))));
    events = await repository().watch('hangzhou').toList();
    expect(events.first.single.name, '上城区');
    expect(events.last.single.name, '拱墅区');
    expect(downloads, 2);
  });
  test('corrupt remote map never replaces last known boundaries', () async {
    final cache = Cache();
    cache.entries['api/hz'] = {'version': 'a' * 64, 'geometry': geometry('缓存')};
    final repo = CityMapRepository(
        scope: 'api',
        cache: cache,
        bundled: (_) async => [],
        manifest: (_) async => {
              'status': 'ready',
              'version': 'b' * 64,
              'url': 'https://oss.example/map'
            },
        download: (_) async => Uint8List.fromList(utf8.encode('{}')));
    final events = await repo.watch('hz').toList();
    expect(events.single.single.name, '缓存');
    expect(cache.entries['api/hz']!['version'], 'a' * 64);
  });
  test('pending service retains bundled map and server scopes do not mix',
      () async {
    final cache = Cache();
    cache.entries['old-api/hz'] = {
      'version': 'a' * 64,
      'geometry': geometry('错误服务器')
    };
    final repo = CityMapRepository(
        scope: 'new-api',
        cache: cache,
        bundled: (_) async => parseCityMap(geometry('内置')),
        manifest: (_) async => {'status': 'pending'},
        download: (_) async => throw StateError('unexpected'));
    expect((await repo.watch('hz').toList()).single.single.name, '内置');
  });
  test('rejects invalid boundaries instead of drawing them', () {
    for (final data in [
      <String, dynamic>{},
      {'type': 'FeatureCollection', 'features': []}
    ]) {
      expect(() => parseCityMap(data), throwsFormatException);
    }
  });
}
