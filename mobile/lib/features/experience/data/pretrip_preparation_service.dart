import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import '../domain/city_story.dart';

class PretripPreparationResult {
  const PretripPreparationResult({
    required this.preparedCount,
    required this.failures,
  });

  final int preparedCount;
  final Map<String, String> failures;

  bool get isComplete => failures.isEmpty;
}

class PretripPreparationService {
  const PretripPreparationService(
    this._dio, {
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider;

  final Dio _dio;
  final Future<Directory> Function()? _directoryProvider;

  Future<PretripPreparationResult> prepare(
    List<OfflineStoryResource> resources, {
    void Function(int complete, int total)? onProgress,
  }) async {
    final root = await _directory();
    var prepared = 0;
    final failures = <String, String>{};
    for (final resource in resources) {
      try {
        final bytes = await _resourceBytes(resource);
        _verify(resource, bytes);
        final key = _resourceKey(resource);
        final target = File(paths.join(root.path, '$key--${resource.version}'));
        await _removeStale(root, key, target.path);
        final temporary = File('${target.path}.download');
        await temporary.writeAsBytes(bytes, flush: true);
        final persisted = await temporary.readAsBytes();
        _verify(resource, persisted);
        if (await target.exists()) await target.delete();
        await temporary.rename(target.path);
        prepared += 1;
      } catch (error) {
        failures[resource.id] = error.toString();
      }
      onProgress?.call(prepared + failures.length, resources.length);
    }
    return PretripPreparationResult(
      preparedCount: prepared,
      failures: failures,
    );
  }

  Future<int> remove(List<OfflineStoryResource> resources) async {
    final root = await _directory();
    var removed = 0;
    for (final resource in resources) {
      final prefix = '${_resourceKey(resource)}--';
      await for (final entity in root.list()) {
        if (entity is File && paths.basename(entity.path).startsWith(prefix)) {
          await entity.delete();
          removed += 1;
        }
      }
    }
    return removed;
  }

  Future<List<int>> _resourceBytes(OfflineStoryResource resource) async {
    if (resource.kind == 'transcript') {
      final response = await _dio.get(resource.url);
      final envelope = response.data;
      final data = envelope is Map ? envelope['data'] : null;
      final transcript = data is Map ? data['transcript'] : null;
      if (transcript is! String) throw StateError('文字稿响应格式不正确');
      return utf8.encode(transcript);
    }
    final response = await _dio.get<List<int>>(
      resource.url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }

  void _verify(OfflineStoryResource resource, List<int> bytes) {
    if (resource.sizeBytes > 0 && bytes.length != resource.sizeBytes) {
      throw StateError('资源大小不一致');
    }
    final checksum = resource.checksumSha256;
    if (checksum != null && checksum.isNotEmpty) {
      final actual = sha256.convert(bytes).toString();
      if (actual != checksum) throw StateError('资源校验失败');
    }
  }

  Future<Directory> _directory() async {
    final provided = _directoryProvider;
    if (provided != null) {
      final directory = await provided();
      await directory.create(recursive: true);
      return directory;
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory(paths.join(support.path, 'pretrip'));
    await directory.create(recursive: true);
    return directory;
  }

  String _resourceKey(OfflineStoryResource resource) =>
      sha256.convert(utf8.encode(resource.id)).toString();

  Future<void> _removeStale(
    Directory root,
    String key,
    String currentPath,
  ) async {
    final prefix = '$key--';
    await for (final entity in root.list()) {
      if (entity is File &&
          entity.path != currentPath &&
          paths.basename(entity.path).startsWith(prefix)) {
        await entity.delete();
      }
    }
  }
}
