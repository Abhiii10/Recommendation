import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/models/destination.dart';
import 'package:rural_tourism_app/services/chatbot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatbotService intent detection', () {
    late ChatbotService service;

    setUp(() async {
      service = ChatbotService(
        destinations: _fakeDestinations(),
      );

      await service.init();
    });

    test('intent accuracy should be at least 80 percent', () {
      final cases = <_IntentCase>[
        _IntentCase('hello', 'greeting'),
        _IntentCase('namaste can you help me', 'greeting'),
        _IntentCase('when is the best time to visit Ghandruk', 'best_time_to_visit'),
        _IntentCase('is autumn good for trekking', 'best_time_to_visit'),
        _IntentCase('can I visit during monsoon', 'best_time_to_visit'),
        _IntentCase('how do I reach Sikles from Pokhara', 'transport'),
        _IntentCase('can I take a bus to Ghandruk', 'transport'),
        _IntentCase('is jeep better than bus', 'transport'),
        _IntentCase('where can I stay in Ghandruk', 'homestay'),
        _IntentCase('tell me about homestays', 'homestay'),
        _IntentCase('what food can I try', 'food'),
        _IntentCase('is vegetarian food available', 'food'),
        _IntentCase('what cultural etiquette should I follow', 'culture_etiquette'),
        _IntentCase('can I take photos of local people', 'culture_etiquette'),
        _IntentCase('is it safe to trek alone', 'safety'),
        _IntentCase('is rural Nepal safe for tourists', 'safety'),
        _IntentCase('how much money do I need', 'budget'),
        _IntentCase('what is the daily budget', 'budget'),
        _IntentCase('what should I pack for trekking', 'trekking'),
        _IntentCase('do I need permits for trekking', 'trekking'),
        _IntentCase('tell me about Ghandruk', 'destination_info'),
        _IntentCase('what is Sikles known for', 'destination_info'),
        _IntentCase('what places are near Ghandruk', 'nearby_places'),
        _IntentCase('recommend me a peaceful village', 'recommendation_help'),
        _IntentCase('where should I go for trekking', 'recommendation_help'),
        _IntentCase('what should I do in emergency', 'emergency_help'),
        _IntentCase('I am injured and need help', 'emergency_help'),
        _IntentCase('can I use this app offline', 'offline_help'),
        _IntentCase('does the app work without internet', 'offline_help'),
        _IntentCase('can you translate this answer to Nepali', 'translation_help'),
      ];

      var correct = 0;

      for (final item in cases) {
        final predicted = service.debugDetectIntent(item.question);

        if (predicted == item.expectedIntent) {
          correct++;
        } else {
          // ignore: avoid_print
          print(
            'FAILED: "${item.question}" expected ${item.expectedIntent}, got $predicted',
          );
        }
      }

      final accuracy = correct / cases.length;

      // ignore: avoid_print
      print(
        'Chatbot intent accuracy: $correct/${cases.length} = ${(accuracy * 100).toStringAsFixed(1)}%',
      );

      expect(accuracy, greaterThanOrEqualTo(0.80));
    });
  });
}

class _IntentCase {
  final String question;
  final String expectedIntent;

  const _IntentCase(
    this.question,
    this.expectedIntent,
  );
}

List<Destination> _fakeDestinations() {
  return const [
    Destination(
      id: 'dest_001',
      name: 'Ghandruk',
      province: 'Gandaki',
      district: 'Kaski',
      municipality: 'Annapurna',
      category: ['village', 'culture', 'trekking'],
      activities: ['trekking', 'culture', 'homestay'],
      bestSeason: ['spring', 'autumn'],
      budgetLevel: 'medium',
      accessibility: 'moderate',
      familyFriendly: true,
      adventureLevel: 3,
      cultureLevel: 5,
      natureLevel: 5,
      shortDescription: 'A Gurung village known for mountain views and homestays.',
      fullDescription:
          'Ghandruk is a popular rural tourism village with Gurung culture, Annapurna views, and trekking routes.',
      latitude: 28.3772,
      longitude: 83.8077,
      tags: ['gurung', 'homestay', 'annapurna'],
      source: 'test',
      confidence: 'high',
    ),
    Destination(
      id: 'dest_002',
      name: 'Sikles',
      province: 'Gandaki',
      district: 'Kaski',
      municipality: 'Madi',
      category: ['village', 'trekking'],
      activities: ['trekking', 'culture', 'nature'],
      bestSeason: ['spring', 'autumn'],
      budgetLevel: 'medium',
      accessibility: 'moderate',
      familyFriendly: true,
      adventureLevel: 3,
      cultureLevel: 5,
      natureLevel: 5,
      shortDescription: 'A traditional village with mountain scenery and rural culture.',
      fullDescription:
          'Sikles is a scenic village offering local culture, mountain views, and trekking routes.',
      latitude: 28.4037,
      longitude: 84.0911,
      tags: ['culture', 'homestay'],
      source: 'test',
      confidence: 'high',
    ),
    Destination(
      id: 'dest_003',
      name: 'Begnas Lake',
      province: 'Gandaki',
      district: 'Kaski',
      municipality: 'Pokhara',
      category: ['lake', 'nature'],
      activities: ['boating', 'relaxation', 'photography'],
      bestSeason: ['spring', 'autumn', 'winter'],
      budgetLevel: 'budget',
      accessibility: 'easy',
      familyFriendly: true,
      adventureLevel: 1,
      cultureLevel: 2,
      natureLevel: 5,
      shortDescription: 'A peaceful lake destination near Pokhara.',
      fullDescription:
          'Begnas Lake is suitable for relaxation, boating, photography, and family trips.',
      latitude: 28.1647,
      longitude: 84.1132,
      tags: ['lake', 'boating'],
      source: 'test',
      confidence: 'high',
    ),
    Destination(
      id: 'dest_004',
      name: 'Dhampus',
      province: 'Gandaki',
      district: 'Kaski',
      municipality: 'Machhapuchhre',
      category: ['village', 'viewpoint'],
      activities: ['hiking', 'photography', 'culture'],
      bestSeason: ['spring', 'autumn'],
      budgetLevel: 'budget',
      accessibility: 'easy',
      familyFriendly: true,
      adventureLevel: 2,
      cultureLevel: 4,
      natureLevel: 5,
      shortDescription: 'A beginner-friendly hiking village with Himalayan views.',
      fullDescription:
          'Dhampus is popular for short hikes, mountain views, and village tourism.',
      latitude: 28.3069,
      longitude: 83.8185,
      tags: ['hiking', 'views'],
      source: 'test',
      confidence: 'high',
    ),
  ];
}