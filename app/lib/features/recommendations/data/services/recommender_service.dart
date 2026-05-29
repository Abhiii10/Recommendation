import 'dart:math';

import 'package:rural_tourism_app/core/utils/app_constants.dart';
import 'package:rural_tourism_app/domain/entities/recommendation_result.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/recommendation_components.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/destination_affinity_provider.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/offline_semantic_encoder.dart';

export 'package:rural_tourism_app/domain/entities/recommendation_result.dart';

const double _retrievalTextWeight = 0.46;
const double _retrievalEmbeddingWeight = 0.18;
const double _retrievalNumericWeight = 0.20;
const double _retrievalQualityWeight = 0.09;
const double _retrievalAccommodationWeight = 0.07;

const double _finalTextWeight = 0.25;
const double _finalEmbeddingWeight = 0.16;
const double _finalNumericWeight = 0.14;
const double _finalContextualWeight = 0.27;
const double _finalQualityWeight = 0.08;
const double _finalPopularityWeight = 0.05;
const double _finalAccommodationWeight = 0.05;

const double _tfIdfTextBlend = 0.62;
const double _bm25TextBlend = 0.38;
const double _bm25Normalisation = 6.0;
const double _diversityScoreTolerance = 0.020;
const int _candidateMultiplier = 8;

class RecommenderService {
  final Map<String, List<Map<String, dynamic>>> similarPlaces;
  final DestinationAffinityProvider? userProfileService;
  final Map<String, List<double>> destinationEmbeddings;
  _HybridTextIndex? _index;
  int _indexedDestinationCount = 0;

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

    _ensureIndex(destinations);

    final index = _index!;
    final queryTerms = _queryTerms(prefs);
    final queryTextVector = index.queryVector(queryTerms);
    final queryEmbeddingVector = OfflineSemanticEncoder.encodePreferences(
      prefs,
      familyFriendly: familyFriendly,
      adventureLevel: adventureLevel,
    );
    final queryNumericVector = _numericQueryVector(
      prefs,
      familyFriendly: familyFriendly,
      adventureLevel: adventureLevel,
    );
    final accommodationsByDestination =
        _accommodationsByDestination(accommodations);

    final candidates = <_CandidateScore>[];

