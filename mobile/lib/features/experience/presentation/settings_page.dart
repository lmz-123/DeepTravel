import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/route_back.dart';
import '../../../core/theme/app_theme.dart';
import '../data/user_preferences_repository.dart';
import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'location_mode_controller.dart';

final playbackSpeedPreferenceProvider = FutureProvider.family<double, String>(
    (ref, userId) =>
        ref.watch(userPreferencesRepositoryProvider).readPlaybackSpeed(userId));

final downloadPolicyPreferenceProvider =
    FutureProvider.family<DownloadPolicy, String>((ref, userId) => ref
        .watch(userPreferencesRepositoryProvider)
        .readDownloadPolicy(userId));

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
                    title: '播放',
                    children: [
                      _PlaybackSpeedTile(userId: userId),
                    ],
                  ),
                  _SettingsSection(
                    title: '行走与下载',
                    children: [
                      const _LocationModeTile(),
                      _DownloadPolicyTile(userId: userId),
                      const _ClearAudioCacheTile(),
                    ],
                  ),
                  _SettingsSection(
                    title: '照片与隐私',
                    children: [
                      _EvidencePolicyTile(userId: userId),
                    ],
                  ),
                  _SettingsSection(
                    title: '关于',
                    children: [
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
