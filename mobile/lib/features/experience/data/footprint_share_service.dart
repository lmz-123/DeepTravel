import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../domain/footprint_models.dart';

abstract interface class FootprintShareGateway {
  Future<void> share(String filePath, String text);
}

class PlatformFootprintShareGateway implements FootprintShareGateway {
  @override
  Future<void> share(String filePath, String text) => SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(filePath, mimeType: 'image/png')],
        ),
      );
}

class FootprintShareCardRenderer {
  const FootprintShareCardRenderer();

  Future<Uint8List> render(
    FootprintEntry entry, {
    Uint8List? explicitlyIncludedPhoto,
  }) async {
    const width = 1080.0;
    const height = 1440.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = const ui.Color(0xFFF4EFE3),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, width, 350),
      ui.Paint()..color = const ui.Color(0xFF24352F),
    );
    if (explicitlyIncludedPhoto != null) {
      final codec = await ui.instantiateImageCodec(explicitlyIncludedPhoto);
      final frame = await codec.getNextFrame();
      final source = ui.Rect.fromLTWH(
          0, 0, frame.image.width.toDouble(), frame.image.height.toDouble());
      const target = ui.Rect.fromLTWH(0, 0, width, 500);
      canvas.drawImageRect(frame.image, source, target, ui.Paint());
      canvas.drawRect(
        target,
        ui.Paint()..color = const ui.Color(0x66000000),
      );
    }
    _paragraph(canvas, '见地 · JIAN·DI', 72, 76, 780,
        size: 34,
        color: const ui.Color(0xFFF2C66D),
        weight: ui.FontWeight.w600);
    _paragraph(canvas, entry.cityName, 72, 144, 850,
        size: 82,
        color: const ui.Color(0xFFFFFFFF),
        weight: ui.FontWeight.w700);
    _paragraph(canvas, entry.sceneTitle, 72, 250, 850,
        size: 36, color: const ui.Color(0xFFE8E2D5));
    var top = explicitlyIncludedPhoto == null ? 430.0 : 570.0;
    _paragraph(canvas, entry.storyTitle, 72, top, 930,
        size: 52,
        color: const ui.Color(0xFF1D2924),
        weight: ui.FontWeight.w700);
    top += 105;
    _paragraph(canvas, '见地讲述', 72, top, 930,
        size: 28,
        color: const ui.Color(0xFF7A5A21),
        weight: ui.FontWeight.w700);
    top += 52;
    top += _paragraph(canvas, entry.editorialSummary, 72, top, 930,
        size: 38, color: const ui.Color(0xFF313630), lineHeight: 1.45);
    final personal = [
      entry.selectedSummaryText,
      entry.observation,
      entry.sentence,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join('\n');
    if (personal.isNotEmpty && top < 1220) {
      top += 42;
      _paragraph(canvas, '我留下的', 72, top, 930,
          size: 28,
          color: const ui.Color(0xFF7A5A21),
          weight: ui.FontWeight.w700);
      top += 52;
      _paragraph(canvas, personal, 72, top, 930,
          size: 34, color: const ui.Color(0xFF424740), lineHeight: 1.4);
    }
    _paragraph(canvas, '由我主动分享 · 私人足迹默认不公开', 72, 1360, 930,
        size: 25, color: const ui.Color(0xFF746F66));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('足迹卡生成失败');
    return data.buffer.asUint8List();
  }

  double _paragraph(
    ui.Canvas canvas,
    String text,
    double left,
    double top,
    double width, {
    required double size,
    required ui.Color color,
    ui.FontWeight weight = ui.FontWeight.w400,
    double lineHeight = 1.2,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
      maxLines: 7,
      ellipsis: '…',
    ))
      ..pushStyle(
          ui.TextStyle(color: color, fontSize: size, fontWeight: weight))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, ui.Offset(left, top));
    return paragraph.height;
  }
}

class FootprintShareService {
  FootprintShareService(
    this.renderer,
    this.gateway, {
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final FootprintShareCardRenderer renderer;
  final FootprintShareGateway gateway;
  final Future<Directory> Function() _temporaryDirectory;

  Future<void> share(
    FootprintEntry entry, {
    Uint8List? explicitlyIncludedPhoto,
  }) async {
    final bytes = await renderer.render(
      entry,
      explicitlyIncludedPhoto: explicitlyIncludedPhoto,
    );
    final directory = await _temporaryDirectory();
    await cleanup(directory: directory);
    final file = File(p.join(
      directory.path,
      'jiandi-footprint-${entry.id}-${const Uuid().v4()}.png',
    ));
    try {
      await file.writeAsBytes(bytes, flush: true);
      await gateway.share(file.path, '我在${entry.cityName}留下了一条见地足迹');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> cleanup({Directory? directory}) async {
    final target = directory ?? await _temporaryDirectory();
    if (!await target.exists()) return;
    await for (final candidate in target.list()) {
      if (candidate is! File ||
          !p.basename(candidate.path).startsWith('jiandi-footprint-')) {
        continue;
      }
      try {
        await candidate.delete();
      } catch (_) {
        // The operating system may still hold a share-sheet attachment.
      }
    }
  }
}

final footprintShareGatewayProvider =
    Provider<FootprintShareGateway>((ref) => PlatformFootprintShareGateway());
final footprintShareServiceProvider = Provider<FootprintShareService>((ref) =>
    FootprintShareService(const FootprintShareCardRenderer(),
        ref.watch(footprintShareGatewayProvider)));
