import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/app_constants.dart';
import '../data/datasources/user_profile_local_datasource.dart';
import '../domain/entities/recommendation_result.dart';
import '../models/destination.dart';
import '../models/user_preferences.dart';

class LocalDataService {
  LocalDataService._();

  static final LocalDataService instance = LocalDataService._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    _db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_destinations(
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            saved_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE recommendation_cache(
            cache_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            generated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE app_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_type TEXT NOT NULL,
            payload TEXT,
            created_at INTEGER NOT NULL
          )
        ''');

        await UserProfileLocalDatasource.runMigrations(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await UserProfileLocalDatasource.runMigrations(
          db,
          oldVersion,
          newVersion,
        );
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('LocalDataService not initialized. Call init() first.');
    }
    return db;
  }

  Database get database => _database;

  String buildRecommendationCacheKey(
    UserPreferences prefs, {
    Destination? seed,
  }) {
    return [
      prefs.activity.trim().toLowerCase(),
      prefs.budget.trim().toLowerCase(),
      prefs.season.trim().toLowerCase(),
      prefs.vibe.trim().toLowerCase(),
      seed?.id.trim().toLowerCase() ?? 'no-seed',
    ].join('|');
  }

  Future<void> saveDestination(Destination destination) async {
    await init();

    await _database.insert(
      'saved_destinations',
      {
        'id': destination.id,
        'payload': jsonEncode(destination.toJson()),
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await logEvent('saved_destination_added', {
      'destination_id': destination.id,
      'destination_name': destination.name,
    });
  }

  Future<void> removeSavedDestination(String destinationId) async {
    await init();

    await _database.delete(
      'saved_destinations',
      where: 'id = ?',
      whereArgs: [destinationId],
    );

    await logEvent('saved_destination_removed', {
      'destination_id': destinationId,
    });
  }

  Future<List<Destination>> getSavedDestinations() async {
    await init();

    final rows = await _database.query(
      'saved_destinations',
      orderBy: 'saved_at DESC',
    );

    return rows.map((row) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return Destination.fromJson(payload);
    }).toList();
  }

  Future<bool> isSaved(String destinationId) async {
    await init();

    final rows = await _database.query(
      'saved_destinations',
      where: 'id = ?',
      whereArgs: [destinationId],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<void> cacheRecommendations(
    String cacheKey,
    List<RecommendationResult> results,
  ) async {
    await init();

    final payload = results
        .map((r) => {
              'score': r.score,
              'reasons': r.reasons,
              'destination': r.destination.toJson(),
            })
        .toList();

    await _database.insert(
      'recommendation_cache',
      {
        'cache_key': cacheKey,
        'payload': jsonEncode(payload),
        'generated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RecommendationResult>> getCachedRecommendations(
    String cacheKey,
  ) async {
    await init();

    final rows = await _database.query(
      'recommendation_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (rows.isEmpty) return [];

    final payload = jsonDecode(rows.first['payload'] as String) as List;

    return payload.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      return RecommendationResult(
        destination: Destination.fromJson(
          Map<String, dynamic>.from(map['destination'] as Map),
        ),
        score: (map['score'] as num).toDouble(),
        reasons: (map['reasons'] as List).map((e) => e.toString()).toList(),
      );
    }).toList();
  }

  Future<void> logEvent(String eventType, Map<String, dynamic> payload) async {
    await init();

    await _database.insert(
      'app_events',
      {
        'event_type': eventType,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}