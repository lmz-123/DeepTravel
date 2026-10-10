import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/city_map.dart';

abstract interface class CityMapCache {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
}

class FileCityMapCache implements CityMapCache {
  Future<File> _file(String key) async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/city-maps');
    await folder.create(recursive: true);
    return File('${folder.path}/${sha256.convert(utf8.encode(key))}.json');
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists() || await file.length() > 5 * 1024 * 1024) {
      return null;
    }
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final file = await _file(key);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }
}

/// OSS requests deliberately use a separate client without account credentials.
Future<Uint8List> downloadCityMap(String url) async {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid map URL');
  }
  final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      followRedirects: false));
  final token = CancelToken();
  final timer = Timer(const Duration(seconds: 20), () {
    if (!token.isCancelled) token.cancel('Map download timed out');
  });
  try {
    final response = await dio.get<ResponseBody>(url,
        options: Options(responseType: ResponseType.stream),
        cancelToken: token);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.data!.stream) {
      if (bytes.length + chunk.length > 4 * 1024 * 1024) {
        throw const FormatException('Map too large');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  } finally {
    token.cancel();
    dio.close(force: true);
    timer.cancel();
  }
}

class CityMapRepository {
  CityMapRepository(
      {required this.scope,
      required this.manifest,
      required this.bundled,
      required this.cache,
      this.download = downloadCityMap});
  final String scope;
  final Future<Map<String, dynamic>> Function(String) manifest;
  final Future<List<CityAtlasDistrict>> Function(String) bundled;
  final CityMapCache cache;
  final Future<Uint8List> Function(String) download;
  final _pending = <String, Future<Map<String, dynamic>?>>{};

  Stream<List<CityAtlasDistrict>> watch(String city) async* {
    final key = '$scope/$city';
    Map<String, dynamic>? cached;
    List<CityAtlasDistrict> initial = const [];
    try {
      cached = await cache.read(key);
      if (cached != null) initial = parseCityMap(cached['geometry']);
    } catch (_) {
      cached = null;
    }
    if (initial.isEmpty) initial = await bundled(city);
    yield initial;
    if (city.isEmpty) return;
    try {
      final future =
          _pending.putIfAbsent(key, () => _refresh(city, key, cached));
      Map<String, dynamic>? fresh;
      try {
        fresh = await future;
      } finally {
        if (identical(_pending[key], future)) _pending.remove(key);
      }
      if (fresh != null) yield parseCityMap(fresh['geometry']);
    } catch (_) {
      // Keep the already rendered offline map on network, cache or parsing errors.
    }
  }

  Future<Map<String, dynamic>?> _refresh(
      String city, String key, Map<String, dynamic>? cached) async {
    final data = await manifest(city);
    if (data['status'] != 'ready' ||
        data['url'] is! String ||
        data['version'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['version'] as String)) {
      return null;
    }
    if (data['version'] == cached?['version']) return cached;
    final bytes = await download(data['url'] as String);
    if (bytes.length > 4 * 1024 * 1024 ||
        sha256.convert(bytes).toString() != data['version']) {
      throw const FormatException('Map checksum mismatch');
    }
    final geometry = jsonDecode(utf8.decode(bytes));
    parseCityMap(geometry);
    final next = <String, dynamic>{
      'version': data['version'],
      'geometry': geometry
    };
    try {
      await cache.write(key, next);
    } catch (_) {/* Display even if disk is full. */}
    return next;
  }
}
