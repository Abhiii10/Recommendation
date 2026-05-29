import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rural_tourism_app/models/accommodation.dart';
import 'package:rural_tourism_app/models/destination.dart';
import 'package:rural_tourism_app/models/user_preferences.dart';
import 'package:rural_tourism_app/services/recommender_service.dart';

const int defaultK = 10;
const double defaultMinimumNdcg = 0.90;
const double defaultMinimumPrecision = 0.95;

void main(List<String> args) {
  final k = _parseK(args);
  final minNdcg = _parseDouble(args, '--min-ndcg=', defaultMinimumNdcg);
  final minPrecision = _parseDouble(
    args,
    '--min-precision=',
    defaultMinimumPrecision,
  );
  final destinations =
      _loadDestinations('assets/data/backend_destinations.json');
  final accommodations = _loadAccommodations('assets/data/accommodations.json');
  final embeddings =
      _loadEmbeddings('assets/embeddings/destination_embeddings.json');
  final service = RecommenderService(
    const {},
    destinationEmbeddings: embeddings,
  );

  final profiles = _evaluationProfiles(k);
  final results = <ProfileEvaluation>[];
  final destinationsById = {
    for (final destination in destinations) destination.id: destination,
  };
  final coveredDestinationIds = <String>{};
  final coveredDistricts = <String>{};
  final coveredCategories = <String>{};
  final baselineCoveredDestinationIds = <String>{};
  final baselineCoveredDistricts = <String>{};
  final baselineCoveredCategories = <String>{};

  for (final profile in profiles) {
    final recommendations = service.recommendByPreferences(
      UserPreferences(
        activity: profile.activity,
        budget: profile.budget,
        season: profile.season,
        vibe: profile.vibe,
      ),
      destinations,
      accommodations: accommodations,
      familyFriendly: profile.familyFriendly,
      adventureLevel: profile.adventureLevel,
      topK: k,
    );

    final predictedIds =
        recommendations.map((item) => item.destination.id).toList();
    coveredDestinationIds.addAll(predictedIds);
    coveredDistricts.addAll(
      recommendations.map((item) => item.destination.district ?? 'unknown'),
    );
    coveredCategories.addAll(
      recommendations.map((item) => item.destination.primaryCategory),
    );

    final grades = {
      for (final destination in destinations)
        destination.id: _gradeDestination(
          profile,
          destination,
          accommodations,
        ),
    };

    final baselineIds = _basicBaseline(profile, destinations, k);
    baselineCoveredDestinationIds.addAll(baselineIds);
    for (final id in baselineIds) {
      final destination = destinationsById[id];
      if (destination == null) continue;
      baselineCoveredDistricts.add(destination.district ?? 'unknown');
      baselineCoveredCategories.add(destination.primaryCategory);
    }

    results.add(
      ProfileEvaluation(
        profile: profile,
        recommendations: recommendations,
        grades: grades,
        upgradedMetrics: Metrics.from(predictedIds, grades, k),
        baselineMetrics: Metrics.from(baselineIds, grades, k),
        baselineIds: baselineIds,
      ),
    );
  }

  final aggregate = AggregateEvaluation(
    destinationCount: destinations.length,
    accommodationCount: accommodations.length,
    profileCount: profiles.length,
    catalogCoverage: coveredDestinationIds.length / destinations.length,
    districtCoverage: coveredDistricts.length / _districtCount(destinations),
    categoryCoverage: coveredCategories.length / _categoryCount(destinations),
    baselineCatalogCoverage:
        baselineCoveredDestinationIds.length / destinations.length,
    baselineDistrictCoverage:
        baselineCoveredDistricts.length / _districtCount(destinations),
    baselineCategoryCoverage:
        baselineCoveredCategories.length / _categoryCount(destinations),
    averageUpgradedMetrics: Metrics.average(
      results.map((result) => result.upgradedMetrics),
    ),
    averageBaselineMetrics: Metrics.average(
      results.map((result) => result.baselineMetrics),
    ),
  );

  final outputDir = Directory('../evaluation')..createSync(recursive: true);
  final jsonPath = '${outputDir.path}/offline_results.json';
  final reportPath = '${outputDir.path}/offline_report.md';

  File(jsonPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'k': k,
      'dataset': {
        'destinations': destinations.length,
        'accommodations': accommodations.length,
        'destination_embeddings': embeddings.length,
        'province': 'Gandaki',
      },
      'engine': {
        'name': 'Advanced Offline Hybrid Recommender',
        'retrieval':
            'TF-IDF + BM25 + offline semantic embeddings + numeric profile + quality/accommodation priors',
        'ranking':
            'contextual scoring + embedding similarity + quality/popularity + local personalization + diversity',
        'baseline': 'basic exact keyword and filter matcher',
      },
      'aggregate': aggregate.toJson(),
      'profiles': results.map((result) => result.toJson(k)).toList(),
    }),
  );

  File(reportPath)
      .writeAsStringSync(_buildMarkdownReport(results, aggregate, k));

  _printConsoleSummary(results, aggregate, k, jsonPath, reportPath);
  _enforceMetricGate(aggregate, minNdcg, minPrecision);
}

