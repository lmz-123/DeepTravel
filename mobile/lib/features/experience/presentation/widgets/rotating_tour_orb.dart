import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/user_preferences_repository.dart';
import '../active_tour_controller.dart';
import '../experience_providers.dart';
import '../location_mode_controller.dart';

class RotatingTourOrbOverlay extends ConsumerStatefulWidget {
  const RotatingTourOrbOverlay({super.key});

  @override
  ConsumerState<RotatingTourOrbOverlay> createState() =>
      _RotatingTourOrbOverlayState();
}

class _RotatingTourOrbOverlayState extends ConsumerState<RotatingTourOrbOverlay>
    with SingleTickerProviderStateMixin {
  static const _hitSize = Size.square(72);
  late final AnimationController _rotation;
  NormalizedOrbPosition? _position;
  String? _loadedUserId;
  bool _rotationScheduled = false;
  bool _isDragging = false;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeTourControllerProvider);
    final userId = ref.watch(currentUserIdProvider);
    final visible = userId != null &&
        state.route != null &&
        state.session != null &&
        state.current != null &&
        state.status != 'idle' &&
        state.status != 'stopped';
    if (!visible) return const SizedBox.shrink();
    final stored = ref.watch(orbPositionProvider(userId)).value;
    if (_loadedUserId != userId) {
      _loadedUserId = userId;
      _position = _edgePosition(stored ?? const NormalizedOrbPosition(1, .72));
    } else {
      _position ??=
          _edgePosition(stored ?? const NormalizedOrbPosition(1, .72));
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final rotating = state.isPlaying && !reducedMotion;
    _syncRotation(rotating);
    final durationMs = state.duration?.inMilliseconds ?? 0;
    final progress = durationMs <= 0
        ? 0.0
        : (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, constraints) {
      final mediaPadding = MediaQuery.paddingOf(context);
      final origin = Offset(8, mediaPadding.top + 8);
      final available = Size(
        (constraints.maxWidth - 16).clamp(0, double.infinity),
        (constraints.maxHeight - mediaPadding.top - mediaPadding.bottom - 16)
            .clamp(0, double.infinity),
      );
      final normalized =
          (_position ?? const NormalizedOrbPosition(1, .72)).clamped();
      final offset = origin + normalized.resolve(available, _hitSize);
      return Stack(
        children: [
          AnimatedPositioned(
            left: offset.dx,
            top: offset.dy,
            width: _hitSize.width,
            height: _hitSize.height,
            duration:
                _isDragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Semantics(
              button: true,
              label:
                  '${state.isPlaying ? '正在播放' : '已暂停'} ${state.route!.title}，${state.current!.title ?? '第 ${state.current!.position} 条线索'}',
              hint: '双击回到当前旅程；也可以上下拖动并吸附到左右侧边',
              customSemanticsActions: {
                const CustomSemanticsAction(label: '向左移动'): () =>
                    _move(const Offset(-.08, 0), userId),
                const CustomSemanticsAction(label: '向右移动'): () =>
                    _move(const Offset(.08, 0), userId),
                const CustomSemanticsAction(label: '向上移动'): () =>
                    _move(const Offset(0, -.08), userId),
                const CustomSemanticsAction(label: '向下移动'): () =>
                    _move(const Offset(0, .08), userId),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/journey/${state.session!.id}'),
                onPanStart: (_) {
                  _isDragging = true;
                  _dragOffset = offset;
                },
                onPanUpdate: (details) {
                  final next = (_dragOffset ?? offset) + details.delta;
                  _dragOffset = next;
                  setState(() {
                    _position = NormalizedOrbPosition.fromOffset(
                      next - origin,
                      available,
                      _hitSize,
                    );
                  });
                },
                onPanEnd: (_) => _finishDrag(userId),
                onPanCancel: () => _finishDrag(userId),
                child: Center(
                  child: TickerMode(
                    enabled: rotating,
                    child: AnimatedBuilder(
                      animation: _rotation,
                      builder: (context, child) => Transform.rotate(
                        angle: rotating ? _rotation.value * math.pi * 2 : 0,
                        child: child,
                      ),
                      child: CustomPaint(
                        foregroundPainter: _OrbProgressPainter(progress),
                        child: _VinylDisc(artwork: state.route!.heroImage),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _syncRotation(bool shouldRotate) {
    if (_rotationScheduled == shouldRotate) return;
    _rotationScheduled = shouldRotate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_rotationScheduled) {
        _rotation.repeat();
      } else {
        _rotation.stop(canceled: false);
      }
    });
  }

  void _move(Offset delta, String userId) {
    final current = _position ?? const NormalizedOrbPosition(1, .72);
    setState(() {
      _position = NormalizedOrbPosition(
        delta.dx == 0 ? current.x : (delta.dx < 0 ? 0 : 1),
        current.y + delta.dy,
      ).clamped();
    });
    _persist(userId);
  }

  void _finishDrag(String userId) {
    final current = _position ?? const NormalizedOrbPosition(1, .72);
    setState(() {
      _isDragging = false;
      _dragOffset = null;
      _position = NormalizedOrbPosition(current.x < .5 ? 0 : 1, current.y);
    });
    _persist(userId);
  }

  NormalizedOrbPosition _edgePosition(NormalizedOrbPosition value) =>
      NormalizedOrbPosition(value.x < .5 ? 0 : 1, value.y).clamped();

  Future<void> _persist(String userId) async {
    final value = _position;
    if (value == null) return;
    await ref
        .read(userPreferencesRepositoryProvider)
        .writeOrbPosition(userId, value);
    ref.invalidate(orbPositionProvider(userId));
  }
}

class _VinylDisc extends StatelessWidget {
  const _VinylDisc({required this.artwork});

  final String artwork;

  @override
  Widget build(BuildContext context) => Container(
        width: 62,
        height: 62,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.ink,
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
          gradient: const RadialGradient(
            colors: [Color(0xFF4A474A), Color(0xFF18161A), Color(0xFF050506)],
            stops: [.08, .55, 1],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: artwork.isEmpty
              ? const ColoredBox(
                  color: AppColors.terracotta,
                  child: Icon(Icons.headphones_rounded,
                      color: AppColors.white, size: 22),
                )
              : Image.network(
                  artwork,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.terracotta,
                    child: Icon(Icons.headphones_rounded,
                        color: AppColors.white, size: 22),
                  ),
                ),
        ),
      );
}

class _OrbProgressPainter extends CustomPainter {
  const _OrbProgressPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.white.withValues(alpha: .8),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(_OrbProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
