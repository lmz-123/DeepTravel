import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_back.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/city_story.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'home_story_controller.dart';
import 'traveler_shell.dart';
import 'widgets/discovery_art.dart';

/// The personal page is the home behind the brand mark. It gathers private
/// destinations without competing with the public city journal.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final userId = session?.user.id;
    final favorites = userId == null
        ? null
        : ref.watch(travelerFavoritesProvider(userId));
    final footprints = ref.watch(currentFootprintsProvider);
    final name = session?.user.username?.trim();
    final savedCount = favorites?.value
            ?.where((item) => item.kind == 'route')
            .length ??
        0;
    return RouteBackScope(
      fallbackLocation: '/',
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回随刊',
                        onPressed: () => popOrGo(context, '/'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      Text('PRIVATE FILE / 见地档案', style: discoverySans(9, spacing: .9, color: AppColors.textMuted)),
                      IconButton(
                        tooltip: '设置',
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.tune_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: '打开旅行者菜单',
                        onPressed: () => TravelerShellScope.showDrawer(context),
                        icon: const Icon(Icons.menu_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(23, 16, 23, 46),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileIdentity(name: name),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          _ProfileMetric(value: favorites == null ? '—' : savedCount.toString().padLeft(2, '0'), label: '书架'),
                          const SizedBox(width: 28),
                          _ProfileMetric(
                            value: footprints.when(
                              data: (result) => result.total
                                  .toString()
                                  .padLeft(2, '0'),
                              loading: () => '—',
                              error: (_, __) => '—',
                            ),
                            label: '足迹',
                          ),
                          const SizedBox(width: 28),
                          _ProfileMetric(value: session == null ? '访' : '01', label: session == null ? '访客' : '账号'),
                        ],
                      ),
                      const SizedBox(height: 34),
                      const _ProfileSectionLabel(label: '01 / KEPT FOR LATER'),
                      const SizedBox(height: 10),
                      _ShelfSummary(
                        favorites: favorites?.value ?? const <TravelerFavorite>[],
                        loading: favorites?.isLoading == true,
                        onOpenShelf: () => context.go('/?tab=shelf'),
                      ),
                      const SizedBox(height: 30),
                      const _ProfileSectionLabel(label: '02 / WHAT YOU HAVE SEEN'),
                      const SizedBox(height: 10),
                      _ProfileEmptyFootprints(
                        onOpen: () => context.push('/footprints'),
                        count: footprints.asData?.value.total ?? 0,
                        loading: footprints.isLoading,
                        failed: footprints.hasError,
                      ),
                      const SizedBox(height: 30),
                      const _ProfileSectionLabel(label: '03 / YOUR SETTINGS'),
                      const SizedBox(height: 10),
                      _ProfileLinkRow(icon: Icons.settings_outlined, title: '播放、定位与离线内容', subtitle: '让随行按你的方式发生', onTap: () => context.push('/settings')),
                      const SizedBox(height: 9),
                      _ProfileLinkRow(icon: Icons.logout_rounded, title: '退出这个账号', subtitle: '清除本机的私人展示记录', onTap: () => _logout(context, ref)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref
        .read(homeStoryPlaybackControllerProvider.notifier)
        .clearForAccountExit();
    await ref.read(activeTourControllerProvider.notifier).clearForAccountExit();
    await ref.read(tourStoreProvider).clearPrivateData();
    ref.invalidate(journeyControllerProvider);
    ref.invalidate(activeTourControllerProvider);
    ref.invalidate(archivedActiveJourneysProvider);
    invalidatePrivateExperienceFromWidget(ref);
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/');
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Transform.rotate(
            angle: -.08,
            child: Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.terracotta,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(38),
                  topRight: Radius.circular(25),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(38),
                ),
              ),
              alignment: Alignment.center,
              child: Text('见', style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 31, color: AppColors.paper, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我的城市随身页', style: discoverySans(10, color: AppColors.textMuted, spacing: .8)),
                const SizedBox(height: 5),
                Text(name?.isNotEmpty == true ? name! : '还没有署名', maxLines: 1, overflow: TextOverflow.ellipsis, style: discoverySerif(29, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(name?.isNotEmpty == true ? '把走过的地方，留成自己的见识。' : '登录以后，收藏与足迹会在这里留下。', style: discoverySans(11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 26, fontStyle: FontStyle.italic, color: AppColors.terracotta)), const SizedBox(height: 2), Text(label, style: discoverySans(10, color: AppColors.textMuted))]);
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: discoverySans(9, color: AppColors.terracotta, spacing: 1.1));
}

class _ShelfSummary extends StatelessWidget {
  const _ShelfSummary({required this.favorites, required this.loading, required this.onOpenShelf});
  final List<TravelerFavorite> favorites;
  final bool loading;
  final VoidCallback onOpenShelf;
  @override
  Widget build(BuildContext context) {
    final routes = favorites.where((item) => item.kind == 'route').take(3).toList();
    return Column(children: [
      if (loading) const LinearProgressIndicator(minHeight: 2, color: AppColors.terracotta),
      if (!loading && routes.isEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(15, 16, 15, 16), decoration: const BoxDecoration(color: AppColors.white, border: Border(bottom: BorderSide(color: AppColors.line))), child: Row(children: [const DiscoveryIcon(DiscoveryMark.bookmark, size: 21, color: AppColors.terracotta), const SizedBox(width: 11), Expanded(child: Text('还没有收藏。去路线里留下一本想翻的城市手册。', style: discoverySans(11, height: 1.65))), const Icon(Icons.arrow_forward, size: 17, color: AppColors.terracotta)])),
      ...routes.map((item) => _ProfileLinkRow(icon: Icons.bookmark_outline, title: item.label, subtitle: item.available ? '已收进私人书架' : '内容暂时不可用', onTap: onOpenShelf)),
      const SizedBox(height: 9),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onOpenShelf, icon: const Icon(Icons.arrow_outward, size: 16), label: const Text('打开完整书架'))),
    ]);
  }
}

