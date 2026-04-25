import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/models/destination.dart';
import 'package:rural_tourism_app/models/user_preferences.dart';
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
  });
}