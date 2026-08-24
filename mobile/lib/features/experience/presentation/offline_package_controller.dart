import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/narration_voice_preference_repository.dart';
import '../data/route_offline_package_service.dart';
import '../domain/models.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';

export '../data/route_offline_package_service.dart'
    show OfflinePackagePhase, OfflinePackageStatus;

class OfflinePackageKey {
  const OfflinePackageKey(this.slug, this.version);

  final String slug;
  final String? version;

  @override
  bool operator ==(Object other) =>
      other is OfflinePackageKey &&
      other.slug == slug &&
      other.version == version;

  @override
  int get hashCode => Object.hash(slug, version);
}

class OfflinePackageController extends AsyncNotifier<OfflinePackageStatus> {
  OfflinePackageController(this.key);

  final OfflinePackageKey key;

  @override
  Future<OfflinePackageStatus> build() => ref
      .watch(routeOfflinePackageServiceProvider)
      .status(key.slug, currentVersion: key.version);

  Future<void> download(RouteExperience route) async {
    state = const AsyncData(
      OfflinePackageStatus(phase: OfflinePackagePhase.downloading),
    );
    try {
      final userId = ref.read(currentUserIdProvider);
      final preferredProfileId = userId == null
          ? null
          : await ref
              .read(narrationVoicePreferenceRepositoryProvider)
              .read(NarrationVoicePreferenceKey(
                userId: userId,
                routeId: route.id,
              ));
      final package =
          await ref.read(routeOfflinePackageServiceProvider).install(
        route.slug,
        preferredNarrationProfileId: preferredProfileId,
        onProgress: (complete, total) {
          state = AsyncData(OfflinePackageStatus(
            phase: OfflinePackagePhase.downloading,
            complete: complete,
            total: total,
          ));
        },
      );
      state = AsyncData(OfflinePackageStatus(
        phase: OfflinePackagePhase.complete,
        complete: package.preparedPaths.length,
        total: package.preparedPaths.length,
        version: package.version,
        checksumSha256: package.checksumSha256,
        message: '版本 ${package.version} · 完整性校验通过',
      ));
      ref.invalidate(offlineAwareRouteProvider(route.slug));
    } catch (error) {
      state = AsyncData(OfflinePackageStatus(
        phase: OfflinePackagePhase.failed,
        message: _message(error),
      ));
    }
  }

  String _message(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    return text.isEmpty ? '离线包下载失败，点击重试' : '$text，点击重试';
  }
}

final offlinePackageControllerProvider = AsyncNotifierProvider.family<
    OfflinePackageController, OfflinePackageStatus, OfflinePackageKey>(
  OfflinePackageController.new,
);

final offlineAwareRouteProvider = FutureProvider.autoDispose
    .family<RouteExperience, String>((ref, slug) async {
  try {
    return await ref.watch(experienceRepositoryProvider).routeBySlug(slug);
  } catch (_) {
    final package =
        await ref.watch(routeOfflinePackageServiceProvider).load(slug);
    if (package != null) return package.route;
    rethrow;
  }
});
