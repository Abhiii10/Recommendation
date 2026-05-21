import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/failure.dart';
import '../../core/utils/app_constants.dart';
import '../../domain/entities/user_interaction.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

class SharedPreferencesUserProfileRepository implements UserProfileRepository {
  static const String _profileKey = 'web_user_profile';
  static const String _interactionCountKey = 'web_user_interaction_count';

  const SharedPreferencesUserProfileRepository();

  @override
  Future<Result<UserProfile>> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);

      if (raw == null || raw.isEmpty) {
        return Ok(UserProfile.empty());
      }

      return Ok(UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (error) {
      return Err(StorageFailure('Failed to load web user profile: $error'));
    }
  }

  @override
  Future<Result<void>> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
      await prefs.setInt(_interactionCountKey, profile.interactionCount);
      return Ok(null);
    } catch (error) {
      return Err(StorageFailure('Failed to save web user profile: $error'));
    }
  }

  @override
  Future<Result<UserProfile>> recordInteraction(
    UserInteraction interaction,
  ) async {
    final profileResult = await getProfile();
    if (profileResult is Err<UserProfile>) return profileResult;

    final profile = (profileResult as Ok<UserProfile>).value;
    final weight = switch (interaction.type) {
      InteractionType.click => AppConstants.clickWeight,
      InteractionType.bookmark => AppConstants.bookmarkWeight,
      InteractionType.dwell => AppConstants.dwellWeight,
    };

    final categoryAffinity = Map<String, double>.from(
      profile.categoryAffinity,
    );
    final tagAffinity = Map<String, double>.from(profile.tagAffinity);

    for (final category in interaction.categories) {
      final key = category.toLowerCase();
      categoryAffinity[key] = (categoryAffinity[key] ?? 0.0) + weight;
    }

    for (final tag in interaction.tags) {
      final key = tag.toLowerCase();
      tagAffinity[key] = (tagAffinity[key] ?? 0.0) + weight;
    }

    final updated = UserProfile(
      categoryAffinity: categoryAffinity,
      tagAffinity: tagAffinity,
      interactionCount: profile.interactionCount + 1,
    );

    final saveResult = await saveProfile(updated);
    if (saveResult is Err<void>) return Err(saveResult.failure);

    return Ok(updated);
  }

  @override
  Future<Result<UserProfile>> applyDecay() async {
    final profileResult = await getProfile();
    if (profileResult is Err<UserProfile>) return profileResult;

    final profile = (profileResult as Ok<UserProfile>).value;
    const decay = AppConstants.affinityDecayFactor;

    final decayed = UserProfile(
      categoryAffinity: {
        for (final entry in profile.categoryAffinity.entries)
          entry.key: entry.value * decay,
      },
      tagAffinity: {
        for (final entry in profile.tagAffinity.entries)
          entry.key: entry.value * decay,
      },
      interactionCount: profile.interactionCount,
    );

    final saveResult = await saveProfile(decayed);
    if (saveResult is Err<void>) return Err(saveResult.failure);

    return Ok(decayed);
  }

  @override
  Future<Result<int>> getInteractionCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(prefs.getInt(_interactionCountKey) ?? 0);
    } catch (error) {
      return Err(StorageFailure('Failed to count web interactions: $error'));
    }
  }
}