int _parseK(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--k=')) {
      return int.tryParse(arg.substring(4)) ?? defaultK;
    }
  }
  return defaultK;
}

double _parseDouble(List<String> args, String prefix, double fallback) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return double.tryParse(arg.substring(prefix.length)) ?? fallback;
    }
  }
  return fallback;
}

List<Destination> _loadDestinations(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
  return decoded
      .map((item) =>
          Destination.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

List<Accommodation> _loadAccommodations(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
  return decoded
      .map(
        (item) =>
            Accommodation.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

Map<String, List<double>> _loadEmbeddings(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const {};
  }

  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = decoded['entries'];
  if (entries is! Map) {
    return const {};
  }

  return {
    for (final entry in entries.entries)
      entry.key.toString(): (entry.value as List)
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false),
  };
}

List<EvaluationProfile> _evaluationProfiles(int k) {
  return [
    EvaluationProfile(
      key: 'family_lake_escape',
      name: 'Family lake escape',
      activity: 'boating',
      budget: 'budget',
      season: 'spring',
      vibe: 'family',
      familyFriendly: true,
      adventureLevel: 1,
      description: 'Low-cost, easy, family-friendly lakeside recommendation.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'high_adventure_trek',
      name: 'High adventure trek',
      activity: 'trekking',
      budget: 'medium',
      season: 'autumn',
      vibe: 'adventure',
      familyFriendly: false,
      adventureLevel: 5,
      description: 'Demanding mountain routes for adventure travelers.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'cultural_homestay',
      name: 'Cultural homestay',
      activity: 'culture',
      budget: 'budget',
      season: 'spring',
      vibe: 'cultural',
      familyFriendly: true,
      adventureLevel: 2,
      description:
          'Village culture, homestay, food, and accessible local life.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'pilgrimage_route',
      name: 'Pilgrimage route',
      activity: 'pilgrimage',
      budget: 'budget',
      season: 'winter',
      vibe: 'spiritual',
      familyFriendly: true,
      adventureLevel: 1,
      description: 'Budget spiritual sites with family-friendly access.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'wildlife_nature',
      name: 'Wildlife and nature',
      activity: 'wildlife',
      budget: 'budget',
      season: 'autumn',
      vibe: 'nature',
      familyFriendly: false,
      adventureLevel: 2,
      description:
          'Community forests, birding, river plains, and lowland nature.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'scenic_photography',
      name: 'Scenic photography',
      activity: 'photography',
      budget: 'medium',
      season: 'autumn',
      vibe: 'scenic',
      familyFriendly: true,
      adventureLevel: 2,
      description:
          'Viewpoints, sunrise, ridges, and photo-friendly landscapes.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'budget_relaxation',
      name: 'Budget relaxation',
      activity: 'relaxation',
      budget: 'budget',
      season: 'winter',
      vibe: 'peaceful',
      familyFriendly: true,
      adventureLevel: 1,
      description: 'Quiet low-cost rural stays with soft nature access.',
      topK: k,
    ),
    EvaluationProfile(
      key: 'heritage_market_culture',
      name: 'Heritage and market culture',
      activity: 'culture',
      budget: 'medium',
      season: 'autumn',
      vibe: 'historic',
      familyFriendly: true,
      adventureLevel: 1,
      description:
          'Historic towns, local markets, temples, and easy cultural walks.',
      topK: k,
    ),
  ];
}

int _gradeDestination(
  EvaluationProfile profile,
  Destination destination,
  List<Accommodation> accommodations,
) {
  final terms = _destinationTerms(destination);
  final activity =
      _weightedTermMatch(terms, _activityAliases(profile.activity));
  final vibe = _weightedTermMatch(terms, _vibeAliases(profile.vibe));
  final season = _seasonScore(destination, profile.season);
  final budget = _budgetScore(destination.priceTier, profile.budget);
  final family =
      _familyScore(destination.familyFriendly, profile.familyFriendly);
  final adventure = _adventureScore(
    destination.adventureLevel,
    profile.adventureLevel,
  );
  final accommodation = _accommodationScore(
    destination,
    accommodations,
    profile.budget,
  );
  final quality = _qualityScore(destination);

  final intent = activity * 0.64 + vibe * 0.36;
  final constraints = season * 0.22 +
      budget * 0.18 +
      family * 0.14 +
      adventure * 0.16 +
      accommodation * 0.16 +
      quality * 0.14;
  final score = intent * 0.72 + constraints * 0.28;

  if (activity < 0.20 && vibe < 0.25) {
    return constraints >= 0.76 ? 1 : 0;
  }

  if (score >= 0.78 && activity >= 0.42) return 3;
  if (score >= 0.56 && (activity >= 0.28 || vibe >= 0.45)) return 2;
  if (score >= 0.36) return 1;
  return 0;
}

List<String> _basicBaseline(
  EvaluationProfile profile,
  List<Destination> destinations,
  int k,
) {
  final scored = <({Destination destination, double score})>[];

  for (final destination in destinations) {
    final terms = _destinationTerms(destination);
    final activity = _exactTermMatch(terms, _normalize(profile.activity));
    final vibe = _exactTermMatch(terms, _normalize(profile.vibe));
    final season = destination.bestSeason
            .map(_normalize)
            .contains(_normalize(profile.season))
        ? 1.0
        : 0.0;
    final budget =
        _normalize(destination.priceTier) == _normalize(profile.budget)
            ? 1.0
            : 0.0;
    final family =
        destination.familyFriendly == profile.familyFriendly ? 1.0 : 0.0;

    final score = activity * 0.38 +
        vibe * 0.20 +
        season * 0.16 +
        budget * 0.14 +
        family * 0.08 +
        _qualityScore(destination) * 0.04;

    scored.add((destination: destination, score: score));
  }

  scored.sort((left, right) => right.score.compareTo(left.score));
  return scored.take(k).map((item) => item.destination.id).toList();
}

double _exactTermMatch(Set<String> terms, String query) {
  if (query.isEmpty) return 0.0;
  return terms.contains(query) ? 1.0 : 0.0;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

Set<String> _destinationTerms(Destination destination) {
  final raw = [
    destination.name,
    destination.district ?? '',
    destination.municipality ?? '',
    ...destination.category,
    ...destination.activities,
    ...destination.tags,
    destination.shortDescription,
    destination.fullDescription,
    destination.priceTier,
    destination.accessibility ?? '',
  ].join(' ');

  final tokens = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toSet();

  for (final category in destination.category) {
    tokens.add(category.toLowerCase());
  }
  for (final activity in destination.activities) {
    tokens.add(activity.toLowerCase());
  }
  for (final tag in destination.tags) {
    tokens.add(tag.toLowerCase());
  }

  return tokens;
}

double _weightedTermMatch(Set<String> terms, Set<String> queryTerms) {
  if (queryTerms.isEmpty) return 0.0;

  var exact = 0;
  var partial = 0;

  for (final query in queryTerms) {
    if (terms.contains(query)) {
      exact += 1;
      continue;
    }
    if (terms.any((term) => term.contains(query) || query.contains(term))) {
      partial += 1;
    }
  }

  return ((exact + partial * 0.55) / queryTerms.length).clamp(0.0, 1.0);
}

double _seasonScore(Destination destination, String season) {
  final query = season.toLowerCase();
  final seasons =
      destination.bestSeason.map((item) => item.toLowerCase()).toSet();
  if (seasons.contains(query) || seasons.contains('year-round')) {
    return 1.0;
  }

  const shoulder = {
    'spring': {'autumn', 'winter'},
    'autumn': {'spring', 'winter'},
    'winter': {'autumn', 'spring'},
    'monsoon': {'summer'},
    'summer': {'monsoon'},
  };

  return (shoulder[query] ?? const {}).any(seasons.contains) ? 0.45 : 0.0;
}

double _budgetScore(String actualBudget, String preferredBudget) {
  final actual = actualBudget.toLowerCase();
  final preferred = preferredBudget.toLowerCase();
  if (actual == preferred) return 1.0;

  const order = ['budget', 'medium', 'premium'];
  final actualIndex = order.indexOf(actual);
  final preferredIndex = order.indexOf(preferred);
  if (actualIndex == -1 || preferredIndex == -1) return 0.35;

  return (actualIndex - preferredIndex).abs() == 1 ? 0.65 : 0.15;
}

double _familyScore(
    bool? destinationFamilyFriendly, bool? profileFamilyFriendly) {
  if (profileFamilyFriendly == null) return 0.5;
  if (profileFamilyFriendly && destinationFamilyFriendly == true) return 1.0;
  if (profileFamilyFriendly && destinationFamilyFriendly != true) return 0.15;
  if (!profileFamilyFriendly && destinationFamilyFriendly != true) return 1.0;
  return 0.55;
}

double _adventureScore(int? destinationAdventure, int profileAdventure) {
  final actual = destinationAdventure ?? 3;
  final diff = (actual - profileAdventure).abs();
  if (diff == 0) return 1.0;
  if (diff == 1) return 0.82;
  if (diff == 2) return 0.48;
  return 0.18;
}

double _accommodationScore(
  Destination destination,
  List<Accommodation> accommodations,
  String preferredBudget,
) {
  final stays = accommodations
      .where((stay) =>
          stay.destinationId == destination.id ||
          stay.destinationName.toLowerCase() == destination.name.toLowerCase())
      .toList();
  if (stays.isEmpty) return 0.0;

  final coverage = min(stays.length, 3) / 3.0;
  final budget = stays
      .map((stay) => _budgetScore(stay.priceRange ?? '', preferredBudget))
      .fold<double>(0.0, max);

  return (coverage * 0.55 + budget * 0.45).clamp(0.0, 1.0);
}

double _qualityScore(Destination destination) {
  var score = 0.0;
  if (destination.confidence == 'high') {
    score += 0.35;
  } else if (destination.confidence == 'medium') {
    score += 0.25;
  } else {
    score += 0.12;
  }
  score += min(destination.tags.length, 12) / 12.0 * 0.25;
  score += min(destination.activities.length, 5) / 5.0 * 0.15;
  score += min(destination.bestSeason.length, 4) / 4.0 * 0.10;
  if (destination.latitude != null && destination.longitude != null) {
    score += 0.10;
  }
  if ((destination.municipality ?? '').isNotEmpty) {
    score += 0.05;
  }
  return score.clamp(0.0, 1.0);
}

Set<String> _activityAliases(String activity) {
  const aliases = {
    'boating': {'boating', 'lake', 'waterside', 'relaxation', 'nature'},
    'trekking': {
      'trekking',
      'hiking',
      'trail',
      'ridge',
      'viewpoint',
      'adventure',
      'climbing',
      'mountain',
      'pass'
    },
    'culture': {
      'culture',
      'cultural',
      'heritage',
      'village',
      'homestay',
      'local'
    },
    'pilgrimage': {
      'pilgrimage',
      'temple',
      'spiritual',
      'monastery',
      'dham',
      'gumba'
    },
    'wildlife': {'wildlife', 'birding', 'forest', 'nature', 'community forest'},
    'photography': {
      'photography',
      'viewpoint',
      'panorama',
      'scenic',
      'sunrise'
    },
    'relaxation': {
      'relaxation',
      'peaceful',
      'quiet',
      'retreat',
      'nature',
      'lake'
    },
  };
  return aliases[activity] ?? {activity};
}

Set<String> _vibeAliases(String vibe) {
  const aliases = {
    'family': {'family', 'easy', 'safe', 'homestay', 'village'},
    'adventure': {'adventure', 'trekking', 'trail', 'pass', 'base'},
    'cultural': {'culture', 'cultural', 'heritage', 'traditional', 'village'},
    'spiritual': {'spiritual', 'pilgrimage', 'temple', 'monastery'},
    'nature': {'nature', 'wildlife', 'forest', 'river', 'lake'},
    'scenic': {'scenic', 'viewpoint', 'panorama', 'photography', 'sunrise'},
    'peaceful': {'peaceful', 'quiet', 'relaxation', 'retreat', 'village'},
    'historic': {'heritage', 'history', 'cultural', 'old settlement', 'market'},
  };
  return aliases[vibe] ?? {vibe};
}

int _districtCount(List<Destination> destinations) {
  return destinations.map((item) => item.district ?? 'unknown').toSet().length;
}

int _categoryCount(List<Destination> destinations) {
  return destinations.map((item) => item.primaryCategory).toSet().length;
}

String _buildMarkdownReport(
  List<ProfileEvaluation> results,
  AggregateEvaluation aggregate,
  int k,
) {
  final buffer = StringBuffer()
    ..writeln('# Offline Recommender Evaluation')
    ..writeln()
    ..writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln()
    ..writeln('Dataset:')
    ..writeln()
    ..writeln('- Destinations: ${aggregate.destinationCount}')
    ..writeln('- Accommodations: ${aggregate.accommodationCount}')
    ..writeln('- Province scope: Gandaki only')
    ..writeln()
    ..writeln('Engine under test:')
    ..writeln()
    ..writeln('- Hybrid TF-IDF + BM25 retrieval')
    ..writeln('- Offline semantic destination embeddings')
    ..writeln('- Numeric traveler profile matching')
    ..writeln('- Contextual reranking')
    ..writeln('- Accommodation, quality, and cold-start priors')
    ..writeln('- District/category diversification')
    ..writeln()
    ..writeln('## Aggregate')
    ..writeln()
    ..writeln('| Metric | Advanced Offline | Basic Baseline | Delta |')
    ..writeln('| --- | ---: | ---: | ---: |')
    ..writeln(_metricRow(
        'Precision@$k',
        aggregate.averageUpgradedMetrics.precision,
        aggregate.averageBaselineMetrics.precision))
    ..writeln(_metricRow('Recall@$k', aggregate.averageUpgradedMetrics.recall,
        aggregate.averageBaselineMetrics.recall))
    ..writeln(_metricRow('nDCG@$k', aggregate.averageUpgradedMetrics.ndcg,
        aggregate.averageBaselineMetrics.ndcg))
    ..writeln(_metricRow('MRR', aggregate.averageUpgradedMetrics.mrr,
        aggregate.averageBaselineMetrics.mrr))
    ..writeln()
    ..writeln('Coverage across evaluation profiles:')
    ..writeln()
    ..writeln('| Coverage | Advanced Offline | Basic Baseline | Delta |')
    ..writeln('| --- | ---: | ---: | ---: |')
    ..writeln(_coverageRow('Catalog', aggregate.catalogCoverage,
        aggregate.baselineCatalogCoverage))
    ..writeln(_coverageRow('District', aggregate.districtCoverage,
        aggregate.baselineDistrictCoverage))
    ..writeln(_coverageRow('Category', aggregate.categoryCoverage,
        aggregate.baselineCategoryCoverage))
    ..writeln()
    ..writeln('## Profile Results')
    ..writeln()
    ..writeln(
        '| Profile | P@$k | R@$k | nDCG@$k | MRR | Baseline nDCG | Top result |')
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | --- |');

  for (final result in results) {
    final top = result.recommendations.isEmpty
        ? 'None'
        : result.recommendations.first.destination.name;
    buffer.writeln(
      '| ${result.profile.name} | ${_fmt(result.upgradedMetrics.precision)} | ${_fmt(result.upgradedMetrics.recall)} | ${_fmt(result.upgradedMetrics.ndcg)} | ${_fmt(result.upgradedMetrics.mrr)} | ${_fmt(result.baselineMetrics.ndcg)} | $top |',
    );
  }

  for (final result in results) {
    buffer
      ..writeln()
      ..writeln('### ${result.profile.name}')
      ..writeln()
      ..writeln(result.profile.description)
      ..writeln()
      ..writeln(
          '| Rank | Destination | District | Category | Score | Grade | Why |')
      ..writeln('| ---: | --- | --- | --- | ---: | ---: | --- |');

    for (var index = 0; index < result.recommendations.length; index++) {
      final recommendation = result.recommendations[index];
      final destination = recommendation.destination;
      final reason = recommendation.reasons.take(2).join('; ');
      buffer.writeln(
        '| ${index + 1} | ${destination.name} | ${destination.district ?? ''} | ${destination.primaryCategory} | ${_fmt(recommendation.score)} | ${result.grades[destination.id] ?? 0} | $reason |',
      );
    }
  }

  return buffer.toString();
}

String _metricRow(String label, double upgraded, double baseline) {
  final delta = upgraded - baseline;
  return '| $label | ${_fmt(upgraded)} | ${_fmt(baseline)} | ${delta >= 0 ? '+' : ''}${_fmt(delta)} |';
}

String _coverageRow(String label, double upgraded, double baseline) {
  final delta = upgraded - baseline;
  return '| $label | ${_pct(upgraded)} | ${_pct(baseline)} | ${delta >= 0 ? '+' : ''}${_pct(delta)} |';
}

void _printConsoleSummary(
  List<ProfileEvaluation> results,
  AggregateEvaluation aggregate,
  int k,
  String jsonPath,
  String reportPath,
) {
  print('Offline recommender evaluation complete.');
  print('Destinations: ${aggregate.destinationCount}');
  print('Accommodations: ${aggregate.accommodationCount}');
  print('Profiles: ${aggregate.profileCount}');
  print('');
  print('Average metrics at K=$k');
  print('  Precision: ${_fmt(aggregate.averageUpgradedMetrics.precision)}');
  print('  Recall:    ${_fmt(aggregate.averageUpgradedMetrics.recall)}');
  print('  nDCG:      ${_fmt(aggregate.averageUpgradedMetrics.ndcg)}');
  print('  MRR:       ${_fmt(aggregate.averageUpgradedMetrics.mrr)}');
  print('');
  print('Baseline nDCG: ${_fmt(aggregate.averageBaselineMetrics.ndcg)}');
  print(
      'Delta nDCG:    ${_fmt(aggregate.averageUpgradedMetrics.ndcg - aggregate.averageBaselineMetrics.ndcg)}');
  print('Catalog coverage: ${_pct(aggregate.catalogCoverage)}');
  print('District coverage: ${_pct(aggregate.districtCoverage)}');
  print('Category coverage: ${_pct(aggregate.categoryCoverage)}');
  print(
      'Baseline catalog coverage: ${_pct(aggregate.baselineCatalogCoverage)}');
  print('');
  print('JSON: $jsonPath');
  print('Report: $reportPath');
}

void _enforceMetricGate(
  AggregateEvaluation aggregate,
  double minNdcg,
  double minPrecision,
) {
  final ndcg = aggregate.averageUpgradedMetrics.ndcg;
  final precision = aggregate.averageUpgradedMetrics.precision;

  if (ndcg < minNdcg || precision < minPrecision) {
    stderr.writeln(
      'Metric gate failed: nDCG=${_fmt(ndcg)} '
      '(min ${_fmt(minNdcg)}), Precision=${_fmt(precision)} '
      '(min ${_fmt(minPrecision)}).',
    );
    exitCode = 1;
    return;
  }

  print(
    'Metric gate passed: nDCG >= ${_fmt(minNdcg)}, '
    'Precision >= ${_fmt(minPrecision)}.',
  );
}

String _fmt(double value) => value.toStringAsFixed(4);

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

class EvaluationProfile {
  final String key;
  final String name;
  final String activity;
  final String budget;
  final String season;
  final String vibe;
  final bool? familyFriendly;
  final int adventureLevel;
  final String description;
  final int topK;

  const EvaluationProfile({
    required this.key,
    required this.name,
    required this.activity,
    required this.budget,
    required this.season,
    required this.vibe,
    required this.familyFriendly,
    required this.adventureLevel,
    required this.description,
    required this.topK,
  });

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'name': name,
      'activity': activity,
      'budget': budget,
      'season': season,
      'vibe': vibe,
      'family_friendly': familyFriendly,
      'adventure_level': adventureLevel,
      'description': description,
      'top_k': topK,
    };
  }
}

class ProfileEvaluation {
  final EvaluationProfile profile;
  final List<RecommendationResult> recommendations;
  final Map<String, int> grades;
  final Metrics upgradedMetrics;
  final Metrics baselineMetrics;
  final List<String> baselineIds;

  const ProfileEvaluation({
    required this.profile,
    required this.recommendations,
    required this.grades,
    required this.upgradedMetrics,
    required this.baselineMetrics,
    required this.baselineIds,
  });

  Map<String, Object?> toJson(int k) {
    final gradeDistribution = {
      for (final grade in [0, 1, 2, 3])
        grade.toString(): recommendations
            .take(k)
            .where((item) => grades[item.destination.id] == grade)
            .length,
    };

    return {
      'profile': profile.toJson(),
      'metrics': upgradedMetrics.toJson(),
      'baseline_metrics': baselineMetrics.toJson(),
      'grade_distribution_top_k': gradeDistribution,
      'baseline_top_ids': baselineIds,
      'top_results': recommendations.take(k).map((item) {
        return {
          'id': item.destination.id,
          'name': item.destination.name,
          'district': item.destination.district,
          'category': item.destination.primaryCategory,
          'score': double.parse(item.score.toStringAsFixed(4)),
          'grade': grades[item.destination.id] ?? 0,
          'reasons': item.reasons,
        };
      }).toList(),
    };
  }
}

class AggregateEvaluation {
  final int destinationCount;
  final int accommodationCount;
  final int profileCount;
  final double catalogCoverage;
  final double districtCoverage;
  final double categoryCoverage;
  final double baselineCatalogCoverage;
  final double baselineDistrictCoverage;
  final double baselineCategoryCoverage;
  final Metrics averageUpgradedMetrics;
  final Metrics averageBaselineMetrics;

  const AggregateEvaluation({
    required this.destinationCount,
    required this.accommodationCount,
    required this.profileCount,
    required this.catalogCoverage,
    required this.districtCoverage,
    required this.categoryCoverage,
    required this.baselineCatalogCoverage,
    required this.baselineDistrictCoverage,
    required this.baselineCategoryCoverage,
    required this.averageUpgradedMetrics,
    required this.averageBaselineMetrics,
  });

  Map<String, Object?> toJson() {
    return {
      'destination_count': destinationCount,
      'accommodation_count': accommodationCount,
      'profile_count': profileCount,
      'catalog_coverage': double.parse(catalogCoverage.toStringAsFixed(4)),
      'district_coverage': double.parse(districtCoverage.toStringAsFixed(4)),
      'category_coverage': double.parse(categoryCoverage.toStringAsFixed(4)),
      'baseline_catalog_coverage':
          double.parse(baselineCatalogCoverage.toStringAsFixed(4)),
      'baseline_district_coverage':
          double.parse(baselineDistrictCoverage.toStringAsFixed(4)),
      'baseline_category_coverage':
          double.parse(baselineCategoryCoverage.toStringAsFixed(4)),
      'average_metrics': averageUpgradedMetrics.toJson(),
      'average_baseline_metrics': averageBaselineMetrics.toJson(),
    };
  }
}

class Metrics {
  final double precision;
  final double recall;
  final double ndcg;
  final double mrr;

  const Metrics({
    required this.precision,
    required this.recall,
    required this.ndcg,
    required this.mrr,
  });

  factory Metrics.from(List<String> predicted, Map<String, int> grades, int k) {
    final relevant = grades.entries
        .where((entry) => entry.value >= 2)
        .map((entry) => entry.key)
        .toSet();
    final top = predicted.take(k).toList();
    final hits = top.where(relevant.contains).length;

    return Metrics(
      precision: top.isEmpty ? 0.0 : hits / top.length,
      recall: relevant.isEmpty ? 0.0 : hits / relevant.length,
      ndcg: _ndcg(top, grades, k),
      mrr: _mrr(predicted, relevant),
    );
  }

  factory Metrics.average(Iterable<Metrics> metrics) {
    final list = metrics.toList();
    if (list.isEmpty) {
      return const Metrics(precision: 0, recall: 0, ndcg: 0, mrr: 0);
    }

    return Metrics(
      precision: list.map((item) => item.precision).reduce((a, b) => a + b) /
          list.length,
      recall:
          list.map((item) => item.recall).reduce((a, b) => a + b) / list.length,
      ndcg: list.map((item) => item.ndcg).reduce((a, b) => a + b) / list.length,
      mrr: list.map((item) => item.mrr).reduce((a, b) => a + b) / list.length,
    );
  }

  Map<String, double> toJson() {
    return {
      'precision': double.parse(precision.toStringAsFixed(4)),
      'recall': double.parse(recall.toStringAsFixed(4)),
      'ndcg': double.parse(ndcg.toStringAsFixed(4)),
      'mrr': double.parse(mrr.toStringAsFixed(4)),
    };
  }

  static double _ndcg(List<String> predicted, Map<String, int> grades, int k) {
    final actual = _dcg(
      predicted.take(k).map((id) => grades[id] ?? 0).toList(),
    );
    final idealGrades = grades.values.toList()
      ..sort((left, right) => right.compareTo(left));
    final ideal = _dcg(idealGrades.take(k).toList());

    return ideal <= 0 ? 0.0 : actual / ideal;
  }

  static double _dcg(List<int> grades) {
    var score = 0.0;
    for (var index = 0; index < grades.length; index++) {
      score += (pow(2, grades[index]) - 1) / (log(index + 2) / ln2);
    }
    return score;
  }

  static double _mrr(List<String> predicted, Set<String> relevant) {
    for (var index = 0; index < predicted.length; index++) {
      if (relevant.contains(predicted[index])) {
        return 1.0 / (index + 1);
      }
    }
    return 0.0;
  }
}
