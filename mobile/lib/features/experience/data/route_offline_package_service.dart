import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../domain/models.dart';
import '../domain/tour_runtime.dart';
import 'prepared_route_service.dart';

enum OfflinePackagePhase { idle, downloading, complete, stale, failed }

class OfflinePackageStatus {
  const OfflinePackageStatus({
    required this.phase,
    this.complete = 0,
    this.total = 0,
    this.version,
    this.checksumSha256,
    this.message,
  });

  const OfflinePackageStatus.idle() : this(phase: OfflinePackagePhase.idle);

  final OfflinePackagePhase phase;
  final int complete;
  final int total;
  final String? version;
  final String? checksumSha256;
  final String? message;

  bool get isUsable => phase == OfflinePackagePhase.complete;
}

class InstalledRoutePackage {
  const InstalledRoutePackage({
    required this.city,
    required this.route,
    required this.version,
    required this.checksumSha256,
    required this.narrationProfileId,
    required this.preparedPaths,
    required this.raw,
  });

  final CityExperience city;
  final RouteExperience route;
  final String version;
  final String checksumSha256;
  final String? narrationProfileId;
  final Map<String, String> preparedPaths;
  final Map<String, dynamic> raw;
}

class RouteOfflinePackageService {
  const RouteOfflinePackageService(
    this._dio,
    this._store,
    this._preparedRoutes,
  );

  static const _indexKey = 'offline_package_index';

  final Dio _dio;
  final TourStore _store;
  final PreparedRouteService _preparedRoutes;

