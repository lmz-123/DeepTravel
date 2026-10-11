import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';

class TravelPlan {
  TravelPlan.fromMap(Map<String, Object?> row)
      : id = row['id'] as String,
        slug = row['slug'] as String,
        title = row['title'] as String,
        city = row['city'] as String,
        image = row['image'] as String,
        date = row['visit_date'] as String?;
  final String id, slug, title, city, image;
  final String? date;
}

class TravelReceipt {
  TravelReceipt.fromMap(Map<String, Object?> row)
      : id = row['id'] as String,
        routeId = row['route_id'] as String,
        name = row['name'] as String,
        fileName = row['file_name'] as String,
        kind = row['kind'] as String;
  final String id, routeId, name, fileName, kind;
}

/// Private, account- and API-scoped local trip wallet. No OSS/public media upload.
class TravelPlanStore {
  TravelPlanStore(this.root, this.database);
  final Directory root;
  final Database database;
  static const maxReceiptBytes = 15 * 1024 * 1024;
  static Future<TravelPlanStore> open(Directory support, String scope,
      {DatabaseFactory? factory}) async {
    final key = sha256.convert(utf8.encode(scope)).toString();
    final dir = Directory(path.join(support.path, 'travel-wallet', key));
    await dir.create(recursive: true);
    final db = await (factory ?? databaseFactory)
        .openDatabase(path.join(dir.path, 'wallet.db'),
            options: OpenDatabaseOptions(
                version: 1,
                onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
                onCreate: (db, _) async {
                  await db.execute(
                      'CREATE TABLE plans (id TEXT PRIMARY KEY, slug TEXT NOT NULL, title TEXT NOT NULL, city TEXT NOT NULL, image TEXT NOT NULL, visit_date TEXT, added_at TEXT NOT NULL)');
                  await db.execute(
                      'CREATE TABLE receipts (id TEXT PRIMARY KEY, route_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE, name TEXT NOT NULL, file_name TEXT NOT NULL, kind TEXT NOT NULL, added_at TEXT NOT NULL)');
                }));
    return TravelPlanStore(dir, db);
  }

  Future<List<TravelPlan>> plans() async =>
      (await database.query('plans', orderBy: 'added_at DESC'))
          .map(TravelPlan.fromMap)
          .toList();
  Future<TravelPlan?> plan(String id) async {
    final rows =
        await database.query('plans', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TravelPlan.fromMap(rows.first);
  }

  Future<void> add(RouteExperience route) async {
    await database.transaction((tx) async {
      final old =
          await tx.query('plans', where: 'id = ?', whereArgs: [route.id]);
      final values = {
        'slug': route.slug,
        'title': route.title,
        'city': route.cityName,
        'image': route.heroImage
      };
      if (old.isEmpty) {
        await tx.insert('plans', {
          ...values,
          'id': route.id,
          'added_at': DateTime.now().toIso8601String()
        });
      } else {
        await tx
            .update('plans', values, where: 'id = ?', whereArgs: [route.id]);
      }
    });
  }

  Future<void> setDate(String id, DateTime? date) async {
    await database.update(
        'plans',
        {
          'visit_date': date == null
              ? null
              : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<List<TravelReceipt>> receipts(String id) async =>
      (await database.query('receipts',
              where: 'route_id = ?', whereArgs: [id], orderBy: 'added_at DESC'))
          .map(TravelReceipt.fromMap)
          .toList();
  File file(TravelReceipt receipt) {
    if (path.basename(receipt.fileName) != receipt.fileName) {
      throw const FormatException('Invalid receipt path');
    }
    return File(path.join(root.path, receipt.fileName));
  }

  Future<void> importReceipt(String routeId, String name, File source) async {
    if (await source.length() > maxReceiptBytes) {
      throw const FormatException('票据不能超过 15 MB');
    }
    final bytes = await source.readAsBytes();
    if (bytes.length > maxReceiptBytes) {
      throw const FormatException('票据不能超过 15 MB');
    }
    final kind = receiptKind(bytes);
    if (kind == null) {
      throw const FormatException('请选择 JPG、PNG、WebP 图片或 PDF 文件');
    }
    final id = const Uuid().v4();
    final filename = '$id.$kind';
    final target = File(path.join(root.path, filename));
    await target.writeAsBytes(bytes, flush: true);
    try {
      await database.transaction((tx) async {
        final count = Sqflite.firstIntValue(await tx.rawQuery(
                'SELECT COUNT(*) FROM receipts WHERE route_id = ?',
                [routeId])) ??
            0;
        if (count >= 20) throw const FormatException('每个景点最多保存 20 份票据');
        await tx.insert('receipts', {
          'id': id,
          'route_id': routeId,
          'name': path
              .basename(name)
              .substring(0, path.basename(name).length.clamp(0, 120)),
          'file_name': filename,
          'kind': kind,
          'added_at': DateTime.now().toIso8601String()
        });
      });
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> removeReceipt(TravelReceipt receipt) async {
    final rows = await database.query('receipts',
        where: 'id = ? AND file_name = ?',
        whereArgs: [receipt.id, receipt.fileName]);
    if (rows.isEmpty) return;
    final target = file(receipt);
    if (await target.exists()) await target.delete();
    await database.delete('receipts', where: 'id = ?', whereArgs: [receipt.id]);
  }

  Future<void> removePlan(String id) async {
    for (final receipt in await receipts(id)) {
      await removeReceipt(receipt);
    }
    await database.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() => database.close();
}

String? receiptKind(Uint8List b) {
  bool starts(List<int> prefix) =>
      b.length >= prefix.length &&
      List.generate(prefix.length, (i) => b[i] == prefix[i]).every((v) => v);
  if (starts([0x25, 0x50, 0x44, 0x46, 0x2d])) return 'pdf';
  if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'png';
  if (starts([0xff, 0xd8, 0xff])) return 'jpg';
  if (b.length >= 12 &&
      String.fromCharCodes(b.take(4)) == 'RIFF' &&
      String.fromCharCodes(b.skip(8).take(4)) == 'WEBP') {
    return 'webp';
  }
  return null;
}
