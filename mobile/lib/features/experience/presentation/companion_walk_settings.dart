import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/tour_runtime.dart';
import 'location_mode_controller.dart';
import 'offline_package_controller.dart';
import 'route_manual/manual_visuals.dart';

const _red = Color(0xFFBC4432);
const _rule = Color(0x35252824);

/// Preparing a walk does not start location tracking or audio. The caller owns
/// that transition, and only an explicit start confirmation returns true.
Future<bool> showCompanionWalkSettings(
  BuildContext context, {
  required RouteExperience route,
  bool startAfterPreparation = false,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: manualPaper,
      barrierColor: const Color(0x73252824),
      shape: const Border(top: BorderSide(color: Color(0x65252824))),
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 350),
              reverseDuration: Duration(milliseconds: 250),
            ),
      builder: (_) => _CompanionWalkSettings(
        route: route,
        startAfterPreparation: startAfterPreparation,
      ),
    ) ??
    false;

class CompanionWalkSettingsEntry extends ConsumerWidget {
  const CompanionWalkSettingsEntry({
    required this.route,
    this.enabled = true,
    super.key,
  });

  final RouteExperience route;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(locationModeControllerProvider);
    final summary = mode.when(
      data: (value) => value == TourLocationMode.real ? '真实行走' : '模拟预览',
      loading: () => '读取定位方式…',
      error: (_, __) => '定位方式待确认',
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('companion-walk-settings-entry'),
        onTap: enabled
            ? () => showCompanionWalkSettings(context, route: route)
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _rule)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('行走设置', style: manualType(13)),
                    const SizedBox(height: 3),
                    Text('$summary · 离线内容',
                        style: manualType(10, color: manualMuted)),
                  ],
                ),
              ),
              const Icon(Icons.north_east, size: 22, color: manualInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanionWalkSettings extends ConsumerStatefulWidget {
  const _CompanionWalkSettings({
    required this.route,
    required this.startAfterPreparation,
  });

  final RouteExperience route;
  final bool startAfterPreparation;

  @override
  ConsumerState<_CompanionWalkSettings> createState() =>
      _CompanionWalkSettingsState();
}

class _CompanionWalkSettingsState
    extends ConsumerState<_CompanionWalkSettings> {
  bool _savingMode = false;
  String? _modeError;

  Future<void> _selectMode(TourLocationMode next) async {
    if (_savingMode) return;
    setState(() {
      _savingMode = true;
      _modeError = null;
    });
    try {
      await ref.read(locationModeControllerProvider.notifier).setMode(next);
    } catch (_) {
      if (!mounted) return;
      // The controller updates optimistically. Reload the persisted choice
      // before allowing a walk to start after a failed write.
      ref.invalidate(locationModeControllerProvider);
      _modeError = '定位方式未保存，请重新选择后重试。';
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(locationModeControllerProvider);
    final packageKey = OfflinePackageKey(
      widget.route.slug,
      widget.route.audioTour?.scriptVersion,
    );
    final package = ref.watch(offlinePackageControllerProvider(packageKey));
    final downloading =
        package.asData?.value.phase == OfflinePackagePhase.downloading;
    final canFinish = !_savingMode &&
        mode.hasValue &&
        !mode.hasError &&
        !mode.isLoading &&
        _modeError == null &&
        (!widget.startAfterPreparation || !downloading);

    return PopScope(
      canPop: !_savingMode,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('companion-walk-settings-sheet'),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('BEFORE YOU GO', style: manualType(9, spacing: .8)),
                  IconButton(
                    tooltip: '关闭行走设置',
                    onPressed: _savingMode
                        ? null
                        : () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.close, size: 22, color: manualInk),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '准备好，\n再出发'),
                  TextSpan(text: '。', style: manualType(33, color: _red)),
                ]),
                style: manualType(33,
                    serif: true,
                    weight: FontWeight.w500,
                    height: 1.45,
                    spacing: -1),
              ),
              const SizedBox(height: 14),
              Text('把准备留在这里，把注意力留给街道。',
                  style: manualType(11, color: manualMuted, height: 1.9)),
              const SizedBox(height: 26),
              Text('定位方式', style: manualType(10, color: manualMuted)),
              const SizedBox(height: 8),
              _ModeOption(
                key: const ValueKey('companion-settings-mode-real'),
                label: '真实行走',
                description: '到现场，跟随实际位置发现故事',
                selected: mode.asData?.value == TourLocationMode.real,
                onTap: _savingMode || mode.isLoading
                    ? null
                    : () => _selectMode(TourLocationMode.real),
              ),
              _ModeOption(
                key: const ValueKey('companion-settings-mode-simulated'),
                label: '模拟预览',
                description: '出发前，先熟悉沿途的故事点',
                selected: mode.asData?.value == TourLocationMode.simulated,
                onTap: _savingMode || mode.isLoading
                    ? null
                    : () => _selectMode(TourLocationMode.simulated),
              ),
              if (_savingMode || mode.isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_savingMode ? '正在保存定位方式…' : '正在读取定位方式…',
                      style: manualType(10, color: manualMuted)),
                ),
              if (_modeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child:
                        Text(_modeError!, style: manualType(11, color: _red)),
                  ),
                ),
              if (mode.hasError)
                TextButton(
                  onPressed: () =>
                      ref.invalidate(locationModeControllerProvider),
                  style: TextButton.styleFrom(
                      foregroundColor: _red, padding: EdgeInsets.zero),
                  child: const Text('定位方式读取失败，点击重试'),
                ),
              if (widget.route.audioTour != null) ...[
                const SizedBox(height: 14),
                _OfflineContent(
                  package: package,
                  onRetryStatus: () => ref
                      .invalidate(offlinePackageControllerProvider(packageKey)),
                  onDownload: () => ref
                      .read(
                          offlinePackageControllerProvider(packageKey).notifier)
                      .download(widget.route),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 18),
              Material(
                color: manualInk,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('companion-settings-done'),
                  onTap: canFinish
                      ? () => Navigator.of(context)
                          .pop(widget.startAfterPreparation)
                      : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.startAfterPreparation
                                  ? downloading
                                      ? '离线内容准备中…'
                                      : '完成准备，开启随行'
                                  : '完成准备',
                              style: manualType(13,
                                  color: canFinish
                                      ? manualPaper
                                      : manualPaper.withValues(alpha: .5)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward,
                              size: 22, color: Color(0xFFE1E8B4)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _rule)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: manualType(18,
                              serif: true, weight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(description,
                          style: manualType(10, color: manualMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                ExcludeSemantics(
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: selected ? _red : manualMuted, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: _red),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _OfflineContent extends StatelessWidget {
  const _OfflineContent({
    required this.package,
    required this.onRetryStatus,
    required this.onDownload,
  });

  final AsyncValue<OfflinePackageStatus> package;
  final VoidCallback onRetryStatus;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final status = package.asData?.value;
    final downloading = status?.phase == OfflinePackagePhase.downloading;
    final String action;
    final String description;
    final VoidCallback? onTap;
    if (package.isLoading) {
      action = '读取中';
      description = '正在检查已下载的内容…';
      onTap = null;
    } else if (package.hasError) {
      action = '重试 ↻';
      description = '暂时无法读取离线内容，请重试';
      onTap = onRetryStatus;
    } else {
      action = switch (status!.phase) {
        OfflinePackagePhase.idle => '下载 ↓',
        OfflinePackagePhase.downloading =>
          status.total > 0 ? '${status.complete}/${status.total}' : '准备中…',
        OfflinePackagePhase.complete => '已准备 ✓',
        OfflinePackagePhase.stale => '更新 ↓',
        OfflinePackagePhase.failed => '重试下载 ↓',
      };
      description = status.message ??
          switch (status.phase) {
            OfflinePackagePhase.idle => '提前准备，路上少些等待',
            OfflinePackagePhase.downloading => '正在下载沿途的声音与故事',
            OfflinePackagePhase.complete => '离线内容已准备，路上可直接收听',
            OfflinePackagePhase.stale => '离线内容有新版本，请更新后使用',
            OfflinePackagePhase.failed => '下载未完成，请重试',
          };
      onTap = downloading || status.isUsable ? null : onDownload;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const ValueKey('companion-settings-offline'),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _rule)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('离线内容', style: manualType(13)),
                      const SizedBox(height: 5),
                      Semantics(
                        liveRegion: true,
                        child: Text(description,
                            style: manualType(10,
                                color: package.hasError ||
                                        status?.phase ==
                                            OfflinePackagePhase.failed
                                    ? _red
                                    : manualMuted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Text(action, style: manualType(12, color: _red)),
              ],
            ),
          ),
        ),
        if (downloading)
          LinearProgressIndicator(
            minHeight: 2,
            color: _red,
            backgroundColor: _rule,
            value: status!.total > 0
                ? (status.complete / status.total).clamp(0.0, 1.0)
                : null,
            semanticsLabel: '离线内容下载进度',
          ),
      ],
    );
  }
}
