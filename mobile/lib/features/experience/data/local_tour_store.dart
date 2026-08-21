import 'dart:convert';

import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

import '../domain/tour_runtime.dart';

class SqliteTourStore implements TourStore {
  SqliteTourStore({this.databasePath});

  final String? databasePath;
  Database? _database;

  Future<Database> get _db async {
    if (_database case final database?) return database;
    final root = databasePath == null ? await getDatabasesPath() : null;
    _database = await openDatabase(
      databasePath ?? paths.join(root!, 'jiandi_tour.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE snapshots (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE outbox (id TEXT PRIMARY KEY, type TEXT NOT NULL, payload TEXT NOT NULL, state TEXT NOT NULL, created_at TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE prepared_assets (url TEXT PRIMARY KEY, path TEXT NOT NULL, version TEXT NOT NULL, size_bytes INTEGER NOT NULL)');
      },
    );
    return _database!;
  }

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    final db = await _db;
    await db.insert(
        'snapshots',
        {
          'key': key,
          'value': jsonEncode(value),
          'updated_at': DateTime.now().toUtc().toIso8601String()
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final rows = await (await _db)
        .query('snapshots', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
  }

  @override
  Future<void> enqueue(OutboxEvent event) async {
    await (await _db).insert(
        'outbox',
        {
          'id': event.id,
          'type': event.type,
          'payload': jsonEncode(event.payload),
          'state': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String()
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<OutboxEvent>> pending() async {
    final rows = await (await _db).query('outbox',
        where: 'state = ?', whereArgs: ['pending'], orderBy: 'created_at ASC');
    return rows
        .map((row) => OutboxEvent(
            id: row['id'] as String,
            type: row['type'] as String,
            payload:
                jsonDecode(row['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> acknowledge(String id) async =>
      (await _db).update('outbox', {'state': 'acknowledged'},
          where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> savePreparedAsset(
          String url, String path, String version, int sizeBytes) async =>
      (await _db).insert(
          'prepared_assets',
          {
            'url': url,
            'path': path,
            'version': version,
            'size_bytes': sizeBytes
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<String?> preparedAsset(
      String url, String version, int sizeBytes) async {
    final rows = await (await _db).query('prepared_assets',
        where: 'url = ? AND version = ? AND size_bytes = ?',
        whereArgs: [url, version, sizeBytes],
        limit: 1);
    return rows.isEmpty ? null : rows.first['path'] as String;
  }
}
