import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/route_back.dart';
import '../../../core/theme/app_theme.dart';
import '../data/prepared_route_service.dart';
import '../data/route_offline_package_service.dart';
import '../data/user_preferences_repository.dart';
import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'location_mode_controller.dart';
import 'offline_package_controller.dart';
import 'widgets/traveler_bottom_navigation.dart';

final playbackSpeedPreferenceProvider = FutureProvider.family<double, String>(
    (ref, userId) =>
        ref.watch(userPreferencesRepositoryProvider).readPlaybackSpeed(userId));

final downloadPolicyPreferenceProvider =
    FutureProvider.family<DownloadPolicy, String>((ref, userId) => ref
        .watch(userPreferencesRepositoryProvider)
        .readDownloadPolicy(userId));

final offlineCachePackagesProvider =
    FutureProvider<List<InstalledRoutePackage>>((ref) =>
        ref.watch(routeOfflinePackageServiceProvider).installedPackages());

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final package = await PackageInfo.fromPlatform();
    return '${package.version}+${package.buildNumber}';
  } catch (_) {
    return AppConfig.appVersion;
  }
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    return RouteBackScope(
      fallbackLocation: '/',
      child: Scaffold(
        bottomNavigationBar: const TravelerBottomNavigation(
          active: TravelerSection.discovery,
        ),
        appBar: AppBar(
          title: const Text('设置'),
          leading: IconButton(
            tooltip: '返回首页',
            onPressed: () => popOrGo(context, '/'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: userId == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _SettingsSection(
                    title: '讲述',
                    children: [
                      _PlaybackSpeedTile(userId: userId),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.record_voice_over_outlined),
                        title: Text('讲述声音'),
                        subtitle: Text('每条景点讲述可在播放器中切换可用声音'),
                        trailing: Text('随内容提供'),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.headphones_rounded),
                        title: Text('建议佩戴耳机'),
                        subtitle: Text('靠近景点时更容易听清环境与讲述的层次'),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: '定位与触发',
                    children: [
                      const _LocationModeTile(),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.radar_rounded),
                        title: Text('靠近景点自动准备讲述'),
                        subtitle: Text('仅在行走导览开启时使用位置；系统限制会如实提示'),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: '下载',
                    children: [
                      _DownloadPolicyTile(userId: userId),
                      const Divider(height: 1),
                      const _OfflineCacheTile(),
                      const Divider(height: 1),
                      const _ClearAudioCacheTile(),
                    ],
                  ),
                  _SettingsSection(
                    title: '照片与隐私',
                    children: [
                      _EvidencePolicyTile(userId: userId),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.location_off_outlined),
                        title: Text('照片位置保持私密'),
                        subtitle: Text('上传时移除 EXIF；私人照片不会自动发布到社区'),
                      ),
                    ],
                  ),
                  const _SettingsSection(
                    title: '数据与测试',
                    children: [
                      _ClearExplorationDataTile(),
                    ],
                  ),
                  _SettingsSection(
                    title: '账号与关于',
                    children: [
                      const ListTile(
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('旅行者账号'),
                        subtitle: Text('足迹、收藏与私人照片只对当前账号可见'),
                        trailing: Icon(Icons.verified_user_outlined),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('见地版本'),
                        trailing: Text(
                          ref.watch(appVersionProvider).value ?? '读取中',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.moss)),
            ),
            Card(child: Column(children: children)),
          ],
        ),
      );
}

