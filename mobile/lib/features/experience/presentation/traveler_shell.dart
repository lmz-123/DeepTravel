import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';

class TravelerShell extends ConsumerStatefulWidget {
  const TravelerShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TravelerShell> createState() => _TravelerShellState();
}

class _TravelerShellState extends ConsumerState<TravelerShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => TravelerShellScope(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        child: Scaffold(
          key: _scaffoldKey,
          drawer: const _TravelerDrawer(),
          body: widget.child,
        ),
      );
}

class TravelerShellScope extends InheritedWidget {
  const TravelerShellScope({
    required this.onOpenDrawer,
    required super.child,
    super.key,
  });

  final VoidCallback onOpenDrawer;

  static void showDrawer(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TravelerShellScope>();
    scope?.onOpenDrawer();
  }

  @override
  bool updateShouldNotify(TravelerShellScope oldWidget) => false;
}

class _TravelerDrawer extends ConsumerWidget {
  const _TravelerDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final username = session?.user.username?.trim();
    return Drawer(
      backgroundColor: AppColors.paper,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.ink,
                    child: Icon(Icons.person_outline_rounded,
                        color: AppColors.gold, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username?.isNotEmpty == true ? username! : '见地旅行者',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text('把走过的地方，留成自己的见识',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerDestination(
              icon: Icons.route_outlined,
              label: '足迹',
              subtitle: '看已完成的路线与照片',
              onTap: () => _go(context, '/footprints'),
            ),
            _DrawerDestination(
              icon: Icons.tune_rounded,
              label: '设置',
              subtitle: '播放、定位、下载与隐私',
              onTap: () => _go(context, '/settings'),
            ),
            if (AppConfig.testAuthEnabled ||
                session?.user.accountKind == 'test') ...[
              const Divider(),
              _DrawerDestination(
                icon: Icons.science_outlined,
                label: '切换测试账号 A',
                onTap: () => _switchAccount(context, ref, 'tester-a'),
              ),
              _DrawerDestination(
                icon: Icons.science_rounded,
                label: '切换测试账号 B',
                onTap: () => _switchAccount(context, ref, 'tester-b'),
              ),
            ],
            const Spacer(),
            const Divider(height: 1),
            _DrawerDestination(
              icon: Icons.logout_rounded,
              label: '退出登录',
              onTap: () => _logout(context, ref),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.go(location);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await _clearPrivatePresentation(ref);
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/');
  }

  Future<void> _switchAccount(
      BuildContext context, WidgetRef ref, String alias) async {
    Navigator.of(context).pop();
    await _clearPrivatePresentation(ref);
    await ref.read(authControllerProvider.notifier).switchTestUser(alias);
    if (context.mounted) context.go('/');
  }

  Future<void> _clearPrivatePresentation(WidgetRef ref) async {
    await ref.read(activeTourControllerProvider.notifier).clearForAccountExit();
    await ref.read(tourStoreProvider).clearPrivateData();
    ref.invalidate(journeyControllerProvider);
    ref.invalidate(activeTourControllerProvider);
    ref.invalidate(archivedActiveJourneysProvider);
    invalidatePrivateExperienceFromWidget(ref);
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 62,
        leading: Icon(icon, color: AppColors.moss),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
