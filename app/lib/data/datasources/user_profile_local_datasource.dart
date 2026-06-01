import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:rural_tourism_app/core/errors/failure.dart';
import 'package:rural_tourism_app/core/storage/hive_storage_service.dart';
import 'package:rural_tourism_app/domain/entities/user_interaction.dart';
import 'package:rural_tourism_app/domain/entities/user_profile.dart';

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
      await HiveStorageService.instance.saveUserInteraction(interaction);
      return Ok(null);
    } catch (e) {
      return Err(StorageFailure('Failed to insert interaction: $e'));
    }
  }

  Future<Result<int>> getInteractionCount() async {
    try {
      return Ok(await HiveStorageService.instance.getUserInteractionCount());
    } catch (e) {
      return Err(StorageFailure('Failed to count interactions: $e'));
    }
  }
}
