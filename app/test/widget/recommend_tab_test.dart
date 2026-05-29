import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/presentation/recommend_tab.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/recommender_service.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';

void main() {
  testWidgets('RecommendTab shows filters and action button', (tester) async {
    final destination = _destination();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: RecommendTab(
          destinations: [destination],
          accommodations: const <Accommodation>[],
          service: RecommenderService(const {}),
          onToggleSaved: (_) async {},
          isSaved: (_) => false,
        ),
      ),
    );

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Budget'), findsWidgets);
    expect(find.text('Trekking'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Get Recommendations'), findsOneWidget);
  });
}

Destination _destination() {
  return const Destination(
    id: 'dest-test',
    name: 'Ghandruk',
    province: 'Gandaki',
    district: 'Kaski',
    municipality: 'Annapurna Rural Municipality',
    category: ['village', 'trekking'],
    activities: ['trekking', 'culture'],
    bestSeason: ['spring', 'autumn'],
    budgetLevel: 'medium',
    accessibility: 'moderate',
    familyFriendly: true,
    adventureLevel: 3,
    cultureLevel: 5,
    natureLevel: 5,
    shortDescription: 'Gurung settlement and Annapurna trekking node.',
    fullDescription:
        'Gurung settlement and Annapurna trekking node with homestays.',
    tags: ['gurung', 'homestay'],
    source: 'test',
    confidence: 'high',
  );
}