    for (final destination in destinations) {
      final documentVector = index.documentVector(destination.id);
      if (documentVector == null) {
        continue;
      }

      final tfIdfSimilarity = _clamp(
        _cosineSimilarity(queryTextVector, documentVector),
      );
      final bm25Similarity = index.bm25Score(destination.id, queryTerms);
      final textSimilarity = _clamp(
        tfIdfSimilarity * _tfIdfTextBlend + bm25Similarity * _bm25TextBlend,
      );
      final embeddingSimilarity = _semanticEmbeddingSimilarity(
        destination,
        queryEmbeddingVector,
      );
      final numericSimilarity = _clamp(
        _cosineSimilarity(queryNumericVector, _numericDocVector(destination)),
      );
      final qualityPrior = _qualityPrior(destination);
      final accommodationFit = _accommodationFit(
        destination,
        accommodationsByDestination,
        prefs.budget,
      );

      final retrievalScore = _clamp(
        textSimilarity * _retrievalTextWeight +
            embeddingSimilarity * _retrievalEmbeddingWeight +
            numericSimilarity * _retrievalNumericWeight +
            qualityPrior * _retrievalQualityWeight +
            accommodationFit * _retrievalAccommodationWeight,
      );

      if (retrievalScore <= 0) {
        continue;
      }

      candidates.add(
        _CandidateScore(
          destination: destination,
          textSimilarity: textSimilarity,
          tfIdfSimilarity: tfIdfSimilarity,
          bm25Similarity: bm25Similarity,
          embeddingSimilarity: embeddingSimilarity,
          numericSimilarity: numericSimilarity,
          retrievalScore: retrievalScore,
          qualityPrior: qualityPrior,
          accommodationFit: accommodationFit,
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
      final activityMatch = _activityMatch(destination, prefs.activity);
      final vibeMatch = _vibeMatch(destination, prefs.vibe);
      final seasonMatch = _seasonMatch(destination, prefs.season);
      final budgetMatch = _budgetMatch(destination.priceTier, prefs.budget);
      final accessibilityFit = _accessibilityScore(destination.accessibility);
      final familyFit = _familyFit(destination, familyFriendly);
      final popularityPrior = _offlinePopularityPrior(
        destination,
        accommodationsByDestination[destination.id] ?? const [],
      );
      final constraintPenalty = _constraintPenalty(
        destination: destination,
        preferredBudget: prefs.budget,
        budgetMatch: budgetMatch,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
      );

      final contextualScore = _clamp(
        activityMatch * AppConstants.activityComponentWeight +
            vibeMatch * AppConstants.vibeComponentWeight +
            seasonMatch * AppConstants.seasonComponentWeight +
            budgetMatch * AppConstants.budgetComponentWeight +
            accessibilityFit * AppConstants.accessibilityComponentWeight +
            familyFit * AppConstants.familyComponentWeight +
            candidate.accommodationFit *
                AppConstants.accommodationComponentWeight,
      );

      final localAffinityBoost =
          userProfileService?.affinityBoostFor(destination) ?? 0.0;

      final localPersonalizationScore = AppConstants.maxAffinityBoost > 0
          ? (localAffinityBoost / AppConstants.maxAffinityBoost)
              .clamp(0.0, 1.0)
              .toDouble()
          : 0.0;

      final baseScore = _clamp(
        candidate.textSimilarity * _finalTextWeight +
            candidate.embeddingSimilarity * _finalEmbeddingWeight +
            candidate.numericSimilarity * _finalNumericWeight +
            contextualScore * _finalContextualWeight +
            candidate.qualityPrior * _finalQualityWeight +
            popularityPrior * _finalPopularityWeight +
            candidate.accommodationFit * _finalAccommodationWeight,
      );

      final finalScore =
          _clamp(baseScore * constraintPenalty + localAffinityBoost);

      final components = RecommendationComponents(
        semantic: _clamp(
          candidate.textSimilarity * 0.60 +
              candidate.embeddingSimilarity * 0.40,
        ),
        collaborative: localPersonalizationScore,
        activityMatch: activityMatch,
        vibeMatch: vibeMatch,
        seasonMatch: seasonMatch,
        budgetMatch: budgetMatch,
        accessibilityFit: accessibilityFit,
        familyFit: familyFit,
        accommodationFit: candidate.accommodationFit,
      );

      reranked.add(
        RecommendationResult(
          destination: destination,
          score: finalScore,
          reasons: _buildExplainableReasons(
            destination: destination,
            prefs: prefs,
            familyFriendly: familyFriendly,
            textSimilarity: candidate.textSimilarity,
            embeddingSimilarity: candidate.embeddingSimilarity,
            numericSimilarity: candidate.numericSimilarity,
            qualityPrior: candidate.qualityPrior,
            popularityPrior: popularityPrior,
            constraintPenalty: constraintPenalty,
            components: components,
          ),
          components: components,
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

    _ensureIndex(destinations);

    final index = _index!;
    final seedVector = index.documentVector(seed.id);
    final seedEmbedding = _semanticVectorFor(seed);
    if (seedVector == null) {
      return [];
    }

    final explicitMatches = _offlineSimilarMatches(seed);
    final seedTerms = _documentQueryTerms(seed);
    final scored = <RecommendationResult>[];

    for (final destination in destinations) {
      if (destination.id == seed.id) {
        continue;
      }

      final documentVector = index.documentVector(destination.id);
      if (documentVector == null) {
        continue;
      }

      final tfIdfSimilarity =
          _clamp(_cosineSimilarity(seedVector, documentVector));
      final bm25Similarity = index.bm25Score(destination.id, seedTerms);
      final embeddingSimilarity =
          _cosineSimilarity(seedEmbedding, _semanticVectorFor(destination));
      var similarity = _clamp(
        tfIdfSimilarity * 0.46 +
            bm25Similarity * 0.28 +
            embeddingSimilarity * 0.26,
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

  void _ensureIndex(List<Destination> destinations) {
    if (_index != null && _indexedDestinationCount == destinations.length) {
      return;
    }

    _index = _HybridTextIndex.build(destinations);
    _indexedDestinationCount = destinations.length;
  }

  double _semanticEmbeddingSimilarity(
    Destination destination,
    List<double> queryVector,
  ) {
    return _clamp(
      _cosineSimilarity(queryVector, _semanticVectorFor(destination)),
    );
  }

  List<double> _semanticVectorFor(Destination destination) {
    return destinationEmbeddings[destination.id] ??
        OfflineSemanticEncoder.encodeDestination(destination);
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

  List<double> _numericDocVector(Destination destination) {
    return _l2Normalise([
      (destination.adventureLevel ?? 3) / 5.0,
      (destination.cultureLevel ?? 3) / 5.0,
      (destination.natureLevel ?? 3) / 5.0,
      _accessibilityScore(destination.accessibility),
      destination.familyFriendly == true ? 1.0 : 0.0,
    ]);
  }

  List<double> _numericQueryVector(
    UserPreferences prefs, {
    bool? familyFriendly,
    int? adventureLevel,
  }) {
    final activity = _norm(prefs.activity);
    final vibe = _norm(prefs.vibe);

    var adventure = 0.5;
    var culture = 0.5;
    var nature = 0.5;
    var accessibility = 0.5;
    var family = 0.5;

    switch (activity) {
      case 'adventure':
      case 'hiking':
      case 'trekking':
        adventure = 0.9;
        nature = 0.8;
        break;
      case 'culture':
      case 'cultural':
      case 'heritage':
        culture = 1.0;
        adventure = 0.3;
        break;
      case 'pilgrimage':
      case 'spiritual':
        culture = 0.9;
        accessibility = 0.7;
        adventure = 0.25;
        break;
      case 'wildlife':
        nature = 1.0;
        adventure = 0.6;
        break;
      case 'relaxation':
        adventure = 0.2;
        accessibility = 0.8;
        break;
      case 'lake':
      case 'boating':
        nature = 0.9;
        adventure = 0.4;
        accessibility = 0.75;
        break;
      case 'photography':
      case 'viewpoint':
      case 'scenic':
        nature = 0.8;
        culture = 0.6;
        break;
    }

    switch (vibe) {
      case 'family':
      case 'social':
        family = 1.0;
        adventure = adventure.clamp(0.0, 0.6);
        accessibility = 0.9;
        break;
      case 'adventure':
        adventure = (adventure + 0.2).clamp(0.0, 1.0);
        break;
      case 'cultural':
      case 'historic':
        culture = (culture + 0.2).clamp(0.0, 1.0);
        break;
      case 'spiritual':
        culture = max(culture, 0.85);
        accessibility = max(accessibility, 0.65);
        break;
      case 'nature':
      case 'scenic':
        nature = max(nature, 0.9);
        break;
      case 'quiet':
      case 'peaceful':
        adventure = (adventure - 0.1).clamp(0.0, 1.0);
        accessibility = max(accessibility, 0.65);
        break;
    }

    if (familyFriendly == true) {
      family = 1.0;
      accessibility = max(accessibility, 0.85);
    }

    if (adventureLevel != null) {
      adventure = ((adventure + adventureLevel / 5.0) / 2).clamp(0.0, 1.0);
    }

    return _l2Normalise([
      adventure,
      culture,
      nature,
      accessibility,
      family,
    ]);
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

  double _offlinePopularityPrior(
    Destination destination,
    List<Accommodation> stays,
  ) {
    var score = 0.28;

    switch (_norm(destination.confidence)) {
      case 'high':
        score += 0.18;
        break;
      case 'medium':
        score += 0.12;
        break;
      case 'low':
        score += 0.06;
        break;
    }

    score += min(stays.length, 3) / 3.0 * 0.18;
    score += min(destination.tags.length, 12) / 12.0 * 0.10;
    score += min(destination.bestSeason.length, 4) / 4.0 * 0.08;

    final access = _norm(destination.accessibility ?? '');
    if (access == 'easy') {
      score += 0.10;
    } else if (access == 'moderate') {
      score += 0.06;
    }

    if (destination.familyFriendly == true) {
      score += 0.05;
    }

    final category = _norm(destination.primaryCategory);
    if (const {
      'village',
      'cultural',
      'culture',
      'trekking',
      'nature',
      'boating',
      'pilgrimage',
      'wildlife',
    }.contains(category)) {
      score += 0.05;
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
    required double textSimilarity,
    required double embeddingSimilarity,
    required double numericSimilarity,
    required double qualityPrior,
    required double popularityPrior,
    required double constraintPenalty,
    required RecommendationComponents components,
  }) {
    final weightedContributions = <_WeightedReason>[
      _WeightedReason(
        score: components.collaborative * 0.20,
        reason: 'Personalized from your saved and viewed destinations',
      ),
      _WeightedReason(
        score: textSimilarity * _finalTextWeight,
        reason: 'Strong offline semantic match to your travel profile',
      ),
      _WeightedReason(
        score: embeddingSimilarity * _finalEmbeddingWeight,
        reason: 'Offline embedding match understands related travel intent',
      ),
      _WeightedReason(
        score: numericSimilarity * _finalNumericWeight,
        reason: 'Feature profile matches your preferred trip style',
      ),
      _WeightedReason(
        score: components.activityMatch *
            _finalContextualWeight *
            AppConstants.activityComponentWeight,
        reason: 'Matches your activity',
      ),
      _WeightedReason(
        score: components.vibeMatch *
            _finalContextualWeight *
            AppConstants.vibeComponentWeight,
        reason: 'Matches your preferred vibe',
      ),
      _WeightedReason(
        score: components.seasonMatch *
            _finalContextualWeight *
            AppConstants.seasonComponentWeight,
        reason: 'Best season match',
      ),
      _WeightedReason(
        score: components.budgetMatch *
            _finalContextualWeight *
            AppConstants.budgetComponentWeight,
        reason: 'Fits budget',
      ),
      _WeightedReason(
        score: components.accessibilityFit *
            _finalContextualWeight *
            AppConstants.accessibilityComponentWeight,
        reason: 'Accessibility fit supports this trip',
      ),
      _WeightedReason(
        score: components.familyFit *
            _finalContextualWeight *
            AppConstants.familyComponentWeight,
        reason: familyFriendly == true
            ? 'Family friendly'
            : 'Flexible for mixed groups',
      ),
      _WeightedReason(
        score: components.accommodationFit * _finalAccommodationWeight,
        reason: 'Has multiple nearby accommodation options',
      ),
      _WeightedReason(
        score: qualityPrior * _finalQualityWeight,
        reason: 'High quality local catalogue data',
      ),
      _WeightedReason(
        score: popularityPrior * _finalPopularityWeight,
        reason: 'Reliable offline fallback pick for cold-start users',
      ),
    ].where((entry) => entry.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (constraintPenalty < 0.90) {
      weightedContributions.removeWhere(
        (entry) =>
            entry.reason ==
            'Reliable offline fallback pick for cold-start users',
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

  List<String> _queryTerms(UserPreferences prefs) => [
        ..._activityAliases(_norm(prefs.activity)),
        ..._vibeAliases(_norm(prefs.vibe)),
        ..._budgetAliases(_norm(prefs.budget)),
        ..._seasonAliases(_norm(prefs.season)),
      ].where((term) => term.trim().isNotEmpty).toList();

  List<String> _documentQueryTerms(Destination destination) {
    return [
      destination.name,
      destination.district ?? '',
      destination.municipality ?? '',
      ...destination.category,
      ...destination.activities,
      ...destination.tags,
      destination.shortDescription,
    ];
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

  List<String> _budgetAliases(String budget) {
    const aliases = <String, List<String>>{
      'budget': ['budget', 'low cost', 'homestay', 'basic rooms'],
      'medium': ['medium', 'guesthouse', 'lodge', 'private rooms'],
      'premium': ['premium', 'hotel', 'resort', 'comfort'],
    };
    return aliases[budget] ?? [budget];
  }

  List<String> _seasonAliases(String season) {
    const aliases = <String, List<String>>{
      'spring': ['spring', 'rhododendron', 'clear weather'],
      'autumn': ['autumn', 'clear weather', 'festival season'],
      'winter': ['winter', 'clear view', 'cool weather'],
      'monsoon': ['monsoon', 'rainy season', 'green hills'],
      'summer': ['summer', 'monsoon', 'green hills'],
    };
    return aliases[season] ?? [season];
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
      for (final value in values)
        ..._HybridTextIndex.tokenize(value).map(_norm),
    }..remove('');
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

  double _cosineSimilarity(List<double> left, List<double> right) {
    if (left.length != right.length || left.isEmpty) {
      return 0.0;
    }

    var dot = 0.0;
    var leftMagnitude = 0.0;
    var rightMagnitude = 0.0;

    for (var index = 0; index < left.length; index++) {
      dot += left[index] * right[index];
      leftMagnitude += left[index] * left[index];
      rightMagnitude += right[index] * right[index];
    }

    if (leftMagnitude == 0 || rightMagnitude == 0) {
      return 0.0;
    }

    return dot / (sqrt(leftMagnitude) * sqrt(rightMagnitude));
  }
}

class _CandidateScore {
  final Destination destination;
  final double textSimilarity;
  final double tfIdfSimilarity;
  final double bm25Similarity;
  final double embeddingSimilarity;
  final double numericSimilarity;
  final double retrievalScore;
  final double qualityPrior;
  final double accommodationFit;

  const _CandidateScore({
    required this.destination,
    required this.textSimilarity,
    required this.tfIdfSimilarity,
    required this.bm25Similarity,
    required this.embeddingSimilarity,
    required this.numericSimilarity,
    required this.retrievalScore,
    required this.qualityPrior,
    required this.accommodationFit,
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

class _HybridTextIndex {
  static const _stopWords = {
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

  final Map<String, int> vocab;
  final Map<String, List<double>> docVectors;
  final Map<String, Map<String, int>> docTermFrequencies;
  final Map<String, int> docLengths;
  final List<int> documentFrequency;
  final int documentCount;
  final double averageDocLength;

  _HybridTextIndex({
    required this.vocab,
    required this.docVectors,
    required this.docTermFrequencies,
    required this.docLengths,
    required this.documentFrequency,
    required this.documentCount,
    required this.averageDocLength,
  });

  factory _HybridTextIndex.build(List<Destination> destinations) {
    final vocab = <String, int>{};
    final docTerms = <String, List<String>>{};
    final docTermFrequencies = <String, Map<String, int>>{};

    for (final destination in destinations) {
      final terms = _termsForDestination(destination);
      docTerms[destination.id] = terms;

      final frequency = <String, int>{};
      for (final term in terms) {
        vocab.putIfAbsent(term, () => vocab.length);
        frequency[term] = (frequency[term] ?? 0) + 1;
      }
      docTermFrequencies[destination.id] = frequency;
    }

    final documentFrequency = List<int>.filled(vocab.length, 0);
    for (final terms in docTerms.values) {
      final seen = <int>{};
      for (final term in terms) {
        final index = vocab[term];
        if (index != null && seen.add(index)) {
          documentFrequency[index]++;
        }
      }
    }

    final documentCount = destinations.length;
    final docLengths = {
      for (final entry in docTerms.entries) entry.key: entry.value.length,
    };
    final averageDocLength = docLengths.isEmpty
        ? 0.0
        : docLengths.values.fold<int>(0, (sum, value) => sum + value) /
            docLengths.length;
    final docVectors = <String, List<double>>{};

    for (final entry in docTerms.entries) {
      final tf = List<double>.filled(vocab.length, 0.0);
      for (final term in entry.value) {
        final index = vocab[term];
        if (index != null) {
          tf[index] += 1.0;
        }
      }

      for (var index = 0; index < tf.length; index++) {
        if (tf[index] == 0) {
          continue;
        }
        final idf =
            log((documentCount + 1) / (documentFrequency[index] + 1)) + 1.0;
        tf[index] = tf[index] * idf;
      }

      final magnitude = sqrt(tf.fold(0.0, (sum, value) => sum + value * value));
      docVectors[entry.key] =
          magnitude == 0 ? tf : tf.map((value) => value / magnitude).toList();
    }

    return _HybridTextIndex(
      vocab: vocab,
      docVectors: docVectors,
      docTermFrequencies: docTermFrequencies,
      docLengths: docLengths,
      documentFrequency: documentFrequency,
      documentCount: documentCount,
      averageDocLength: averageDocLength,
    );
  }

  List<double>? documentVector(String id) => docVectors[id];

  List<double> queryVector(List<String> terms) {
    final vector = List<double>.filled(vocab.length, 0.0);
    for (final term in terms.expand(tokenize)) {
      final index = vocab[term];
      if (index != null) {
        final idf =
            log((documentCount + 1) / (documentFrequency[index] + 1)) + 1.0;
        vector[index] += idf;
      }
    }

    final magnitude =
        sqrt(vector.fold(0.0, (sum, value) => sum + value * value));
    return magnitude == 0
        ? vector
        : vector.map((value) => value / magnitude).toList();
  }

  double bm25Score(String id, List<String> queryTerms) {
    final frequencies = docTermFrequencies[id];
    final docLength = docLengths[id];
    if (frequencies == null || docLength == null || averageDocLength <= 0) {
      return 0.0;
    }

    const k1 = 1.45;
    const b = 0.72;
    var rawScore = 0.0;
    final seenQueryTerms = <String>{};

    for (final term in queryTerms.expand(tokenize)) {
      if (!seenQueryTerms.add(term)) {
        continue;
      }

      final index = vocab[term];
      if (index == null) {
        continue;
      }

      final termFrequency = frequencies[term] ?? 0;
      if (termFrequency == 0) {
        continue;
      }

      final df = documentFrequency[index];
      final idf = log(1 + (documentCount - df + 0.5) / (df + 0.5));
      final numerator = termFrequency * (k1 + 1);
      final denominator =
          termFrequency + k1 * (1 - b + b * (docLength / averageDocLength));

      rawScore += idf * (numerator / denominator);
    }

    return (rawScore / (rawScore + _bm25Normalisation))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static List<String> _termsForDestination(Destination destination) {
    return [
      ..._repeat(destination.name, 3),
      ..._repeat(destination.district ?? '', 2),
      ..._repeat(destination.municipality ?? '', 1),
      ...destination.category.expand((value) => _repeat(value, 4)),
      ...destination.activities.expand((value) => _repeat(value, 4)),
      ...destination.tags.expand((value) => _repeat(value, 3)),
      ..._repeat(destination.shortDescription, 2),
      destination.fullDescription,
      destination.priceTier,
      destination.accessibility ?? '',
      destination.familyFriendly == true ? 'family friendly safe' : '',
    ].expand(tokenize).toList();
  }

  static Iterable<String> _repeat(String value, int times) sync* {
    for (var index = 0; index < times; index++) {
      yield value;
    }
  }

  static List<String> tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty && !_stopWords.contains(term))
        .toList();
  }
}
