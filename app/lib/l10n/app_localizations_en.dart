// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Paila Nepal';

  @override
  String get homeTitle => 'Discover Rural Nepal';

  @override
  String get homeSubtitle =>
      'Hidden villages · Sacred trails · Authentic culture';

  @override
  String get recommendationsTitle => 'Recommendations';

  @override
  String get mapTitle => 'Destination Map';

  @override
  String get savedTitle => 'Saved Places';

  @override
  String get translationTitle => 'Tourism Translator';

  @override
  String get chatTitle => 'Tourism Assistant';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle => 'AI-driven guide for rural tourism in Nepal.';

  @override
  String get projectPurpose =>
      'This app helps travelers discover rural destinations around Pokhara through recommendations, map exploration, destination details, saved places, translation, and offline-friendly guidance.';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get featureRecommendations =>
      'Preference-based destination recommendations';

  @override
  String get featureMap => 'Map-based destination exploration';

  @override
  String get featureDetails => 'Destination details with location actions';

  @override
  String get featureSaved => 'Saved destinations with local persistence';

  @override
  String get featureTranslation => 'Offline-friendly phrase translation';

  @override
  String get savedEmpty => 'No saved places yet';

  @override
  String get savedEmptySubtitle =>
      'Browse destinations on the Home tab or get AI recommendations and bookmark the places you want to revisit.';

  @override
  String get chatPlaceholder => 'Ask about destinations, trekking, food...';

  @override
  String get chatGreeting =>
      'Namaste! Ask me about destinations, trekking, homestays, safety, transport, food, or culture.';

  @override
  String get noInternet => 'No internet - some features unavailable';

  @override
  String get backOnline => 'Back online';

  @override
  String get offlineMap => 'Offline map';

  @override
  String get onlineMap => 'Online map';

  @override
  String get preparingMap => 'Preparing map';
}