class _ProfileEmptyFootprints extends StatelessWidget {
  const _ProfileEmptyFootprints({
    required this.onOpen,
    required this.count,
    required this.loading,
    required this.failed,
  });
  final VoidCallback onOpen;
  final int count;
  final bool loading;
  final bool failed;
  @override
  Widget build(BuildContext context) {
    final hasFootprints = count > 0;
    final title = loading
        ? '正在读取足迹'
        : failed
            ? '足迹暂时没有加载出来'
            : hasFootprints
                ? '已经留下 $count 页足迹'
                : '还没有留下足迹';
    final message = loading
        ? '稍等一下，正在整理你的城市印象。'
        : failed
            ? '打开足迹页重试，已保存的内容不会消失。'
            : hasFootprints
                ? '打开足迹，继续整理听过、看过和留下的片段。'
                : '每听到一个故事，才慢慢写下一页。';
    return InkWell(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Text(
              hasFootprints ? '$count' : '未',
              style: discoverySerif(
                28,
                color: AppColors.lime,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: discoverySerif(16)),
                  const SizedBox(height: 3),
                  Text(message, style: discoverySans(10, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 17, color: AppColors.terracotta),
          ],
        ),
      ),
    );
  }
}

class _ProfileLinkRow extends StatelessWidget {
  const _ProfileLinkRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(width: double.infinity, constraints: const BoxConstraints(minHeight: 64), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))), child: Row(children: [Icon(icon, size: 19, color: AppColors.terracotta), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: discoverySerif(15)), const SizedBox(height: 2), Text(subtitle, style: discoverySans(10, color: AppColors.textMuted))])), const Icon(Icons.arrow_forward, size: 17, color: AppColors.terracotta)])));
}
