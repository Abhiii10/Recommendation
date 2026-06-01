import 'dart:math';

import 'package:rural_tourism_app/core/utils/app_constants.dart';
import 'package:rural_tourism_app/domain/entities/recommendation_result.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/recommendation_components.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/destination_affinity_provider.dart';

export 'package:rural_tourism_app/domain/entities/recommendation_result.dart';

const double _embeddingScoreWeight = 0.70;
const double _contextualScoreWeight = 0.30;
const double _querySeedThreshold = 0.18;
const double _diversityScoreTolerance = 0.020;
const int _candidateMultiplier = 8;

class RecommenderService {
  final Map<String, List<Map<String, dynamic>>> similarPlaces;
  final DestinationAffinityProvider? userProfileService;
  final Map<String, List<double>> destinationEmbeddings;

  RecommenderService(
    this.similarPlaces, {
    this.userProfileService,
    Map<String, List<double>> destinationEmbeddings = const {},
  }) : destinationEmbeddings = Map.unmodifiable(destinationEmbeddings);

  List<RecommendationResult> recommendByPreferences(
    UserPreferences prefs,
    List<Destination> destinations, {
    List<Accommodation> accommodations = const [],
    bool? familyFriendly,
    int? adventureLevel,
    int topK = 10,
  }) {
    if (destinations.isEmpty) {
      return [];
    }

    final accommodationsByDestination =
        _accommodationsByDestination(accommodations);
    final queryEmbeddingVector = _queryEmbeddingVector(
      prefs,
      destinations,
      accommodationsByDestination,
      familyFriendly: familyFriendly,
      adventureLevel: adventureLevel,
    );

    final candidates = <_CandidateScore>[];

    for (final destination in destinations) {
      final components = _contextualComponents(
        destination: destination,
        prefs: prefs,
        familyFriendly: familyFriendly,
        accommodationsByDestination: accommodationsByDestination,
      );
      final contextualScore = _contextualScore(components);
      final embeddingSimilarity = _semanticEmbeddingSimilarity(
        destination,
        queryEmbeddingVector,
      );
      final retrievalScore = _clamp(
        embeddingSimilarity * _embeddingScoreWeight +
            contextualScore * _contextualScoreWeight,
      );

      if (retrievalScore <= 0) {
        continue;
      }

      candidates.add(
        _CandidateScore(
          destination: destination,
          embeddingSimilarity: embeddingSimilarity,
          retrievalScore: retrievalScore,
          contextualScore: contextualScore,
          components: components,
        ),
      );
    }

    if (candidates.isEmpty) {
      return [];
    }

    candidates.sort((a, b) => b.retrievalScore.compareTo(a.retrievalScore));
    final stageOneLimit = min(
      candidates.length,
      max(AppConstants.offlineRetrieveTopK, topK * _candidateMultiplier),
    );
    final stageOne = candidates.take(stageOneLimit).toList();

    final reranked = <RecommendationResult>[];

    for (final candidate in stageOne) {
      final destination = candidate.destination;
      final components = candidate.components;
      final constraintPenalty = _constraintPenalty(
        destination: destination,
        preferredBudget: prefs.budget,
        budgetMatch: components.budgetMatch,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
      );

      final localAffinityBoost =
          userProfileService?.affinityBoostFor(destination) ?? 0.0;

      final localPersonalizationScore = AppConstants.maxAffinityBoost > 0
          ? (localAffinityBoost / AppConstants.maxAffinityBoost)
              .clamp(0.0, 1.0)
              .toDouble()
          : 0.0;

      final baseScore = _clamp(
        candidate.embeddingSimilarity * _embeddingScoreWeight +
            candidate.contextualScore * _contextualScoreWeight,
      );

      final finalScore = baseScore;
      final resultComponents = RecommendationComponents(
        semantic: candidate.embeddingSimilarity,
        collaborative: localPersonalizationScore,
        activityMatch: components.activityMatch,
        vibeMatch: components.vibeMatch,
        seasonMatch: components.seasonMatch,
        budgetMatch: components.budgetMatch,
        accessibilityFit: components.accessibilityFit,
        familyFit: components.familyFit,
        accommodationFit: components.accommodationFit,
      );

      reranked.add(
        RecommendationResult(
          destination: destination,
          score: finalScore,
          reasons: _buildExplainableReasons(
            destination: destination,
            prefs: prefs,
            familyFriendly: familyFriendly,
            embeddingSimilarity: candidate.embeddingSimilarity,
            contextualScore: candidate.contextualScore,
            constraintPenalty: constraintPenalty,
            components: resultComponents,
          ),
          components: resultComponents,
        ),
      );
    }

    reranked.sort((a, b) => b.score.compareTo(a.score));

    return _diversify(
      reranked,
      topK: topK,
      maxPerDistrict: AppConstants.maxResultsPerDistrict,
      maxPerCategory: AppConstants.maxResultsPerCategory,
    );
  }

