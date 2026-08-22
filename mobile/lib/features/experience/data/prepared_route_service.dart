import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'platform_tour_adapters.dart';

String narrationCacheVersion(String? profileId, NarrationAsset asset) =>
    '${profileId ?? 'default'}:${asset.scriptVersion}';

class PreparedRouteService {
  PreparedRouteService(this._dio, this._store);
  final Dio _dio;
  final TourStore _store;

  Future<Map<String, String>> prepare(
      AudioTourManifest manifest, String? profileId) async {
    final support = await getApplicationSupportDirectory();
    final directory =
        Directory(paths.join(support.path, 'prepared', manifest.scriptVersion));
    await directory.create(recursive: true);
    final result = <String, String>{};
    for (final fragment in manifest.fragments) {
      final asset = fragment.narrationFor(profileId);
      final profileKey = profileId ?? 'default';
      final cacheVersion = narrationCacheVersion(profileId, asset);
      final existing =
          await _store.preparedAsset(asset.url, cacheVersion, asset.sizeBytes);
      if (preparedFileExists(existing, asset.sizeBytes)) {
        result[fragment.id] = existing!;
        continue;
      }
      final target = paths.join(directory.path,
          '${fragment.id}-$profileKey-${asset.scriptVersion}.m4a');
      final temporary = '$target.download';
      await _dio.download(asset.url, temporary);
      final file = File(temporary);
      if (!await file.exists() ||
          (asset.sizeBytes > 0 && await file.length() != asset.sizeBytes)) {
        await file.delete().catchError((_) => file);
        throw StateError('故事音频下载不完整，请重试');
      }
      await file.rename(target);
      await _store.savePreparedAsset(
          asset.url, target, cacheVersion, asset.sizeBytes);
      result[fragment.id] = target;
    }
    return result;
  }
}
