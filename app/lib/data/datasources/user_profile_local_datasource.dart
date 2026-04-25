import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/user_interaction.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileLocalDatasource {
  final Database db;

  const UserProfileLocalDatasource(this.db);

  static Future<void> runMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_interactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          destination_id TEXT NOT NULL,
          interaction_type TEXT NOT NULL,
          categories TEXT NOT NULL,
          tags TEXT NOT NULL,
          timestamp_ms INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile_store (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  Future<Result<UserProfile>> getProfile() async {
    try {
      final rows = await db.query(
        'user_profile_store',
        where: 'key = ?',
        whereArgs: ['profile'],
      );

      if (rows.isEmpty) return Ok(UserProfile.empty());

      final json =
          jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;

      return Ok(UserProfile.fromJson(json));
    } catch (e) {
      return Err(StorageFailure('Failed to load user profile: $e'));
    }
  }

  Future<Result<void>> saveProfile(UserProfile profile) async {
    try {
      await db.insert(
        'user_profile_store',
        {'key': 'profile', 'value': jsonEncode(profile.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return Ok(null);
    } catch (e) {
      return Err(StorageFailure('Failed to save user profile: $e'));
    }
  }

  Future<Result<void>> insertInteraction(UserInteraction interaction) async {
    try {
      await db.insert('user_interactions', {
        'destination_id': interaction.destinationId,
        'interaction_type': interaction.type.name,
        'categories': jsonEncode(interaction.categories),
        'tags': jsonEncode(interaction.tags),
        'timestamp_ms': interaction.timestamp.millisecondsSinceEpoch,
      });
      return Ok(null);
    } catch (e) {
      return Err(StorageFailure('Failed to insert interaction: $e'));
    }
  }

  Future<Result<int>> getInteractionCount() async {
    try {
      final result =
          await db.rawQuery('SELECT COUNT(*) as cnt FROM user_interactions');
      final cnt = Sqflite.firstIntValue(result) ?? 0;
      return Ok(cnt);
    } catch (e) {
      return Err(StorageFailure('Failed to count interactions: $e'));
    }
  }
}