class _PlaybackSpeedTile extends ConsumerWidget {
  const _PlaybackSpeedTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playbackSpeedPreferenceProvider(userId)).value ?? 1;
    return ListTile(
      leading: const Icon(Icons.speed_rounded),
      title: const Text('默认播放速度'),
      subtitle: const Text('新播放的讲解会使用这个速度'),
      trailing: DropdownButton<double>(
        value: [0.8, 1.0, 1.25, 1.5].contains(speed) ? speed : 1.0,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 0.8, child: Text('0.8×')),
          DropdownMenuItem(value: 1.0, child: Text('1.0×')),
          DropdownMenuItem(value: 1.25, child: Text('1.25×')),
          DropdownMenuItem(value: 1.5, child: Text('1.5×')),
        ],
        onChanged: (value) async {
          if (value == null) return;
          await ref
              .read(userPreferencesRepositoryProvider)
              .writePlaybackSpeed(userId, value);
          await ref.read(narrationPlayerProvider).setSpeed(value);
          ref.invalidate(playbackSpeedPreferenceProvider(userId));
        },
      ),
    );
  }
}

class _LocationModeTile extends ConsumerWidget {
  const _LocationModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(locationModeControllerProvider).value ??
        TourLocationMode.real;
    return SwitchListTile(
      secondary: const Icon(Icons.location_on_outlined),
      title: const Text('测试用模拟定位'),
      subtitle: Text(mode == TourLocationMode.simulated
          ? '不读取真实位置，可手动推进测试'
          : '按现场位置自动发现线索'),
      value: mode == TourLocationMode.simulated,
      onChanged: (enabled) =>
          ref.read(locationModeControllerProvider.notifier).setMode(
                enabled ? TourLocationMode.simulated : TourLocationMode.real,
              ),
    );
  }
}

class _DownloadPolicyTile extends ConsumerWidget {
  const _DownloadPolicyTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(downloadPolicyPreferenceProvider(userId)).value ??
        DownloadPolicy.wifiOnly;
    return ListTile(
      leading: const Icon(Icons.download_outlined),
      title: const Text('路线音频预下载'),
      subtitle: const Text('只影响整条路线缓存，不限制在线播放'),
      trailing: DropdownButton<DownloadPolicy>(
        value: policy,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(
              value: DownloadPolicy.wifiOnly, child: Text('仅 Wi-Fi')),
          DropdownMenuItem(
              value: DownloadPolicy.anyNetwork, child: Text('任意网络')),
          DropdownMenuItem(value: DownloadPolicy.manual, child: Text('手动')),
        ],
        onChanged: (value) async {
          if (value == null) return;
          await ref
              .read(userPreferencesRepositoryProvider)
              .writeDownloadPolicy(userId, value);
          ref.invalidate(downloadPolicyPreferenceProvider(userId));
        },
      ),
    );
  }
}

class _ClearAudioCacheTile extends ConsumerWidget {
  const _ClearAudioCacheTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('清除已下载音频'),
        subtitle: const Text('不会删除足迹、照片、登录或未上传记录'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('清除音频缓存？'),
              content: const Text('之后仍可在线播放，或在合适的网络下重新下载。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('清除'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          final result =
              await ref.read(preparedRouteServiceProvider).clearPreparedAudio();
          if (!context.mounted) return;
          final message = result.isComplete
              ? '已清除 ${result.removedCount} 条音频缓存'
              : '已清除 ${result.removedCount} 条，${result.failedPaths.length} 条暂时无法删除';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        },
      );
}

