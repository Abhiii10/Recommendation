import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/core/media/image_cache_service.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/destination_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeImageCacheService extends Fake implements ImageCacheService {
  @override
  Future<String?> resolveNetworkUrl(
    String name, {
    String? destinationId,
  }) async =>
      null;

  @override
  Future<void> prefetchAll(List<Destination> destinations) async {}

  @override
  Future<List<String>> resolveGallery(
    String destinationName, {
    String? destinationId,
    int maxImages = 5,
  }) async =>
      [];

  @override
  Future<void> prefetchGalleries(List<Destination> destinations) async {}

  static final instance = _FakeImageCacheService();
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('destination_card_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
          return tempDir.path;
      }
      return tempDir.path;
    });
  });

  tearDownAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    ImageCacheService.debugInstance = _FakeImageCacheService.instance;
    SharedPreferences.setMockInitialValues({
      'img_cache_with-image-light': '',
      'img_cache_without-image-light': '',
      'img_cache_with-image-dark': '',
    });
  });

  tearDown(() {
    ImageCacheService.debugInstance = null;
  });

  testWidgets('DestinationCard golden - light with local image',
      (tester) async {
    ImageCacheService.debugInstance = _FakeImageCacheService.instance;
    await tester.pumpWidget(
      _CardHarness(
        brightness: Brightness.light,
        destination: _destination(id: 'with-image-light'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('destination-card-golden')),
      matchesGoldenFile('goldens/destination_card_light_with_image.png'),
    );
  });

  testWidgets('DestinationCard golden - light local fallback', (tester) async {
    ImageCacheService.debugInstance = _FakeImageCacheService.instance;
    await tester.pumpWidget(
      _CardHarness(
        brightness: Brightness.light,
        destination: _destination(id: 'without-image-light'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('destination-card-golden')),
      matchesGoldenFile('goldens/destination_card_light_without_image.png'),
    );
  });

  testWidgets('DestinationCard golden - dark with local image', (tester) async {
    ImageCacheService.debugInstance = _FakeImageCacheService.instance;
    await tester.pumpWidget(
      _CardHarness(
        brightness: Brightness.dark,
        destination: _destination(id: 'with-image-dark'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('destination-card-golden')),
      matchesGoldenFile('goldens/destination_card_dark_with_image.png'),
    );
  });
}

class _CardHarness extends StatelessWidget {
  final Brightness brightness;
  final Destination destination;

  const _CardHarness({
    required this.brightness,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.theme;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: RepaintBoundary(
                key: const ValueKey('destination-card-golden'),
                child: SizedBox(
                  width: 360,
                  child: DestinationCard(
                    destination: destination,
                    reasons: const [
                      'Matches your trekking and village interests',
                    ],
                    scoreLabel: '92%',
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Destination _destination({
  required String id,
}) {
  return Destination(
    id: id,
    name: 'Ghandruk Village',
    province: 'Gandaki',
    district: 'Kaski',
    municipality: 'Annapurna Rural Municipality',
    category: const ['village', 'trekking'],
    activities: const ['trekking', 'culture', 'photography'],
    bestSeason: const ['spring', 'autumn'],
    budgetLevel: 'medium',
    accessibility: 'moderate',
    familyFriendly: true,
    adventureLevel: 3,
    cultureLevel: 5,
    natureLevel: 5,
    shortDescription: 'A Gurung settlement and Annapurna trekking node.',
    fullDescription:
        'A Gurung settlement and Annapurna trekking node with mountain views.',
    latitude: 28.377,
    longitude: 83.807,
    tags: const ['gurung', 'homestay', 'annapurna'],
    source: 'test',
    confidence: 'high',
  );
}
