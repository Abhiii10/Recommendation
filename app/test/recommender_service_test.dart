import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/models/accommodation.dart';
import 'package:rural_tourism_app/models/destination.dart';
import 'package:rural_tourism_app/models/user_preferences.dart';
import 'package:rural_tourism_app/services/offline_semantic_encoder.dart';
import 'package:rural_tourism_app/services/recommender_service.dart';

void main() {
  group('RecommenderService', () {
    final destinations = [
      const Destination(
        id: '1',
        name: 'Ghachok',
        province: 'Gandaki',
        district: 'Kaski',
        municipality: null,
        category: ['village', 'cultural'],
        activities: ['hiking', 'culture', 'photography'],
        bestSeason: ['spring', 'autumn'],
        budgetLevel: 'budget',
        accessibility: 'moderate',
        familyFriendly: true,
        adventureLevel: 2,
        cultureLevel: 4,
        natureLevel: 4,
        shortDescription: 'Quiet Gurung village with hiking trails.',
        fullDescription:
            'Ghachok is a quiet Gurung village with waterfalls and hiking trails.',
        latitude: 28.3789,
        longitude: 83.9789,
        tags: ['gurung', 'quiet', 'village'],
        source: 'test',
        confidence: 'high',
      ),
      const Destination(
        id: '2',
        name: 'Kahun Danda',
        province: 'Gandaki',
        district: 'Kaski',
        municipality: null,
        category: ['viewpoint', 'adventure'],
        activities: ['hiking', 'photography', 'sightseeing'],
        bestSeason: ['autumn', 'winter'],
        budgetLevel: 'budget',
        accessibility: 'easy',
        familyFriendly: true,
        adventureLevel: 2,
        cultureLevel: 1,
        natureLevel: 4,
        shortDescription: 'Scenic ridge viewpoint east of Pokhara.',
        fullDescription:
            'Kahun Danda is a scenic ridge viewpoint popular for sunrise and hiking.',
        latitude: 28.233,
        longitude: 84.03,
        tags: ['nature', 'photography', 'sunrise', 'viewpoint'],
        source: 'test',
        confidence: 'high',
      ),
    ];

    final service = RecommenderService({
      '1': [
        {'id': '2', 'score': 0.71}
      ]
    });

    test('returns ranked results for preferences', () {
      final prefs = const UserPreferences(
        activity: 'culture',
        budget: 'budget',
        season: 'autumn',
        vibe: 'quiet',
      );

      final results = service.recommendByPreferences(prefs, destinations);

      expect(results, isNotEmpty);
      expect(results.first.destination.name, 'Ghachok');
    });

    test('returns similar destinations from offline similarity map', () {
      final results =
          service.similarToDestination(destinations.first, destinations);

      expect(results, isNotEmpty);
      expect(results.first.destination.name, 'Kahun Danda');
    });

    test('uses contextual and accommodation signals for offline ranking', () {
      final localDestinations = [
        _destination(
          id: 'lake',
          name: 'Begnas Quiet Lake',
          district: 'Kaski',
          category: ['boating', 'nature', 'relaxation'],
          activities: ['boating', 'relaxation', 'photography'],
          tags: ['lake', 'waterside', 'family', 'peaceful'],
          budgetLevel: 'budget',
          accessibility: 'easy',
          familyFriendly: true,
          adventureLevel: 1,
          cultureLevel: 2,
          natureLevel: 5,
        ),
        _destination(
          id: 'trail',
          name: 'Remote High Ridge',
          district: 'Manang',
          category: ['trekking', 'viewpoint', 'nature'],
          activities: ['trekking', 'adventure', 'photography'],
          tags: ['ridge', 'high altitude', 'trail'],
          budgetLevel: 'medium',
          accessibility: 'difficult',
          familyFriendly: false,
          adventureLevel: 5,
          cultureLevel: 2,
          natureLevel: 5,
        ),
        _destination(
          id: 'temple',
          name: 'Hill Temple',
          district: 'Tanahun',
          category: ['pilgrimage', 'cultural', 'spiritual'],
          activities: ['pilgrimage', 'culture', 'photography'],
          tags: ['temple', 'heritage', 'rituals'],
          budgetLevel: 'budget',
          accessibility: 'moderate',
          familyFriendly: true,
          adventureLevel: 1,
          cultureLevel: 5,
          natureLevel: 3,
        ),
      ];

      final accommodations = [
        const Accommodation(
          id: 'acc_lake_1',
          destinationName: 'Begnas Quiet Lake',
          destinationId: 'lake',
          name: 'Begnas Quiet Lake Community Homestay',
          type: 'homestay',
          priceRange: 'budget',
          amenities: ['local food', 'basic rooms', 'lake access'],
          source: 'test',
          confidence: 'high',
        ),
        const Accommodation(
          id: 'acc_lake_2',
          destinationName: 'Begnas Quiet Lake',
          destinationId: 'lake',
          name: 'Begnas Quiet Lake Guest House',
          type: 'guesthouse',
          priceRange: 'budget',
          amenities: ['private rooms', 'local meals', 'family rooms'],
          source: 'test',
          confidence: 'high',
        ),
      ];

      final results = service.recommendByPreferences(
        const UserPreferences(
          activity: 'boating',
          budget: 'budget',
          season: 'spring',
          vibe: 'family',
        ),
        localDestinations,
        accommodations: accommodations,
        familyFriendly: true,
        adventureLevel: 1,
      );

      expect(results.first.destination.id, 'lake');
      expect(results.first.components.accommodationFit, greaterThan(0.8));
      expect(results.first.reasons.join(' '), contains('accommodation'));
    });

    test('diversifies strong results across districts when possible', () {
      final localDestinations = [
        _destination(id: 'kaski_1', name: 'Kaski Culture A', district: 'Kaski'),
        _destination(id: 'kaski_2', name: 'Kaski Culture B', district: 'Kaski'),
        _destination(id: 'kaski_3', name: 'Kaski Culture C', district: 'Kaski'),
        _destination(
            id: 'gorkha_1', name: 'Gorkha Culture A', district: 'Gorkha'),
        _destination(
          id: 'lamjung_1',
          name: 'Lamjung Culture A',
          district: 'Lamjung',
        ),
      ];

      final results = service.recommendByPreferences(
        const UserPreferences(
          activity: 'culture',
          budget: 'budget',
          season: 'autumn',
          vibe: 'cultural',
        ),
        localDestinations,
        topK: 4,
      );

      final districts =
          results.map((result) => result.destination.district).toSet();

      expect(results, hasLength(4));
      expect(districts.length, greaterThanOrEqualTo(2));
    });

    test('uses offline embeddings to match related travel intent', () {
      const prefs = UserPreferences(
        activity: 'boating',
        budget: 'budget',
        season: 'spring',
        vibe: 'family',
      );
      final semanticLake = _destination(
        id: 'semantic_lake',
        name: 'Quiet Hamlet',
        district: 'Kaski',
        category: const ['village'],
        activities: const ['culture'],
        tags: const ['community', 'local meals'],
        budgetLevel: 'budget',
        accessibility: 'easy',
        familyFriendly: true,
        adventureLevel: 1,
      );
      final dryTrail = _destination(
        id: 'dry_trail',
        name: 'Dry Ridge Trail',
        district: 'Manang',
        category: const ['trekking'],
        activities: const ['adventure', 'hiking'],
        tags: const ['ridge', 'high altitude'],
        budgetLevel: 'medium',
        accessibility: 'difficult',
        familyFriendly: false,
        adventureLevel: 5,
      );
      final service = RecommenderService(
        const {},
        destinationEmbeddings: {
          semanticLake.id: OfflineSemanticEncoder.encodePreferences(
            prefs,
            familyFriendly: true,
            adventureLevel: 1,
          ),
          dryTrail.id: OfflineSemanticEncoder.encodePreferences(
            const UserPreferences(
              activity: 'trekking',
              budget: 'medium',
              season: 'autumn',
              vibe: 'adventure',
            ),
            familyFriendly: false,
            adventureLevel: 5,
          ),
        },
      );

      final results = service.recommendByPreferences(
        prefs,
        [semanticLake, dryTrail],
        familyFriendly: true,
        adventureLevel: 1,
      );

      expect(results.first.destination.id, semanticLake.id);
      expect(results.first.reasons.join(' '), contains('embedding'));
    });
  });
}

Destination _destination({
  required String id,
  required String name,
  required String district,
  List<String> category = const ['village', 'cultural', 'nature'],
  List<String> activities = const ['culture', 'photography', 'relaxation'],
  List<String> tags = const ['homestay', 'local food', 'heritage', 'terraces'],
  String budgetLevel = 'budget',
  String accessibility = 'moderate',
  bool familyFriendly = true,
  int adventureLevel = 1,
  int cultureLevel = 4,
  int natureLevel = 4,
}) {
  return Destination(
    id: id,
    name: name,
    province: 'Gandaki',
    district: district,
    municipality: null,
    category: category,
    activities: activities,
    bestSeason: const ['spring', 'autumn'],
    budgetLevel: budgetLevel,
    accessibility: accessibility,
    familyFriendly: familyFriendly,
    adventureLevel: adventureLevel,
    cultureLevel: cultureLevel,
    natureLevel: natureLevel,
    shortDescription: '$name is a test destination in $district.',
    fullDescription:
        '$name is a test destination in $district with local culture, scenery, and offline recommendation metadata.',
    latitude: 28.0,
    longitude: 84.0,
    tags: tags,
    source: 'test',
    confidence: 'high',
  );
}