  Future<InstalledRoutePackage> install(
    String slug, {
    String? preferredNarrationProfileId,
    void Function(int complete, int total)? onProgress,
  }) async {
    final response = await _dio.get('/routes/$slug/offline-package');
    final envelope = response.data;
    final rawData = envelope is Map ? envelope['data'] : null;
    if (rawData is! Map) throw StateError('离线包响应格式不正确');
    final raw = Map<String, dynamic>.from(rawData);
    _verifyManifest(raw);
    final package =
        _parse(raw, narrationProfileId: preferredNarrationProfileId);
    final manifest = package.route.audioTour;
    if (manifest == null || manifest.fragments.isEmpty) {
      throw StateError('这条路线暂时没有可下载的离线故事');
    }
    if (manifest.scriptVersion != package.version) {
      throw StateError('离线包版本与路线内容不一致');
    }
    final profileId = manifest.effectiveProfileId(preferredNarrationProfileId);
    for (final fragment in manifest.fragments) {
      final asset = fragment.narrationFor(profileId);
      if (asset.scriptVersion != package.version ||
          !_isSha256(asset.checksumSha256)) {
        throw StateError('离线音频版本或校验信息不完整');
      }
    }
    final paths = await _preparedRoutes.prepareExplicit(
      manifest,
      profileId,
      onProgress: onProgress,
    );
    final stored = {
      'data': raw,
      'narration_profile_id': profileId,
      'installed_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.saveJson(_packageKey(slug), stored);
    final index = await _index();
    await _store.saveJson(_indexKey, {
      'slugs': {...index, slug}.toList()..sort(),
    });
    return InstalledRoutePackage(
      city: package.city,
      route: package.route,
      version: package.version,
      checksumSha256: package.checksumSha256,
      narrationProfileId: profileId,
      preparedPaths: paths,
      raw: raw,
    );
  }

  Future<InstalledRoutePackage?> load(String slug) async {
    final stored = await _store.readJson(_packageKey(slug));
    final rawData = stored?['data'];
    if (rawData is! Map) return null;
    try {
      final raw = Map<String, dynamic>.from(rawData);
      _verifyManifest(raw);
      final profileId = stored?['narration_profile_id'] as String?;
      final package = _parse(raw, narrationProfileId: profileId);
      final manifest = package.route.audioTour;
      if (manifest == null || manifest.scriptVersion != package.version) {
        return null;
      }
      final effectiveProfileId = manifest.effectiveProfileId(profileId);
      final paths = await _preparedRoutes.preparedPaths(
        manifest,
        effectiveProfileId,
        requireChecksum: true,
      );
      if (paths == null) return null;
      return InstalledRoutePackage(
        city: package.city,
        route: package.route,
        version: package.version,
        checksumSha256: package.checksumSha256,
        narrationProfileId: effectiveProfileId,
        preparedPaths: paths,
        raw: raw,
      );
    } catch (_) {
      return null;
    }
  }

  Future<OfflinePackageStatus> status(
    String slug, {
    String? currentVersion,
  }) async {
    final package = await load(slug);
    if (package == null) return const OfflinePackageStatus.idle();
    if (currentVersion != null && package.version != currentVersion) {
      return OfflinePackageStatus(
        phase: OfflinePackagePhase.stale,
        version: package.version,
        checksumSha256: package.checksumSha256,
        message: '离线包有新版本，点击更新',
      );
    }
    return OfflinePackageStatus(
      phase: OfflinePackagePhase.complete,
      complete: package.preparedPaths.length,
      total: package.preparedPaths.length,
      version: package.version,
      checksumSha256: package.checksumSha256,
      message: '版本 ${package.version} · 完整性校验通过',
    );
  }

  Future<List<InstalledRoutePackage>> installedPackages() async {
    final result = <InstalledRoutePackage>[];
    for (final slug in await _index()) {
      final package = await load(slug);
      if (package != null) result.add(package);
    }
    return result;
  }

  Future<PreparedAudioClearResult> remove(String slug) async {
    final index = await _index();
    final target = await _store.readJson(_packageKey(slug));
    final targetUrls = _selectedAssetUrls(target);
    final sharedUrls = <String>{};
    for (final otherSlug in index.where((value) => value != slug)) {
      sharedUrls.addAll(
        _selectedAssetUrls(await _store.readJson(_packageKey(otherSlug))),
      );
    }
    final result = await _preparedRoutes.clearPreparedAudioUrls(
      targetUrls.difference(sharedUrls),
    );
    await _store.saveJson(_packageKey(slug), const {});
    await _store.saveJson(_indexKey, {
      'slugs': (index..remove(slug)).toList()..sort(),
    });
    return result;
  }

  void _verifyManifest(Map<String, dynamic> raw) {
    final expected = raw['package_checksum_sha256'] as String?;
    if (!_isSha256(expected)) throw StateError('离线包缺少有效校验和');
    final payload = Map<String, dynamic>.from(raw)
      ..remove('package_checksum_sha256');
    final canonical = jsonEncode(_canonicalValue(payload));
    final actual = sha256.convert(utf8.encode(canonical)).toString();
    if (actual != expected) throw StateError('离线包完整性校验失败');
  }

  InstalledRoutePackage _parse(
    Map<String, dynamic> raw, {
    required String? narrationProfileId,
  }) {
    final cityJson = raw['city'];
    final routeJson = raw['route'];
    final version = raw['package_version'];
    final checksum = raw['package_checksum_sha256'];
    if (cityJson is! Map ||
        routeJson is! Map ||
        version is! String ||
        checksum is! String) {
      throw StateError('离线包缺少路线元数据');
    }
    return InstalledRoutePackage(
      city: CityExperience.fromJson(Map<String, dynamic>.from(cityJson)),
      route: RouteExperience.fromJson(Map<String, dynamic>.from(routeJson)),
      version: version,
      checksumSha256: checksum,
      narrationProfileId: narrationProfileId,
      preparedPaths: const {},
      raw: raw,
    );
  }

  Future<Set<String>> _index() async {
    final value = await _store.readJson(_indexKey);
    return (value?['slugs'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
  }

  Set<String> _selectedAssetUrls(Map<String, dynamic>? stored) {
    final rawData = stored?['data'];
    if (rawData is! Map) return const {};
    try {
      final raw = Map<String, dynamic>.from(rawData);
      _verifyManifest(raw);
      final profileId = stored?['narration_profile_id'] as String?;
      final manifest = _parse(
        raw,
        narrationProfileId: profileId,
      ).route.audioTour;
      if (manifest == null) return const {};
      final effectiveProfileId = manifest.effectiveProfileId(profileId);
      return manifest.fragments
          .map((fragment) => fragment.narrationFor(effectiveProfileId).url)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  static Object? _canonicalValue(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalValue(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalValue).toList();
    return value;
  }

  static bool _isSha256(String? value) =>
      value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  static String _packageKey(String slug) => 'offline_package_$slug';
}