class _OfflineCacheTile extends ConsumerWidget {
  const _OfflineCacheTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(offlineCachePackagesProvider);
    return ExpansionTile(
      leading: const Icon(Icons.offline_pin_outlined),
      title: const Text('离线缓存'),
      subtitle: Text(packages.when(
        loading: () => '正在读取',
        error: (_, __) => '暂时无法读取',
        data: (items) => items.isEmpty ? '暂无离线景点包' : '已缓存 ${items.length} 个景点',
      )),
      children: packages.when(
        loading: () => const [
          Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ],
        error: (_, __) => [
          ListTile(
            title: const Text('离线缓存读取失败'),
            trailing: TextButton(
              onPressed: () => ref.invalidate(offlineCachePackagesProvider),
              child: const Text('重试'),
            ),
          ),
        ],
        data: (items) => items.isEmpty
            ? const [
                ListTile(
                  title: Text('还没有下载离线景点包'),
                  subtitle: Text('可在首页景点卡片左下角下载。'),
                ),
              ]
            : items
                .map((package) => ListTile(
                      title: Text(package.route.title),
                      subtitle: Text(
                        '${package.city.name} · 版本 ${package.version} · ${package.preparedPaths.length} 段音频',
                      ),
                      trailing: IconButton(
                        key: ValueKey(
                          'remove-offline-package-${package.route.slug}',
                        ),
                        tooltip: '清除${package.route.title}离线缓存',
                        onPressed: () => _remove(context, ref, package),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ))
                .toList(growable: false),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    InstalledRoutePackage package,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('清除${package.route.title}离线缓存？'),
        content: const Text('该景点之后需要联网使用，也可以重新下载。其他景点的离线缓存不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    PreparedAudioClearResult result;
    try {
      result = await ref
          .read(routeOfflinePackageServiceProvider)
          .remove(package.route.slug);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('离线缓存清除失败，请重试')),
        );
      }
      return;
    }
    ref.invalidate(offlineCachePackagesProvider);
    ref.invalidate(offlinePackageControllerProvider(OfflinePackageKey(
      package.route.slug,
      package.route.audioTour?.scriptVersion,
    )));
    ref.invalidate(offlineAwareRouteProvider(package.route.slug));
    if (!context.mounted) return;
    final message = result.isComplete
        ? '已清除${package.route.title}离线缓存'
        : '离线包已移除，${result.failedPaths.length} 个文件暂时无法删除';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EvidencePolicyTile extends ConsumerWidget {
  const _EvidencePolicyTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(evidencePolicyProvider(userId));
    return policy.when(
      loading: () => const ListTile(
        leading: Icon(Icons.privacy_tip_outlined),
        title: Text('正在读取照片政策'),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('照片政策暂时不可用'),
        subtitle: const Text('照片仍按私密访问处理，可点击重试。'),
        onTap: () => ref.invalidate(evidencePolicyProvider(userId)),
      ),
      data: (policy) => _PolicyContent(policy: policy),
    );
  }
}

class _ClearExplorationDataTile extends ConsumerWidget {
  const _ClearExplorationDataTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: const Icon(Icons.restart_alt_rounded),
        title: const Text('清除探索记录'),
        subtitle: const Text('重新锁定所有节点；保留账号、收藏、照片和下载内容'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _clear(context, ref),
      );

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除全部探索记录？'),
        content: const Text(
          '所有旅程进度、已解锁节点、线索簿和故事拼合状态都会重置，便于重新测试上锁流程。'
          '\n\n账号、收藏、已上传照片、足迹、社区内容、离线包和音频缓存不会删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(activeTourControllerProvider.notifier)
          .clearForAccountExit();
      final result = await ref
          .read(experienceRepositoryProvider)
          .clearExplorationProgress();
      await ref.read(tourStoreProvider).clearPrivateData();
      ref.invalidate(journeyControllerProvider);
      ref.invalidate(activeTourControllerProvider);
      ref.invalidate(archivedActiveJourneysProvider);
      ref.invalidate(journeyLibraryProvider);
      ref.invalidate(journeyContextProvider);
      ref.invalidate(currentJourneyLibraryProvider);
      ref.invalidate(currentAllJourneysProvider);
      ref.invalidate(routeJourneyIndexProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '已重置 ${result.journeyCount} 段旅程、${result.fragmentCount} 个节点',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('探索记录清除失败，请检查网络后重试')),
      );
    }
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent({required this.policy});

  final EvidencePolicy policy;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('旅途照片为私密内容'),
        subtitle: Text(
          '仅本人可查看 · 上传时移除 EXIF · 保留 ${policy.retentionDays} 天 · '
          '单张上限 ${(policy.maxBytes / 1024 / 1024).toStringAsFixed(0)} MB',
        ),
      );
}
