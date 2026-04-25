import '../../core/errors/failure.dart';
import '../entities/user_interaction.dart';
import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<Result<UserProfile>> getProfile();
  Future<Result<void>> saveProfile(UserProfile profile);
  Future<Result<UserProfile>> recordInteraction(UserInteraction interaction);
  Future<Result<UserProfile>> applyDecay();
  Future<Result<int>> getInteractionCount();
}