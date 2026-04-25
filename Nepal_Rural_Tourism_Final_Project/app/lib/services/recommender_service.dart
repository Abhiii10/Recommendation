import 'dart:math';

import '../core/utils/app_constants.dart';
import '../domain/entities/recommendation_result.dart';
import '../models/accommodation.dart';
import '../models/destination.dart';
import '../models/recommendation_components.dart';
import '../models/user_preferences.dart';
import 'user_profile_service.dart';

export '../domain/entities/recommendation_result.dart';

class RecommenderService {
  final Map<String, List<Map<String, dynamic>>> similarPlaces;
  final UserProfileService? userProfileService;
  _TfIdfIndex? _index;

  RecommenderService(this.similarPlaces, {this.userProfileService});

  List<RecommendationResult> recommendByPreferences(
    UserPreferences prefs,
    List<Destination> destinations, {
    List<Accommodation> accommodations = const [],
    bool? familyFriendly,
    int? adventureLevel,
    int topK = 10,
  }) {
    _index ??= _TfIdfIndex.build(destinations);

    final queryTextVector = _index!.queryVector(_queryTerms(prefs));
    final queryNumericVector = _numericQueryVector(
      prefs,
      familyFriendly: familyFriendly,
      adventureLevel: adventureLevel,
    );

    final candidates = <_CandidateScore>[];

    for (final destination in destinations) {
      final documentVector = _index!.documentVector(destination.id);
      if (documentVector == null) {
        continue;
      }

      final textSimilarity = _clamp(
        _cosineSimilarity(queryTextVector, documentVector),
      );
      final numericSimilarity = _clamp(
        _cosineSimilarity(queryNumericVector, _numericDocVector(destination)),
      );

      final retrievalScore = _clamp(
        textSimilarity * AppConstants.retrievalTextWeight +
            numericSimilarity * AppConstants.retrievalNumericWeight,
      );

      if (retrievalScore <= 0) {
        continue;
      }

      candidates.add(
        _CandidateScore(
          destination: destination,
          textSimilarity: textSimilarity,
          numericSimilarity: numericSimilarity,
          retrievalScore: retrievalScore,
        ),
      );
    }

    candidates.sort((a, b) => b.retrievalScore.compareTo(a.retrievalScore));
    final stageOne = candidates
        .take(min(AppConstants.offlineRetrieveTopK, candidates.length))
        .toList();

    final reranked = <RecommendationResult>[];

    for (final candidate in stageOne) {
      final destination = candidate.destination;
      final activityMatch = _activityMatch(destination, prefs.activity);
      final vibeMatch = _vibeMatch(destination, prefs.vibe);
      final seasonMatch = _seasonMatch(destination, prefs.season);
      final budgetMatch = _budgetMatch(destination.priceTier, prefs.budget);
      final accessibilityFit = _accessibilityScore(destination.accessibility);
      final familyFit = _familyFit(destination, familyFriendly);
      final accommodationFit = _accommodationFit(
        destination,
        accommodations,
        prefs.budget,
      );

      final contextualScore = _clamp(
        activityMatch * AppConstants.activityComponentWeight +
            vibeMatch * AppConstants.vibeComponentWeight +
            seasonMatch * AppConstants.seasonComponentWeight +
            budgetMatch * AppConstants.budgetComponentWeight +
            accessibilityFit * AppConstants.accessibilityComponentWeight +
            familyFit * AppConstants.familyComponentWeight +
            accommodationFit * AppConstants.accommodationComponentWeight,
      );

      final finalScore = _clamp(
        candidate.textSimilarity * AppConstants.finalTextScoreWeight +
            candidate.numericSimilarity * AppConstants.finalNumericScoreWeight +
            contextualScore * AppConstants.finalContextualScoreWeight,
      );

      final components = RecommendationComponents(
        semantic: candidate.textSimilarity,
        collaborative: 0.0,
        activityMatch: activityMatch,
        vibeMatch: vibeMatch,
        seasonMatch: seasonMatch,
        budgetMatch: budgetMatch,
        accessibilityFit: accessibilityFit,
        familyFit: familyFit,
        accommodationFit: accommodationFit,
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
            numericSimilarity: candidate.numericSimilarity,
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
    _index ??= _TfIdfIndex.build(destinations);

    final seedVector = _index!.documentVector(seed.id);
    if (seedVector == null) {
      return [];
    }

    final explicitMatches = _offlineSimilarMatches(seed);
    final scored = <RecommendationResult>[];

    for (final destination in destinations) {
      if (destination.id == seed.id) {
        continue;
      }

      final documentVector = _index!.documentVector(destination.id);
      if (documentVector == null) {
        continue;
      }

      var similarity = _clamp(_cosineSimilarity(seedVector, documentVector));
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
    return scored.take(topK).toList();
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
        adventure = 0.9;
        nature = 0.8;
        break;
      case 'culture':
        culture = 1.0;
        adventure = 0.3;
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
        nature = 0.9;
        adventure = 0.4;
        break;
      case 'photography':
      case 'viewpoint':
        nature = 0.8;
        culture = 0.6;
        break;
    }

    switch (vibe) {
      case 'family':
        family = 1.0;
        adventure = adventure.clamp(0.0, 0.6);
        accessibility = 0.9;
        break;
      case 'adventure':
        adventure = (adventure + 0.2).clamp(0.0, 1.0);
        break;
      case 'cultural':
        culture = (culture + 0.2).clamp(0.0, 1.0);
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
    final queryTerms = _activityAliases(_norm(activity)).toSet();

    if (queryTerms.isEmpty) {
      return 0.5;
    }
    if (queryTerms.any(terms.contains)) {
      return 1.0;
    }
    if (queryTerms.any(
      (query) => terms.any((term) => term.contains(query) || query.contains(term)),
    )) {
      return 0.6;
    }
    return 0.0;
  }

  double _vibeMatch(Destination destination, String vibe) {
    final terms = _allTerms(destination);
    final queryTerms = _vibeAliases(_norm(vibe)).toSet();

    if (queryTerms.isEmpty) {
      return 0.5;
    }
    if (queryTerms.any(terms.contains)) {
      return 1.0;
    }
    if (queryTerms.any(
      (query) => terms.any((term) => term.contains(query) || query.contains(term)),
    )) {
      return 0.55;
    }
    return 0.0;
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
      return 0.0;
    }

    return (actualIndex - preferredIndex).abs() == 1 ? 0.65 : 0.0;
  }

  double _accessibilityScore(String? accessibility) {
    switch (_norm(accessibility ?? '')) {
      case 'easy':
        return 1.0;
      case 'moderate':
        return 0.6;
      case 'difficult':
        return 0.2;
      case 'very difficult':
        return 0.1;
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
      return 0.0;
    }
    return 0.55;
  }

  double _accommodationFit(
    Destination destination,
    List<Accommodation> accommodations,
    String preferredBudget,
  ) {
    final stays = accommodations.where((accommodation) {
      final matchesId = accommodation.destinationId == destination.id;
      final matchesName = _norm(accommodation.destinationName) == _norm(destination.name);
      return matchesId || matchesName;
    }).toList();

    if (stays.isEmpty) {
      return 0.35;
    }

    final preferred = _norm(preferredBudget);
    var best = 0.45;

    for (final stay in stays) {
      final stayBudget = _norm(stay.priceRange ?? '');
      if (stayBudget.isNotEmpty && stayBudget == preferred) {
        best = max(best, 1.0);
      } else if (stayBudget.isNotEmpty) {
        best = max(best, 0.7);
      } else {
        best = max(best, 0.45);
      }
    }

    return best;
  }

  List<RecommendationResult> _diversify(
    List<RecommendationResult> ranked, {
    required int topK,
    required int maxPerDistrict,
    required int maxPerCategory,
  }) {
    final districtCount = <String, int>{};
    final categoryCount = <String, int>{};
    final diversified = <RecommendationResult>[];

    for (final result in ranked) {
      if (diversified.length >= topK) {
        break;
      }

      final district = _norm(result.destination.district ?? 'unknown');
      final category = _norm(result.destination.primaryCategory);

      final districtMatches = districtCount[district] ?? 0;
      final categoryMatches = categoryCount[category] ?? 0;

      if (districtMatches >= maxPerDistrict || categoryMatches >= maxPerCategory) {
        continue;
      }

      districtCount[district] = districtMatches + 1;
      categoryCount[category] = categoryMatches + 1;
      diversified.add(result);
    }

    if (diversified.length < topK) {
      final seen = diversified.map((result) => result.destination.id).toSet();
      for (final result in ranked) {
        if (diversified.length >= topK) {
          break;
        }
        if (seen.add(result.destination.id)) {
          diversified.add(result);
        }
      }
    }

    return diversified;
  }

  List<String> _buildExplainableReasons({
    required Destination destination,
    required UserPreferences prefs,
    required bool? familyFriendly,
    required double textSimilarity,
    required double numericSimilarity,
    required RecommendationComponents components,
  }) {
    final weightedContributions = <_WeightedReason>[
      _WeightedReason(
        score: textSimilarity * AppConstants.finalTextScoreWeight,
        reason: 'Strong text match to your selected travel profile',
      ),
      _WeightedReason(
        score: numericSimilarity * AppConstants.finalNumericScoreWeight,
        reason: 'Feature profile matches your preferred trip style',
      ),
      _WeightedReason(
        score: components.activityMatch *
            AppConstants.finalContextualScoreWeight *
            AppConstants.activityComponentWeight,
        reason: 'Matches your activity',
      ),
      _WeightedReason(
        score: components.vibeMatch *
            AppConstants.finalContextualScoreWeight *
            AppConstants.vibeComponentWeight,
        reason: 'Matches your preferred vibe',
      ),
      _WeightedReason(
        score: components.seasonMatch *
            AppConstants.finalContextualScoreWeight *
            AppConstants.seasonComponentWeight,
        reason: 'Best season match',
      ),
      _WeightedReason(
        score: components.budgetMatch *
            AppConstants.finalContextualScoreWeight *
            AppConstants.budgetComponentWeight,
        reason: 'Fits budget',
      ),
      _WeightedReason(
        score: components.accessibilityFit *
            AppConstants.finalContextualScoreWeight *
            AppConstants.accessibilityComponentWeight,
        reason: 'Accessibility fit supports this trip',
      ),
      _WeightedReason(
        score: components.familyFit *
            AppConstants.finalContextualScoreWeight *
            AppConstants.familyComponentWeight,
        reason: familyFriendly == true ? 'Family friendly' : 'Flexible for mixed groups',
      ),
      _WeightedReason(
        score: components.accommodationFit *
            AppConstants.finalContextualScoreWeight *
            AppConstants.accommodationComponentWeight,
        reason: 'Accommodation available',
      ),
    ].where((entry) => entry.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

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

    return weightedContributions.take(3).map((entry) {
      final percent = ((entry.score / total) * 100).round();
      return '${entry.reason} ($percent%)';
    }).toList();
  }

  List<String> _buildSimilarityReasons(Destination seed, Destination destination) {
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
        _norm(prefs.budget),
        _norm(prefs.season),
      ];

  List<String> _activityAliases(String activity) {
    const aliases = <String, List<String>>{
      'culture': [
        'culture',
        'cultural',
        'heritage',
        'village',
        'museum',
        'pilgrimage',
      ],
      'hiking': ['hiking', 'trekking', 'adventure', 'trek', 'trail'],
      'adventure': [
        'adventure',
        'hiking',
        'trekking',
        'rafting',
        'paragliding',
        'zipline',
      ],
      'wildlife': ['wildlife', 'bird', 'forest', 'nature', 'conservation'],
      'relaxation': ['relax', 'peaceful', 'lake', 'scenic', 'retreat'],
      'lake': ['lake', 'boating', 'waterside', 'scenic'],
      'photography': ['photography', 'viewpoint', 'panorama', 'scenic'],
      'viewpoint': ['viewpoint', 'panorama', 'sunrise', 'scenic'],
    };
    return aliases[activity] ?? [activity];
  }

  List<String> _vibeAliases(String vibe) {
    const aliases = <String, List<String>>{
      'family': ['family', 'easy', 'safe', 'picnic'],
      'adventure': ['adventure', 'thrill', 'trekking', 'rafting'],
      'cultural': ['culture', 'heritage', 'local', 'traditional'],
      'quiet': ['quiet', 'peaceful', 'relax', 'retreat'],
      'peaceful': ['peaceful', 'quiet', 'relax', 'retreat'],
      'photography': ['scenic', 'viewpoint', 'panorama'],
    };
    return aliases[vibe] ?? [vibe];
  }

  Set<String> _allTerms(Destination destination) {
    return {
      ...destination.activities.map(_norm),
      ...destination.category.map(_norm),
      ...destination.tags.map(_norm),
    };
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
    final magnitude = sqrt(values.fold(0.0, (sum, value) => sum + value * value));
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
  final double numericSimilarity;
  final double retrievalScore;

  const _CandidateScore({
    required this.destination,
    required this.textSimilarity,
    required this.numericSimilarity,
    required this.retrievalScore,
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

class _TfIdfIndex {
  final Map<String, int> vocab;
  final Map<String, List<double>> docVectors;

  _TfIdfIndex({
    required this.vocab,
    required this.docVectors,
  });

  factory _TfIdfIndex.build(List<Destination> destinations) {
    final vocab = <String, int>{};
    final docTerms = <String, List<String>>{};

    for (final destination in destinations) {
      final terms = <String>[
        ...destination.category,
        ...destination.activities,
        ...destination.tags,
        destination.description,
        destination.type,
        destination.district ?? '',
      ].expand((value) => _tokenize(value)).toList();

      docTerms[destination.id] = terms;

      for (final term in terms) {
        vocab.putIfAbsent(term, () => vocab.length);
      }
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
        final idf = log((documentCount + 1) / (documentFrequency[index] + 1)) + 1.0;
        tf[index] = tf[index] * idf;
      }

      final magnitude = sqrt(tf.fold(0.0, (sum, value) => sum + value * value));
      docVectors[entry.key] = magnitude == 0
          ? tf
          : tf.map((value) => value / magnitude).toList();
    }

    return _TfIdfIndex(vocab: vocab, docVectors: docVectors);
  }

  List<double>? documentVector(String id) => docVectors[id];

  List<double> queryVector(List<String> terms) {
    final vector = List<double>.filled(vocab.length, 0.0);
    for (final term in terms.expand(_tokenize)) {
      final index = vocab[term];
      if (index != null) {
        vector[index] += 1.0;
      }
    }

    final magnitude = sqrt(vector.fold(0.0, (sum, value) => sum + value * value));
    return magnitude == 0
        ? vector
        : vector.map((value) => value / magnitude).toList();
  }

  static List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
  }
}
