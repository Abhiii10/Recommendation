import '../core/errors/failure.dart';
import '../core/utils/app_constants.dart';
import '../domain/entities/user_interaction.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../models/destination.dart';

class UserProfileService {
  final UserProfileRepository _repository;

  UserProfile _cachedProfile = UserProfile.empty();
  bool _isWarm = false;

  UserProfileService(this._repository);

  Future<void> initOnLaunch() async {
    final Result<UserProfile> result = await _repository.applyDecay();

    result.fold(
      onOk: (profile) {
        _cachedProfile = profile;
        _isWarm = true;
      },
      onErr: (_) {
        _cachedProfile = UserProfile.empty();
        _isWarm = true;
      },
    );
  }

  UserProfile get profile => _cachedProfile;

  bool get isColdStart =>
      _cachedProfile.interactionCount < AppConstants.coldStartThreshold;

  Future<void> recordClick(Destination dest) async {
    await _record(dest, InteractionType.click);
  }

  Future<void> recordBookmark(Destination dest) async {
    await _record(dest, InteractionType.bookmark);
  }

  Future<void> recordDwell(Destination dest) async {
    await _record(dest, InteractionType.dwell);
  }

  Future<void> _record(Destination dest, InteractionType type) async {
    final interaction = UserInteraction(
      destinationId: dest.id,
      type: type,
      categories: dest.category,
      tags: dest.tags,
      timestamp: DateTime.now(),
    );

    final Result<UserProfile> result =
        await _repository.recordInteraction(interaction);

    result.fold(
      onOk: (profile) {
        _cachedProfile = profile;
      },
      onErr: (_) {},
    );
  }

  double affinityBoostFor(Destination dest) {
    if (!_isWarm || isColdStart) return 0.0;

    double raw = 0.0;

    for (final category in dest.category) {
      raw += _cachedProfile.categoryAffinity[category.toLowerCase()] ?? 0.0;
    }

    for (final tag in dest.tags) {
      raw += _cachedProfile.tagAffinity[tag.toLowerCase()] ?? 0.0;
    }

    final double maxPossible = _maxObservedAffinity();
    if (maxPossible <= 0) return 0.0;

    final double normalized = (raw / maxPossible).clamp(0.0, 1.0);
    return normalized * AppConstants.maxAffinityBoost;
  }

  double _maxObservedAffinity() {
    final double catMax = _cachedProfile.categoryAffinity.values.fold(
      0.0,
      (previous, value) => value > previous ? value : previous,
    );

    final double tagMax = _cachedProfile.tagAffinity.values.fold(
      0.0,
      (previous, value) => value > previous ? value : previous,
    );

    return (catMax * 3 + tagMax * 4).clamp(1.0, double.infinity);
  }
}