  List<RecommendationResult> similarToDestination(
    Destination seed,
    List<Destination> destinations, {
    int topK = 4,
  }) {
    if (destinations.isEmpty) {
      return [];
    }

    final seedEmbedding = _semanticVectorFor(seed);
    if (seedEmbedding.isEmpty) {
      return [];
    }

    final explicitMatches = _offlineSimilarMatches(seed);
    final scored = <RecommendationResult>[];

    for (final destination in destinations) {
      if (destination.id == seed.id) {
        continue;
      }

      final destinationEmbedding = _semanticVectorFor(destination);
      if (destinationEmbedding.isEmpty) {
        continue;
      }

      var similarity = _clamp(
        _normalisedDotProduct(seedEmbedding, destinationEmbedding),
      );
      final reasons = <String>[];

      final normalizedId = destination.id.toLowerCase();
      final normalizedName = destination.name.toLowerCase();
      if (explicitMatches.contains(normalizedId) ||
          explicitMatches.contains(normalizedName)) {
        similarity = _clamp(similarity + 0.20);
        reasons.add('Similar to selected place in the offline knowledge base');
      }

      if (similarity <= 0) {
        continue;
      }

      final seedDistrict = _norm(seed.district ?? '');
      final destinationDistrict = _norm(destination.district ?? '');
      if (seedDistrict.isNotEmpty && seedDistrict == destinationDistrict) {
        similarity = _clamp(similarity + 0.05);
        reasons.add('Located in the same district');
      }

      similarity = _clamp(similarity + _qualityPrior(destination) * 0.04);
      reasons.addAll(_buildSimilarityReasons(seed, destination));

      scored.add(
        RecommendationResult(
          destination: destination,
          score: similarity,
          reasons: reasons.take(4).toList(),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return _diversify(
      scored,
      topK: topK,
      maxPerDistrict: AppConstants.maxResultsPerDistrict,
      maxPerCategory: AppConstants.maxResultsPerCategory,
    );
  }

  double _semanticEmbeddingSimilarity(
    Destination destination,
    List<double> queryVector,
  ) {
    final destinationVector = _semanticVectorFor(destination);
    if (queryVector.isEmpty || destinationVector.isEmpty) {
      return 0.0;
    }
    return _clamp(_normalisedDotProduct(queryVector, destinationVector));
  }

  List<double> _semanticVectorFor(Destination destination) {
    return destinationEmbeddings[destination.id] ?? const [];
  }

  List<double> _queryEmbeddingVector(
    UserPreferences prefs,
    List<Destination> destinations,
    Map<String, List<Accommodation>> accommodationsByDestination, {
    bool? familyFriendly,
    int? adventureLevel,
  }) {
    final weighted = <double>[];
    var totalWeight = 0.0;

    for (final destination in destinations) {
      final vector = _semanticVectorFor(destination);
      if (vector.isEmpty) {
        continue;
      }

      final seedWeight = _querySeedWeight(
        destination: destination,
        prefs: prefs,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        accommodationsByDestination: accommodationsByDestination,
      );
      if (seedWeight < _querySeedThreshold) {
        continue;
      }

      if (weighted.isEmpty) {
        weighted.addAll(List<double>.filled(vector.length, 0.0));
      }
      if (weighted.length != vector.length) {
        continue;
      }

      for (var index = 0; index < vector.length; index++) {
        weighted[index] += vector[index] * seedWeight;
      }
      totalWeight += seedWeight;
    }

    if (weighted.isEmpty || totalWeight <= 0) {
      return _averageEmbedding(destinations);
    }

    for (var index = 0; index < weighted.length; index++) {
      weighted[index] /= totalWeight;
    }
    return _l2Normalise(weighted);
  }

  List<double> _averageEmbedding(List<Destination> destinations) {
    final average = <double>[];
    var count = 0;

    for (final destination in destinations) {
      final vector = _semanticVectorFor(destination);
      if (vector.isEmpty) {
        continue;
      }
      if (average.isEmpty) {
        average.addAll(List<double>.filled(vector.length, 0.0));
      }
      if (average.length != vector.length) {
        continue;
      }
      for (var index = 0; index < vector.length; index++) {
        average[index] += vector[index];
      }
      count++;
    }

    if (count == 0) {
      return const [];
    }
    for (var index = 0; index < average.length; index++) {
      average[index] /= count;
    }
    return _l2Normalise(average);
  }

  double _querySeedWeight({
    required Destination destination,
    required UserPreferences prefs,
    required bool? familyFriendly,
    required int? adventureLevel,
    required Map<String, List<Accommodation>> accommodationsByDestination,
  }) {
    final components = _contextualComponents(
      destination: destination,
      prefs: prefs,
      familyFriendly: familyFriendly,
      accommodationsByDestination: accommodationsByDestination,
    );
    var score = _contextualScore(components);

    if (adventureLevel != null && destination.adventureLevel != null) {
      final diff = (destination.adventureLevel! - adventureLevel).abs();
      score = _clamp(score + max(0.0, 1.0 - diff / 4.0) * 0.10);
    }

    return score;
  }

  RecommendationComponents _contextualComponents({
    required Destination destination,
    required UserPreferences prefs,
    required bool? familyFriendly,
    required Map<String, List<Accommodation>> accommodationsByDestination,
  }) {
    return RecommendationComponents(
      semantic: 0.0,
      collaborative: 0.0,
      activityMatch: _activityMatch(destination, prefs.activity),
      vibeMatch: _vibeMatch(destination, prefs.vibe),
      seasonMatch: _seasonMatch(destination, prefs.season),
      budgetMatch: _budgetMatch(destination.priceTier, prefs.budget),
      accessibilityFit: _accessibilityScore(destination.accessibility),
      familyFit: _familyFit(destination, familyFriendly),
      accommodationFit: _accommodationFit(
        destination,
        accommodationsByDestination,
        prefs.budget,
      ),
    );
  }

  double _contextualScore(RecommendationComponents components) {
    return _clamp(
      components.activityMatch * AppConstants.activityComponentWeight +
          components.vibeMatch * AppConstants.vibeComponentWeight +
          components.seasonMatch * AppConstants.seasonComponentWeight +
          components.budgetMatch * AppConstants.budgetComponentWeight +
          components.accessibilityFit *
              AppConstants.accessibilityComponentWeight +
          components.familyFit * AppConstants.familyComponentWeight +
          components.accommodationFit *
              AppConstants.accommodationComponentWeight,
    );
  }

  Set<String> _offlineSimilarMatches(Destination seed) {
    final entries = [
      ...?similarPlaces[seed.id],
      ...?similarPlaces[seed.id.toLowerCase()],
      ...?similarPlaces[seed.name],
      ...?similarPlaces[seed.name.toLowerCase()],
    ];

    return entries
        .expand((entry) => [
              entry['id']?.toString().toLowerCase(),
              entry['name']?.toString().toLowerCase(),
            ])
        .whereType<String>()
        .toSet();
  }

  double _activityMatch(Destination destination, String activity) {
    final terms = _allTerms(destination);
    final queryTerms = _activityAliases(_norm(activity));

    if (queryTerms.isEmpty) {
      return 0.5;
    }

    return _weightedAliasMatch(terms, queryTerms);
  }

  double _vibeMatch(Destination destination, String vibe) {
    final terms = _allTerms(destination);
    final queryTerms = _vibeAliases(_norm(vibe));

    if (queryTerms.isEmpty) {
      return 0.5;
    }

    return _weightedAliasMatch(terms, queryTerms);
  }

  double _weightedAliasMatch(Set<String> terms, List<String> aliases) {
    if (aliases.isEmpty) return 0.0;

    var exact = 0.0;
    var partial = 0.0;

    for (final alias in aliases.map(_norm)) {
      if (terms.contains(alias)) {
        exact += 1.0;
        continue;
      }

      if (terms.any((term) => term.contains(alias) || alias.contains(term))) {
        partial += 1.0;
      }
    }

    final denominator = min(aliases.length, 3);
    return _clamp((exact + partial * 0.55) / denominator);
  }

  double _seasonMatch(Destination destination, String season) {
    final query = _norm(season);
    final seasons = destination.bestSeason.map(_norm).toSet();
    if (query.isEmpty) {
      return 0.5;
    }
    if (seasons.contains(query) || seasons.contains('year-round')) {
      return 1.0;
    }

    const shoulderSeasons = {
      'spring': {'winter', 'autumn'},
      'autumn': {'spring', 'winter'},
      'winter': {'autumn', 'spring'},
      'monsoon': {'summer'},
      'summer': {'monsoon'},
    };

    if ((shoulderSeasons[query] ?? const {}).any(seasons.contains)) {
      return 0.45;
    }
    return 0.0;
  }

  double _budgetMatch(String? actualBudget, String preferredBudget) {
    final actual = _norm(actualBudget ?? '');
    final preferred = _norm(preferredBudget);

    if (preferred.isEmpty) {
      return 0.5;
    }
    if (actual == preferred) {
      return 1.0;
    }

    const order = ['budget', 'medium', 'premium'];
    final actualIndex = order.indexOf(actual);
    final preferredIndex = order.indexOf(preferred);

    if (actualIndex == -1 || preferredIndex == -1) {
      return 0.35;
    }

    return (actualIndex - preferredIndex).abs() == 1 ? 0.65 : 0.15;
  }

  double _accessibilityScore(String? accessibility) {
    switch (_norm(accessibility ?? '')) {
      case 'easy':
        return 1.0;
      case 'moderate':
        return 0.68;
      case 'difficult':
        return 0.30;
      case 'very difficult':
        return 0.14;
      default:
        return 0.5;
    }
  }

  double _familyFit(Destination destination, bool? familyFriendly) {
    if (familyFriendly == null) {
      return 0.5;
    }
    if (familyFriendly && destination.familyFriendly == true) {
      return 1.0;
    }
    if (familyFriendly && destination.familyFriendly != true) {
      return 0.18;
    }
    return 0.62;
  }

  Map<String, List<Accommodation>> _accommodationsByDestination(
    List<Accommodation> accommodations,
  ) {
    final byDestination = <String, List<Accommodation>>{};

    for (final accommodation in accommodations) {
      final id = accommodation.destinationId?.trim();
      if (id != null && id.isNotEmpty) {
        byDestination.putIfAbsent(id, () => []).add(accommodation);
      }
    }

    return byDestination;
  }

  double _accommodationFit(
    Destination destination,
    Map<String, List<Accommodation>> accommodationsByDestination,
    String preferredBudget,
  ) {
    final stays = accommodationsByDestination[destination.id] ?? const [];

    if (stays.isEmpty) {
      return 0.25;
    }

    final preferred = _norm(preferredBudget);
    var bestBudget = 0.45;
    var typeFit = 0.45;

    for (final stay in stays) {
      final stayBudget = _norm(stay.priceRange ?? '');
      if (stayBudget.isNotEmpty && stayBudget == preferred) {
        bestBudget = max(bestBudget, 1.0);
      } else if (stayBudget.isNotEmpty &&
          _budgetMatch(stayBudget, preferredBudget) >= 0.65) {
        bestBudget = max(bestBudget, 0.75);
      } else if (stayBudget.isNotEmpty) {
        bestBudget = max(bestBudget, 0.55);
      }

      final type = _norm(stay.type ?? '');
      if (type.contains('homestay')) {
        typeFit = max(typeFit, 0.90);
      } else if (type.contains('lodge') || type.contains('guesthouse')) {
        typeFit = max(typeFit, 0.75);
      } else if (type.contains('resort') || type.contains('hotel')) {
        typeFit = max(typeFit, 0.65);
      }
    }

    final coverageFit = stays.length >= 3
        ? 1.0
        : stays.length == 2
            ? 0.82
            : 0.62;

    return _clamp(bestBudget * 0.46 + coverageFit * 0.34 + typeFit * 0.20);
  }

  double _qualityPrior(Destination destination) {
    var score = 0.35;

    switch (_norm(destination.confidence)) {
      case 'high':
        score += 0.22;
        break;
      case 'medium':
        score += 0.16;
        break;
      case 'low':
        score += 0.08;
        break;
    }

    score += min(destination.tags.length, 14) / 14.0 * 0.14;
    score += min(destination.activities.length, 5) / 5.0 * 0.08;
    score += min(destination.bestSeason.length, 4) / 4.0 * 0.06;
    score += min(destination.displayDescription.length, 520) / 520.0 * 0.10;

    if (destination.latitude != null && destination.longitude != null) {
      score += 0.05;
    }
    if ((destination.municipality ?? '').trim().isNotEmpty) {
      score += 0.04;
    }
    if (destination.images.isNotEmpty) {
      score += 0.03;
    }

    return _clamp(score);
  }

  double _constraintPenalty({
    required Destination destination,
    required String preferredBudget,
    required double budgetMatch,
    required bool? familyFriendly,
    required int? adventureLevel,
  }) {
    var penalty = 1.0;

    if (familyFriendly == true && destination.familyFriendly != true) {
      penalty -= 0.20;
    }

    if (_norm(preferredBudget).isNotEmpty && budgetMatch <= 0.20) {
      penalty -= 0.12;
    }

    final destinationAdventure = destination.adventureLevel;
    if (adventureLevel != null && destinationAdventure != null) {
      final diff = (destinationAdventure - adventureLevel).abs();
      if (diff > 2) {
        penalty -= min(0.16, (diff - 2) * 0.08);
      }
    }

    return penalty.clamp(0.64, 1.0).toDouble();
  }

  List<RecommendationResult> _diversify(
    List<RecommendationResult> ranked, {
    required int topK,
    required int maxPerDistrict,
    required int maxPerCategory,
  }) {
    final remaining = ranked.toList();
    final districtCount = <String, int>{};
    final categoryCount = <String, int>{};
    final diversified = <RecommendationResult>[];

    while (remaining.isNotEmpty && diversified.length < topK) {
      RecommendationResult? best;
      var bestAdjustedScore = double.negativeInfinity;

      for (final result in remaining) {
        final district = _norm(result.destination.district ?? 'unknown');
        final category = _norm(result.destination.primaryCategory);
        final districtMatches = districtCount[district] ?? 0;
        final categoryMatches = categoryCount[category] ?? 0;

        final hardBlocked = districtMatches >= maxPerDistrict ||
            categoryMatches >= maxPerCategory;
        if (hardBlocked) {
          final bestUnblockedScore = _bestUnblockedScore(
            remaining,
            districtCount,
            categoryCount,
            maxPerDistrict,
            maxPerCategory,
          );

          if (bestUnblockedScore != null &&
              result.score <= bestUnblockedScore + _diversityScoreTolerance) {
            continue;
          }
        }

        final adjustedScore = hardBlocked
            ? result.score
            : result.score - districtMatches * 0.035 - categoryMatches * 0.030;

        if (adjustedScore > bestAdjustedScore) {
          bestAdjustedScore = adjustedScore;
          best = result;
        }
      }

      final selected = best ?? remaining.first;
      remaining.remove(selected);

      final district = _norm(selected.destination.district ?? 'unknown');
      final category = _norm(selected.destination.primaryCategory);
      districtCount[district] = (districtCount[district] ?? 0) + 1;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      diversified.add(selected);
    }

    return diversified;
  }

  double? _bestUnblockedScore(
    List<RecommendationResult> candidates,
    Map<String, int> districtCount,
    Map<String, int> categoryCount,
    int maxPerDistrict,
    int maxPerCategory,
  ) {
    double? bestScore;
    for (final candidate in candidates) {
      final district = _norm(candidate.destination.district ?? 'unknown');
      final category = _norm(candidate.destination.primaryCategory);
      if ((districtCount[district] ?? 0) < maxPerDistrict &&
          (categoryCount[category] ?? 0) < maxPerCategory) {
        bestScore = bestScore == null
            ? candidate.score
            : max(bestScore, candidate.score);
      }
    }
    return bestScore;
  }

  List<String> _buildExplainableReasons({
    required Destination destination,
    required UserPreferences prefs,
    required bool? familyFriendly,
    required double embeddingSimilarity,
    required double contextualScore,
    required double constraintPenalty,
    required RecommendationComponents components,
  }) {
    final weightedContributions = <_WeightedReason>[
      _WeightedReason(
        score: components.collaborative * 0.20,
        reason: 'Personalized from your saved and viewed destinations',
      ),
      _WeightedReason(
        score: embeddingSimilarity * _embeddingScoreWeight,
        reason: 'SBERT embedding match understands related travel intent',
      ),
      _WeightedReason(
        score: contextualScore * _contextualScoreWeight,
        reason: 'Contextual fit matches your selected trip profile',
      ),
      _WeightedReason(
        score: components.activityMatch *
            _contextualScoreWeight *
            AppConstants.activityComponentWeight,
        reason: 'Matches your activity',
      ),
      _WeightedReason(
        score: components.vibeMatch *
            _contextualScoreWeight *
            AppConstants.vibeComponentWeight,
        reason: 'Matches your preferred vibe',
      ),
      _WeightedReason(
        score: components.seasonMatch *
            _contextualScoreWeight *
            AppConstants.seasonComponentWeight,
        reason: 'Best season match',
      ),
      _WeightedReason(
        score: components.budgetMatch *
            _contextualScoreWeight *
            AppConstants.budgetComponentWeight,
        reason: 'Fits budget',
      ),
      _WeightedReason(
        score: components.accessibilityFit *
            _contextualScoreWeight *
            AppConstants.accessibilityComponentWeight,
        reason: 'Accessibility fit supports this trip',
      ),
      _WeightedReason(
        score: components.familyFit *
            _contextualScoreWeight *
            AppConstants.familyComponentWeight,
        reason: familyFriendly == true
            ? 'Family friendly'
            : 'Flexible for mixed groups',
      ),
      _WeightedReason(
        score: components.accommodationFit *
            _contextualScoreWeight *
            AppConstants.accommodationComponentWeight,
        reason: 'Has multiple nearby accommodation options',
      ),
    ].where((entry) => entry.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (constraintPenalty < 0.90) {
      weightedContributions.removeWhere(
        (entry) =>
            entry.reason == 'Contextual fit matches your selected trip profile',
      );
    }

    final total = weightedContributions.fold<double>(
      0,
      (sum, entry) => sum + entry.score,
    );

    if (weightedContributions.isEmpty || total <= 0) {
      return [
        'Matches your activity for ${_pretty(prefs.activity)}',
        'Fits budget',
        'Best season match',
      ];
    }

    final reasons = weightedContributions.take(4).map((entry) {
      final percent = ((entry.score / total) * 100).round();
      return '${entry.reason} ($percent%)';
    }).toList();

    if (components.accommodationFit >= 0.75 &&
        !reasons
            .any((reason) => reason.toLowerCase().contains('accommodation'))) {
      const accommodationReason = 'Has multiple nearby accommodation options';
      if (reasons.length >= 4) {
        reasons[3] = accommodationReason;
      } else {
        reasons.add(accommodationReason);
      }
    }

    return reasons;
  }

  List<String> _buildSimilarityReasons(
      Destination seed, Destination destination) {
    final reasons = <String>[];

    final sharedActivities = seed.activities.map(_norm).toSet()
      ..retainAll(destination.activities.map(_norm).toSet());
    if (sharedActivities.isNotEmpty) {
      reasons.add('Similar to selected place in activity profile');
    }

    final sharedCategories = seed.category.map(_norm).toSet()
      ..retainAll(destination.category.map(_norm).toSet());
    if (sharedCategories.isNotEmpty) {
      reasons.add('Similar category to the selected place');
    }

    final sharedTags = seed.tags.map(_norm).toSet()
      ..retainAll(destination.tags.map(_norm).toSet());
    if (sharedTags.isNotEmpty) {
      reasons.add('Shares local tags with the selected place');
    }

    if (_norm(seed.priceTier) == _norm(destination.priceTier)) {
      reasons.add('Similar budget level');
    }

    final sharedSeasons = seed.bestSeason.map(_norm).toSet()
      ..retainAll(destination.bestSeason.map(_norm).toSet());
    if (sharedSeasons.isNotEmpty) {
      reasons.add('Best season match');
    }

    return reasons;
  }

  List<String> _activityAliases(String activity) {
    const aliases = <String, List<String>>{
      'culture': [
        'culture',
        'cultural',
        'heritage',
        'village',
        'museum',
        'pilgrimage',
        'homestay',
        'local food',
      ],
      'cultural': [
        'culture',
        'cultural',
        'heritage',
        'village',
        'traditional',
        'local',
      ],
      'hiking': ['hiking', 'trekking', 'adventure', 'trek', 'trail', 'ridge'],
      'trekking': [
        'trekking',
        'hiking',
        'trail',
        'ridge',
        'viewpoint',
        'climbing',
        'mountain',
        'pass',
      ],
      'adventure': [
        'adventure',
        'hiking',
        'trekking',
        'trail',
        'climbing',
        'cave',
        'pass',
      ],
      'wildlife': [
        'wildlife',
        'bird',
        'birding',
        'forest',
        'nature',
        'conservation',
      ],
      'relaxation': [
        'relax',
        'relaxation',
        'peaceful',
        'lake',
        'scenic',
        'retreat',
        'hot spring',
      ],
      'lake': ['lake', 'boating', 'waterside', 'scenic', 'relaxation'],
      'boating': ['boating', 'lake', 'waterside', 'relaxation'],
      'pilgrimage': ['pilgrimage', 'temple', 'spiritual', 'dham', 'gumba'],
      'photography': [
        'photography',
        'viewpoint',
        'panorama',
        'scenic',
        'sunrise',
      ],
      'viewpoint': ['viewpoint', 'panorama', 'sunrise', 'scenic', 'ridge'],
    };
    return aliases[activity] ?? [activity];
  }

  List<String> _vibeAliases(String vibe) {
    const aliases = <String, List<String>>{
      'family': ['family', 'easy', 'safe', 'picnic', 'homestay'],
      'social': ['family', 'local', 'homestay', 'market', 'village'],
      'adventure': ['adventure', 'thrill', 'trekking', 'trail', 'climbing'],
      'cultural': ['culture', 'heritage', 'local', 'traditional', 'village'],
      'historic': ['heritage', 'history', 'cultural', 'old settlement'],
      'spiritual': ['spiritual', 'pilgrimage', 'temple', 'monastery'],
      'nature': ['nature', 'forest', 'lake', 'river', 'viewpoint'],
      'scenic': ['scenic', 'viewpoint', 'panorama', 'photography'],
      'quiet': ['quiet', 'peaceful', 'relax', 'retreat', 'village'],
      'peaceful': ['peaceful', 'quiet', 'relax', 'retreat', 'village'],
      'photography': ['scenic', 'viewpoint', 'panorama', 'sunrise'],
    };
    return aliases[vibe] ?? [vibe];
  }

  Set<String> _allTerms(Destination destination) {
    final values = [
      destination.name,
      destination.district ?? '',
      destination.municipality ?? '',
      ...destination.activities,
      ...destination.category,
      ...destination.tags,
      destination.shortDescription,
      destination.fullDescription,
    ];

    return {
      for (final value in values) _norm(value),
      for (final value in values) ..._tokenize(value).map(_norm),
    }..remove('');
  }

  List<String> _tokenize(String input) {
    const stopWords = {
      'a',
      'an',
      'and',
      'are',
      'as',
      'at',
      'by',
      'for',
      'from',
      'in',
      'is',
      'it',
      'near',
      'of',
      'on',
      'or',
      'the',
      'to',
      'with',
    };

    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1 && !stopWords.contains(token))
        .toList();
  }

  String _pretty(String value) {
    if (value.isEmpty) {
      return value;
    }
    final trimmed = value.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  String _norm(String value) => value.trim().toLowerCase();

  double _clamp(double value) => value.clamp(0.0, 1.0).toDouble();

  List<double> _l2Normalise(List<double> values) {
    final magnitude =
        sqrt(values.fold(0.0, (sum, value) => sum + value * value));
    if (magnitude == 0) {
      return List<double>.filled(values.length, 0.0);
    }
    return values.map((value) => value / magnitude).toList();
  }

  double _normalisedDotProduct(List<double> left, List<double> right) {
    if (left.length != right.length || left.isEmpty) {
      return 0.0;
    }

    var dot = 0.0;
    for (var index = 0; index < left.length; index++) {
      dot += left[index] * right[index];
    }
    return dot;
  }
}

class _CandidateScore {
  final Destination destination;
  final double embeddingSimilarity;
  final double retrievalScore;
  final double contextualScore;
  final RecommendationComponents components;

  const _CandidateScore({
    required this.destination,
    required this.embeddingSimilarity,
    required this.retrievalScore,
    required this.contextualScore,
    required this.components,
  });
}

class _WeightedReason {
  final double score;
  final String reason;

  const _WeightedReason({
    required this.score,
    required this.reason,
  });
}
