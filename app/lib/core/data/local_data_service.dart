import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:rural_tourism_app/core/storage/database_factory_config.dart';
import 'package:rural_tourism_app/core/utils/app_constants.dart';
import 'package:rural_tourism_app/data/datasources/user_profile_local_datasource.dart';
import 'package:rural_tourism_app/domain/entities/recommendation_result.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart';

class LocalDataService {
  LocalDataService._();

  static final LocalDataService instance = LocalDataService._();
  static const String _webSavedDestinationsKey = 'web_saved_destinations';
  static const String _webEventsKey = 'web_app_events';
  static const String _webPendingBackendInteractionsKey =
      'web_pending_backend_interactions';
  static const String _webCachePrefix = 'web_recommendation_cache_';
  static const String _webCacheTimestampSuffix = '_generated_at';
  static const String _webReviewsPrefix = 'web_destination_reviews_';

  Database? _db;
  bool _ffiInitialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_db != null) return;

    _initDesktopDatabaseFactory();

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

        await _createDestinationReviewsTable(db);
        await _createPendingBackendInteractionsTable(db);
        await UserProfileLocalDatasource.runMigrations(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _createDestinationReviewsTable(db);
        }

        if (oldVersion < 4) {
          await _createPendingBackendInteractionsTable(db);
        }

        await UserProfileLocalDatasource.runMigrations(
          db,
          oldVersion,
          newVersion,
        );
      },
    );
  }

  Future<void> _createDestinationReviewsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS destination_reviews(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination_id TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5),
        review_text TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_destination_reviews_destination_id
      ON destination_reviews(destination_id)
    ''');
  }

  Future<void> _createPendingBackendInteractionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_backend_interactions(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        destination_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 1.0,
        timestamp TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_backend_interactions_created_at
      ON pending_backend_interactions(created_at)
    ''');
  }

  void _initDesktopDatabaseFactory() {
    if (_ffiInitialized) return;

    configureDatabaseFactoryForPlatform();
    _ffiInitialized = true;
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

    if (kIsWeb) {
      await _saveDestinationForWeb(destination);
      return;
    }

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

    if (kIsWeb) {
      await _removeSavedDestinationForWeb(destinationId);
      return;
    }

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

    if (kIsWeb) {
      return _getSavedDestinationsForWeb();
    }

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

    if (kIsWeb) {
      final saved = await _getSavedDestinationsForWeb();
      return saved.any((destination) => destination.id == destinationId);
    }

    final rows = await _database.query(
      'saved_destinations',
      where: 'id = ?',
      whereArgs: [destinationId],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<void> saveReview(String destId, int rating, String? text) async {
    await init();

    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Must be between 1 and 5.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final review = <String, dynamic>{
      'destination_id': destId,
      'rating': rating,
      'review_text': text?.trim().isEmpty == true ? null : text?.trim(),
      'created_at': now,
    };

    if (kIsWeb) {
      await _saveReviewForWeb(destId, review);
      return;
    }

    await _database.insert('destination_reviews', review);
  }

  Future<List<Map<String, dynamic>>> getReviews(String destId) async {
    await init();

    if (kIsWeb) {
      return _getReviewsForWeb(destId);
    }

    return _database.query(
      'destination_reviews',
      where: 'destination_id = ?',
      whereArgs: [destId],
      orderBy: 'created_at DESC',
    );
  }

  Future<double?> getAverageRating(String destId) async {
    await init();

    if (kIsWeb) {
      final reviews = await _getReviewsForWeb(destId);
      if (reviews.isEmpty) return null;

      final total = reviews.fold<double>(
        0,
        (sum, review) => sum + (review['rating'] as num).toDouble(),
      );
      return total / reviews.length;
    }

    final rows = await _database.rawQuery(
      '''
      SELECT AVG(rating) AS average_rating
      FROM destination_reviews
      WHERE destination_id = ?
      ''',
      [destId],
    );

    final value = rows.first['average_rating'];
    if (value == null) return null;

    return (value as num).toDouble();
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

    if (kIsWeb) {
      await cacheJsonPayload(cacheKey, payload);
      return;
    }

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

    if (kIsWeb) {
      final payload = await getCachedJsonList(cacheKey);
      if (payload == null) return [];
      return _decodeRecommendationResults(payload);
    }

    final rows = await _database.query(
      'recommendation_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (rows.isEmpty) return [];

    final payload = jsonDecode(rows.first['payload'] as String) as List;

    return _decodeRecommendationResults(payload);
  }

  Future<void> clearRecommendationCache() async {
    final db = database;
    await db.delete('recommendation_cache');
  }

  Future<void> enqueueBackendInteraction({
    required String userId,
    required String destinationId,
    required String eventType,
    double value = 1.0,
    String? timestamp,
  }) async {
    await init();

    final now = DateTime.now();
    final item = <String, dynamic>{
      'id':
          '${now.microsecondsSinceEpoch}_${userId}_${destinationId}_$eventType',
      'user_id': userId,
      'destination_id': destinationId,
      'event_type': eventType,
      'value': value,
      'timestamp': timestamp ?? now.toUtc().toIso8601String(),
      'created_at': now.millisecondsSinceEpoch,
      'attempts': 0,
    };

    if (kIsWeb) {
      await _enqueueBackendInteractionForWeb(item);
      return;
    }

    await _database.insert(
      'pending_backend_interactions',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingBackendInteractions({
    int limit = 50,
  }) async {
    await init();

    if (kIsWeb) {
      final items = await _getPendingBackendInteractionsForWeb();
      return items.take(limit).toList();
    }

    return _database.query(
      'pending_backend_interactions',
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<void> markBackendInteractionsSynced(List<String> ids) async {
    if (ids.isEmpty) return;

    await init();

    if (kIsWeb) {
      final idSet = ids.toSet();
      final items = await _getPendingBackendInteractionsForWeb();
      final remaining =
          items.where((item) => !idSet.contains(item['id'])).toList();
      await _savePendingBackendInteractionsForWeb(remaining);
      return;
    }

    final placeholders = List.filled(ids.length, '?').join(',');
    await _database.delete(
      'pending_backend_interactions',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> markBackendInteractionSyncAttempted(List<String> ids) async {
    if (ids.isEmpty) return;

    await init();

    if (kIsWeb) {
      final idSet = ids.toSet();
      final items = await _getPendingBackendInteractionsForWeb();
      final updated = items.map((item) {
        if (!idSet.contains(item['id'])) return item;
        return {
          ...item,
          'attempts': ((item['attempts'] as num?)?.toInt() ?? 0) + 1,
        };
      }).toList();
      await _savePendingBackendInteractionsForWeb(updated);
      return;
    }

    final placeholders = List.filled(ids.length, '?').join(',');
    await _database.rawUpdate(
      '''
      UPDATE pending_backend_interactions
      SET attempts = attempts + 1
      WHERE id IN ($placeholders)
      ''',
      ids,
    );
  }

  List<RecommendationResult> _decodeRecommendationResults(List payload) {
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

  Future<void> cacheJsonPayload(String cacheKey, Object payload) async {
    await init();

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webCachePrefix$cacheKey', jsonEncode(payload));
      await prefs.setInt(
        '$_webCachePrefix$cacheKey$_webCacheTimestampSuffix',
        DateTime.now().millisecondsSinceEpoch,
      );
      return;
    }

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

  Future<List<dynamic>?> getCachedJsonList(
    String cacheKey, {
    Duration? maxAge,
  }) async {
    await init();

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final generatedAt =
          prefs.getInt('$_webCachePrefix$cacheKey$_webCacheTimestampSuffix');

      if (maxAge != null && generatedAt == null) return null;

      if (maxAge != null && generatedAt != null) {
        final age = DateTime.now().millisecondsSinceEpoch - generatedAt;
        if (age > maxAge.inMilliseconds) {
          await prefs.remove('$_webCachePrefix$cacheKey');
          await prefs.remove(
            '$_webCachePrefix$cacheKey$_webCacheTimestampSuffix',
          );
          return null;
        }
      }

      final raw = prefs.getString('$_webCachePrefix$cacheKey');
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    }

    final rows = await _database.query(
      'recommendation_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    if (maxAge != null) {
      final generatedAt = rows.first['generated_at'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - generatedAt;
      if (age > maxAge.inMilliseconds) {
        await _database.delete(
          'recommendation_cache',
          where: 'cache_key = ?',
          whereArgs: [cacheKey],
        );
        return null;
      }
    }

    final decoded = jsonDecode(rows.first['payload'] as String);
    return decoded is List ? decoded : null;
  }

  Future<void> _saveDestinationForWeb(Destination destination) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await _getSavedDestinationsForWeb();

    saved.removeWhere((item) => item.id == destination.id);
    saved.insert(0, destination);

    await prefs.setString(
      _webSavedDestinationsKey,
      jsonEncode(saved.map((item) => item.toJson()).toList()),
    );

    await logEvent('saved_destination_added', {
      'destination_id': destination.id,
      'destination_name': destination.name,
    });
  }

  Future<void> _removeSavedDestinationForWeb(String destinationId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await _getSavedDestinationsForWeb();

    saved.removeWhere((item) => item.id == destinationId);

    await prefs.setString(
      _webSavedDestinationsKey,
      jsonEncode(saved.map((item) => item.toJson()).toList()),
    );

    await logEvent('saved_destination_removed', {
      'destination_id': destinationId,
    });
  }

  Future<List<Destination>> _getSavedDestinationsForWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webSavedDestinationsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (entry) => Destination.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveReviewForWeb(
    String destId,
    Map<String, dynamic> review,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final reviews = await _getReviewsForWeb(destId);
    reviews.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch,
      ...review,
    });

    await prefs.setString(
      '$_webReviewsPrefix$destId',
      jsonEncode(reviews),
    );
  }

  Future<List<Map<String, dynamic>>> _getReviewsForWeb(String destId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_webReviewsPrefix$destId');

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueueBackendInteractionForWeb(
    Map<String, dynamic> item,
  ) async {
    final items = await _getPendingBackendInteractionsForWeb();
    items.removeWhere((existing) => existing['id'] == item['id']);
    items.add(item);
    await _savePendingBackendInteractionsForWeb(items);
  }

  Future<List<Map<String, dynamic>>>
      _getPendingBackendInteractionsForWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webPendingBackendInteractionsKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingBackendInteractionsForWeb(
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final limited =
        items.length > 500 ? items.sublist(items.length - 500) : items;
    await prefs.setString(
      _webPendingBackendInteractionsKey,
      jsonEncode(limited),
    );
  }

  Future<void> logEvent(String eventType, Map<String, dynamic> payload) async {
    await init();

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webEventsKey);
      final events = raw == null || raw.isEmpty
          ? <dynamic>[]
          : (jsonDecode(raw) as List<dynamic>);

      events.add({
        'event_type': eventType,
        'payload': payload,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      final limited =
          events.length > 200 ? events.sublist(events.length - 200) : events;

      await prefs.setString(_webEventsKey, jsonEncode(limited));
      return;
    }

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
