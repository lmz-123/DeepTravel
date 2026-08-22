import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fragment_models.dart';
import '../experience_providers.dart';

class NostalgicPhotoFrame extends StatelessWidget {
  const NostalgicPhotoFrame({
    required this.child,
    this.width,
    this.aspectRatio = 1,
    this.tilt = .012,
    super.key,
  });

  final Widget child;
  final double? width;
  final double aspectRatio;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Transform.rotate(
      angle: reduceMotion ? 0 : tilt,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: const _KeepsakeCollectionPainter(),
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D0BF),
                    border: Border.all(
                      color: const Color(0xFF695B43).withValues(alpha: .55),
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LocalPhotoThumbnail extends StatelessWidget {
  const LocalPhotoThumbnail({
    required this.path,
    required this.title,
    this.width = 132,
    super.key,
  });

  final String path;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '查看照片：$title',
        child: InkWell(
          onTap: () => showLocalEvidencePhoto(
            context,
            path: path,
            title: title,
          ),
          borderRadius: BorderRadius.circular(8),
          child: NostalgicPhotoFrame(
            width: width,
            tilt: -.01,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _UnavailablePhoto(),
            ),
          ),
        ),
      );
}

class EvidenceThumbnail extends ConsumerWidget {
  const EvidenceThumbnail({
    required this.userId,
    required this.journeyId,
    required this.evidence,
    required this.title,
    this.width = 132,
    super.key,
  });

  final String userId;
  final String journeyId;
  final EvidenceRecord evidence;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = EvidenceBytesKey(
      userId: userId,
      journeyId: journeyId,
      evidence: evidence,
    );
    final bytes = ref.watch(evidenceBytesProvider(key));
    return Semantics(
      button: true,
      label: '查看照片：$title',
      hint: evidence.isExpired ? '照片已经过期，可以重试确认' : '双击打开大图，可双指缩放',
      child: InkWell(
        onTap: () {
          final value = bytes.asData?.value;
          if (value != null && value.isNotEmpty) {
            showEvidencePhoto(
              context,
              bytes: value,
              title: title,
              capturedAt: evidence.capturedAt ?? evidence.uploadedAt,
            );
          } else {
            ref.invalidate(evidenceBytesProvider(key));
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: NostalgicPhotoFrame(
          width: width,
          tilt: _tiltFor(evidence.id),
          child: bytes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _UnavailablePhoto(expired: evidence.isExpired),
            data: (value) => value.isEmpty
                ? _UnavailablePhoto(expired: evidence.isExpired)
                : Image.memory(value, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }

  double _tiltFor(String seed) {
    final sign = seed.hashCode.isEven ? 1 : -1;
    return sign * (.006 + (seed.hashCode.abs() % 5) * .001);
  }
}

Future<void> showLocalEvidencePhoto(
  BuildContext context, {
  required String path,
  required String title,
}) =>
    _showPhotoViewer(
      context,
      title: title,
      image: Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _UnavailablePhoto(),
      ),
    );

Future<void> showEvidencePhoto(
  BuildContext context, {
  required List<int> bytes,
  required String title,
  DateTime? capturedAt,
}) =>
    _showPhotoViewer(
      context,
      title: title,
      capturedAt: capturedAt,
      image: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
    );

Future<void> _showPhotoViewer(
  BuildContext context, {
  required String title,
  required Widget image,
  DateTime? capturedAt,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: .94),
    builder: (context) => Dialog.fullscreen(
      backgroundColor: AppColors.ink,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '关闭照片',
                  color: AppColors.white,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Text(
                    '双指缩放',
                    style: TextStyle(color: AppColors.gold, fontSize: 12),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Semantics(
                label: '旅途照片大图，可双指缩放和拖动',
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1E7CF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: .55),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: image,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (capturedAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Text(
                  '留念于 ${_formatTime(capturedAt)}',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: .68),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _UnavailablePhoto extends StatelessWidget {
  const _UnavailablePhoto({this.expired = false});

  final bool expired;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: AppColors.moss),
              const SizedBox(height: 6),
              Text(
                expired ? '照片已过保存期\n轻触重试' : '照片暂时不可用\n轻触重试',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      );
}

class _KeepsakeCollectionPainter extends CustomPainter {
  const _KeepsakeCollectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(13),
    );
    canvas.drawShadow(
      Path()..addRRect(card),
      Colors.black.withValues(alpha: .32),
      10,
      true,
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFFF3E9D1));
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF7A6542).withValues(alpha: .5),
    );

    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xFFC19A52).withValues(alpha: .36),
    );

    final tape = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .76, 8),
        width: math.min(42, size.width * .25),
        height: 12,
      ),
      const Radius.circular(2),
    );
    canvas.save();
    canvas.translate(size.width * .76, 8);
    canvas.rotate(-.08);
    canvas.translate(-size.width * .76, -8);
    canvas.drawRRect(
      tape,
      Paint()..color = const Color(0xFFD7B66A).withValues(alpha: .58),
    );
    canvas.restore();

    final stampCenter = Offset(size.width - 24, size.height - 17);
    canvas.drawCircle(
      stampCenter,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.terracotta.withValues(alpha: .58),
    );
    canvas.drawLine(
      Offset(14, size.height - 16),
      Offset(size.width - 40, size.height - 16),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFF8A7148).withValues(alpha: .3),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
