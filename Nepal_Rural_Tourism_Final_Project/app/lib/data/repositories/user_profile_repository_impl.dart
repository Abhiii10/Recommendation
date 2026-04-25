import '../../core/errors/failure.dart';
import '../../core/utils/app_constants.dart';
import '../../domain/entities/user_interaction.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_local_datasource.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileLocalDatasource _datasource;

  const UserProfileRepositoryImpl(this._datasource);

  @override
  Future<Result<UserProfile>> getProfile() => _datasource.getProfile();

  @override
  Future<Result<void>> saveProfile(UserProfile profile) =>
      _datasource.saveProfile(profile);

  @override
  Future<Result<UserProfile>> recordInteraction(
    UserInteraction interaction,
  ) async {
    final insertResult = await _datasource.insertInteraction(interaction);
    if (insertResult is Err<void>) {
      return Err(insertResult.failure);
    }

    final profileResult = await _datasource.getProfile();
    if (profileResult is Err<UserProfile>) {
      return profileResult;
    }

    final profile = (profileResult as Ok<UserProfile>).value;

    final double weight;
    switch (interaction.type) {
      case InteractionType.click:
        weight = AppConstants.clickWeight;
        break;
      case InteractionType.bookmark:
        weight = AppConstants.bookmarkWeight;
        break;
      case InteractionType.dwell:
        weight = AppConstants.dwellWeight;
        break;
    }

    final catMap = Map<String, double>.from(profile.categoryAffinity);
    for (final cat in interaction.categories) {
      catMap[cat.toLowerCase()] = (catMap[cat.toLowerCase()] ?? 0.0) + weight;
    }

    final tagMap = Map<String, double>.from(profile.tagAffinity);
    for (final tag in interaction.tags) {
      tagMap[tag.toLowerCase()] = (tagMap[tag.toLowerCase()] ?? 0.0) + weight;
    }

    final updated = UserProfile(
      categoryAffinity: catMap,
      tagAffinity: tagMap,
      interactionCount: profile.interactionCount + 1,
    );

    final saveResult = await _datasource.saveProfile(updated);
    if (saveResult is Err<void>) {
      return Err(saveResult.failure);
    }

    return Ok(updated);
  }

  @override
  Future<Result<UserProfile>> applyDecay() async {
    final profileResult = await _datasource.getProfile();
    if (profileResult is Err<UserProfile>) return profileResult;

    final profile = (profileResult as Ok<UserProfile>).value;
    const decay = AppConstants.affinityDecayFactor;

    final decayed = UserProfile(
      categoryAffinity: {
        for (final e in profile.categoryAffinity.entries)
          e.key: e.value * decay,
      },
      tagAffinity: {
        for (final e in profile.tagAffinity.entries)
          e.key: e.value * decay,
      },
      interactionCount: profile.interactionCount,
    );

    final saveResult = await _datasource.saveProfile(decayed);
    if (saveResult is Err<void>) {
      return Err(saveResult.failure);
    }

    return Ok(decayed);
  }

  @override
  Future<Result<int>> getInteractionCount() =>
      _datasource.getInteractionCount();
}