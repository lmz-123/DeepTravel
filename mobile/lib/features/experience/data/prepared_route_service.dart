import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'platform_tour_adapters.dart';
import 'user_preferences_repository.dart';

String narrationCacheVersion(String? profileId, NarrationAsset asset) =>
    '${profileId ?? 'default'}:${asset.scriptVersion}';

class PreparedRouteService {
  PreparedRouteService(
    this._dio,
    this._store, {
    ConnectivityReader? connectivity,
    Future<DownloadPolicy> Function()? downloadPolicy,
    PreparedFileSystem? fileSystem,
    Future<Directory> Function()? directoryProvider,
  })  : _connectivity = connectivity ?? PluginConnectivityReader(),
        _downloadPolicy =
            downloadPolicy ?? (() async => DownloadPolicy.wifiOnly),
        _fileSystem = fileSystem ?? const IoPreparedFileSystem(),
        _directoryProvider = directoryProvider;

  final Dio _dio;
  final TourStore _store;
  final ConnectivityReader _connectivity;
  final Future<DownloadPolicy> Function() _downloadPolicy;
  final PreparedFileSystem _fileSystem;
  final Future<Directory> Function()? _directoryProvider;

  Future<Map<String, String>> prepare(
    AudioTourManifest manifest,
    String? profileId,
  ) =>
      _prepare(manifest, profileId);

  Future<Map<String, String>> prepareExplicit(
    AudioTourManifest manifest,
    String? profileId, {
    void Function(int complete, int total)? onProgress,
  }) =>
      _prepare(
        manifest,
        profileId,
        explicit: true,
        onProgress: onProgress,
      );

  Future<Map<String, String>> _prepare(
    AudioTourManifest manifest,
    String? profileId, {
    bool explicit = false,
    void Function(int complete, int total)? onProgress,
  }) async {
    if (!explicit) await _enforceDownloadPolicy();
    if (manifest.fragments.isEmpty) return const {};
    final support = _directoryProvider == null
        ? await getApplicationSupportDirectory()
        : await _directoryProvider();
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
      if (await _isPrepared(existing, asset, requireChecksum: explicit)) {
        result[fragment.id] = existing!;
        onProgress?.call(result.length, manifest.fragments.length);
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
      await _verifyChecksum(file, asset, required: explicit);
      final targetFile = File(target);
      if (await targetFile.exists()) await targetFile.delete();
      await file.rename(target);
      await _store.savePreparedAsset(
          asset.url, target, cacheVersion, asset.sizeBytes);
      result[fragment.id] = target;
      onProgress?.call(result.length, manifest.fragments.length);
    }
    return result;
  }

  Future<Map<String, String>?> preparedPaths(
    AudioTourManifest manifest,
    String? profileId, {
    bool requireChecksum = false,
  }) async {
    final result = <String, String>{};
    for (final fragment in manifest.fragments) {
      final asset = fragment.narrationFor(profileId);
      final path = await _store.preparedAsset(
        asset.url,
        narrationCacheVersion(profileId, asset),
        asset.sizeBytes,
      );
      if (!await _isPrepared(path, asset, requireChecksum: requireChecksum)) {
        return null;
      }
      result[fragment.id] = path!;
    }
    return result;
  }

  Future<bool> _isPrepared(
    String? path,
    NarrationAsset asset, {
    required bool requireChecksum,
  }) async {
    if (!preparedFileExists(path, asset.sizeBytes)) return false;
    try {
      await _verifyChecksum(File(path!), asset, required: requireChecksum);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyChecksum(
    File file,
    NarrationAsset asset, {
    required bool required,
  }) async {
    final checksum = asset.checksumSha256;
    if (checksum == null || checksum.isEmpty) {
      if (required) throw StateError('离线音频缺少校验和');
      return;
    }
    final actual = sha256.convert(await file.readAsBytes()).toString();
    if (actual != checksum) throw StateError('故事音频校验失败，请重试');
  }

  Future<void> _enforceDownloadPolicy() async {
    final policy = await _downloadPolicy();
    if (policy == DownloadPolicy.manual) {
      throw const RoutePreparationSkipped(
        '当前为手动下载；音频仍可在线播放，也可在设置中改为自动下载。',
      );
    }
    if (policy != DownloadPolicy.wifiOnly) return;
    final transports = await _connectivity.current();
    if (!transports.contains(ConnectivityResult.wifi) &&
        !transports.contains(ConnectivityResult.ethernet)) {
      throw const RoutePreparationSkipped(
        '当前不是 Wi-Fi，已跳过整条路线预下载；播放时会按需联网。',
      );
    }
  }

  Future<PreparedAudioClearResult> clearPreparedAudio() async {
    return _clearPreparedAudio(
      (await _store.preparedAssets()).map((asset) => asset.url).toSet(),
    );
  }

  Future<PreparedAudioClearResult> clearPreparedAudioUrls(
    Set<String> urls,
  ) =>
      _clearPreparedAudio(urls);

  Future<PreparedAudioClearResult> _clearPreparedAudio(
    Set<String> urls,
  ) async {
    var removed = 0;
    final failures = <String>[];
    for (final asset in await _store.preparedAssets()) {
      if (!urls.contains(asset.url)) continue;
      try {
        if (await _fileSystem.exists(asset.path)) {
          await _fileSystem.delete(asset.path);
        }
        await _store.removePreparedAsset(asset.url);
        removed += 1;
      } catch (_) {
        failures.add(asset.path);
      }
    }
    return PreparedAudioClearResult(
      removedCount: removed,
      failedPaths: failures,
    );
  }
}

class PreparedAudioClearResult {
  const PreparedAudioClearResult({
    required this.removedCount,
    required this.failedPaths,
  });

  final int removedCount;
  final List<String> failedPaths;
  bool get isComplete => failedPaths.isEmpty;
}

abstract interface class PreparedFileSystem {
  Future<bool> exists(String path);
  Future<void> delete(String path);
}

class IoPreparedFileSystem implements PreparedFileSystem {
  const IoPreparedFileSystem();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> delete(String path) => File(path).delete();
}

abstract interface class ConnectivityReader {
  Future<List<ConnectivityResult>> current();
}

class PluginConnectivityReader implements ConnectivityReader {
  @override
  Future<List<ConnectivityResult>> current() =>
      Connectivity().checkConnectivity();
}

class RoutePreparationSkipped implements Exception {
  const RoutePreparationSkipped(this.message);

  final String message;

  @override
  String toString() => message;
}
