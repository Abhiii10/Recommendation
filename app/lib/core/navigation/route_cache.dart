import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:rural_tourism_app/core/navigation/models/route_result.dart';

const _routeCacheDatabaseName = 'route_cache.db';
const _routeCacheTable = 'cached_routes';
const _routeCacheMaxAge = Duration(days: 30);

class RouteCache {
  RouteCache._();

  static final RouteCache instance = RouteCache._();

  Database? _database;

  Future<RouteResult?> get(String key) async {
    try {
      final db = await _db;
      final rows = await db.query(
        _routeCacheTable,
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final cachedAt = rows.first['cached_at'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > _routeCacheMaxAge.inMilliseconds) {
        await db.delete(
          _routeCacheTable,
          where: 'key = ?',
          whereArgs: [key],
        );
        return null;
      }

      final data = rows.first['data'] as String?;
      if (data == null || data.isEmpty) return null;

      return RouteResult.fromJson(
        Map<String, dynamic>.from(jsonDecode(data) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String key, RouteResult result) async {
    try {
      final db = await _db;
      await db.insert(
        _routeCacheTable,
        {
          'key': key,
          'data': jsonEncode(result.toJson()),
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Route caching is best-effort; navigation should still continue.
    }
  }

  String buildKey(LatLng origin, LatLng destination, TravelMode mode) {
    return '${_coordinate(origin.latitude)},${_coordinate(origin.longitude)}'
        '->${_coordinate(destination.latitude)},${_coordinate(destination.longitude)}'
        '->${mode.name}';
  }

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;

    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, _routeCacheDatabaseName);
    final opened = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          '''
          CREATE TABLE $_routeCacheTable (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
          ''',
        );
      },
    );
    _database = opened;
    return opened;
  }

  String _coordinate(double value) => value.toStringAsFixed(6);
}
