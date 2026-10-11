import 'dart:io';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';
import '../domain/community_models.dart';

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

/// Private, account- and API-scoped local trip wallet. No OSS/public media upload.
class TravelPlanStore {
  TravelPlanStore(this.root, this.database);
  final Directory root;
  final Database database;
  static Future<TravelPlanStore> open(Directory support, String scope,
      {DatabaseFactory? factory}) async {
    final key = sha256.convert(utf8.encode(scope)).toString();
    final dir = Directory(path.join(support.path, 'travel-wallet', key));
    await dir.create(recursive: true);
    final db = await (factory ?? databaseFactory)
        .openDatabase(path.join(dir.path, 'wallet.db'),
            options: OpenDatabaseOptions(
                version: 2,
                onUpgrade: (db, old, _) async {
                  if (old < 2) await _createGuides(db);
                },
                onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
                onCreate: (db, _) async {
                  await db.execute(
                      'CREATE TABLE plans (id TEXT PRIMARY KEY, slug TEXT NOT NULL, title TEXT NOT NULL, city TEXT NOT NULL, image TEXT NOT NULL, visit_date TEXT, added_at TEXT NOT NULL)');
                  await db.execute(
                      'CREATE TABLE receipts (id TEXT PRIMARY KEY, route_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE, name TEXT NOT NULL, file_name TEXT NOT NULL, kind TEXT NOT NULL, added_at TEXT NOT NULL)');
                  await _createGuides(db);
                }));
    return TravelPlanStore(dir, db);
  }

  static Future<void> _createGuides(Database db) async {
    await db.execute(
        'CREATE TABLE guide_imports (post_id TEXT NOT NULL, route_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE, title TEXT NOT NULL, author TEXT NOT NULL, PRIMARY KEY (route_id, post_id))');
    await db.execute(
        'CREATE TABLE preparation_tasks (id TEXT PRIMARY KEY, route_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE, post_id TEXT, title TEXT NOT NULL, body TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL)');
  }

  Future<void> importGuide(RouteExperience route, CommunityPost post) async {
    if (post.category != CommunityCategory.guide ||
        post.preparationItems.isEmpty ||
        post.place?.routeSlug != route.slug) {
      throw const FormatException('攻略地点不匹配');
    }
    await add(route);
    await database.transaction((tx) async {
      final existing = await tx.query('guide_imports',
          where: 'route_id = ? AND post_id = ?',
          whereArgs: [route.id, post.id]);
      if (existing.isNotEmpty) return;
      await tx.insert('guide_imports', {
        'route_id': route.id,
        'post_id': post.id,
        'title': post.title ?? '攻略',
        'author': post.author.displayName
      });
      for (var i = 0; i < post.preparationItems.length; i++) {
        final item = post.preparationItems[i];
        await tx.insert('preparation_tasks', {
          'id': const Uuid().v4(),
          'route_id': route.id,
          'post_id': post.id,
          'title': item.title,
          'body': item.body,
          'position': i
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> guides(String id) =>
      database.query('guide_imports',
          where: 'route_id = ?', whereArgs: [id], orderBy: 'rowid');
  Future<List<Map<String, Object?>>> tasks(String id) =>
      database.query('preparation_tasks',
          where: 'route_id = ?', whereArgs: [id], orderBy: 'rowid');
  Future<void> checkTask(String id, bool done) async {
    await database.update('preparation_tasks', {'done': done ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addTask(String routeId, String title) async {
    title = title.trim();
    if (title.isEmpty || title.length > 60) {
      throw const FormatException('准备项为 1 至 60 字');
    }
    await database.insert('preparation_tasks', {
      'id': const Uuid().v4(),
      'route_id': routeId,
      'title': title,
      'body': '',
      'position': 0
    });
  }

  Future<void> removeTask(String id) async {
    await database
        .delete('preparation_tasks', where: 'id = ?', whereArgs: [id]);
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

  Future<void> removePlan(String id) async {
    // Preserve legacy files until the owner explicitly removes their trip.
    for (final row in await database
        .query('receipts', where: 'route_id = ?', whereArgs: [id])) {
      final name = row['file_name'] as String;
      if (path.basename(name) == name) {
        final file = File(path.join(root.path, name));
        if (await file.exists()) await file.delete();
      }
    }
    await database.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() => database.close();
}
