import 'package:flutter_riverpod/legacy.dart';

class RecommendationPrefsState {
  final String activity;
  final String budget;
  final String season;
  final String vibe;
  final bool familyFriendly;
  final int adventureLevel;
  final bool showOnlySaved;

  const RecommendationPrefsState({
    this.activity = 'trekking',
    this.budget = 'medium',
    this.season = 'spring',
    this.vibe = 'cultural',
    this.familyFriendly = false,
    this.adventureLevel = 3,
    this.showOnlySaved = false,
  });

  RecommendationPrefsState copyWith({
    String? activity,
    String? budget,
    String? season,
    String? vibe,
    bool? familyFriendly,
    int? adventureLevel,
    bool? showOnlySaved,
  }) {
    return RecommendationPrefsState(
      activity: activity ?? this.activity,
      budget: budget ?? this.budget,
      season: season ?? this.season,
      vibe: vibe ?? this.vibe,
      familyFriendly: familyFriendly ?? this.familyFriendly,
      adventureLevel: adventureLevel ?? this.adventureLevel,
      showOnlySaved: showOnlySaved ?? this.showOnlySaved,
    );
  }
}

class UserPrefsNotifier extends StateNotifier<RecommendationPrefsState> {
  UserPrefsNotifier() : super(const RecommendationPrefsState());

  void setActivity(String value) {
    state = state.copyWith(activity: value);
  }

  void setBudget(String value) {
    state = state.copyWith(budget: value);
  }

  void setSeason(String value) {
    state = state.copyWith(season: value);
  }

  void setVibe(String value) {
    state = state.copyWith(vibe: value);
  }

  void setFamilyFriendly(bool value) {
    state = state.copyWith(familyFriendly: value);
  }

  void setAdventureLevel(int value) {
    state = state.copyWith(adventureLevel: value);
  }

  void setShowOnlySaved(bool value) {
    state = state.copyWith(showOnlySaved: value);
  }
}

final userPrefsProvider =
    StateNotifierProvider<UserPrefsNotifier, RecommendationPrefsState>(
  (ref) => UserPrefsNotifier(),
);
