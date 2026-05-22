import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Gandaki Tourism Guide'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Rural Nepal'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden villages · Sacred trails · Authentic culture'**
  String get homeSubtitle;

  /// No description provided for @recommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendationsTitle;

  /// No description provided for @mapTitle.
  ///
  /// In en, this message translates to:
  /// **'Destination Map'**
  String get mapTitle;

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Places'**
  String get savedTitle;

  /// No description provided for @translationTitle.
  ///
  /// In en, this message translates to:
  /// **'Tourism Translator'**
  String get translationTitle;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Tourism Assistant'**
  String get chatTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-driven guide for rural tourism in Nepal.'**
  String get aboutSubtitle;

  /// No description provided for @projectPurpose.
  ///
  /// In en, this message translates to:
  /// **'This app helps travelers discover rural destinations around Pokhara through recommendations, map exploration, destination details, saved places, translation, and offline-friendly guidance.'**
  String get projectPurpose;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @featureRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Preference-based destination recommendations'**
  String get featureRecommendations;

  /// No description provided for @featureMap.
  ///
  /// In en, this message translates to:
  /// **'Map-based destination exploration'**
  String get featureMap;

  /// No description provided for @featureDetails.
  ///
  /// In en, this message translates to:
  /// **'Destination details with location actions'**
  String get featureDetails;

  /// No description provided for @featureSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved destinations with local persistence'**
  String get featureSaved;

  /// No description provided for @featureTranslation.
  ///
  /// In en, this message translates to:
  /// **'Offline-friendly phrase translation'**
  String get featureTranslation;

  /// No description provided for @savedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet'**
  String get savedEmpty;

  /// No description provided for @savedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse destinations on the Home tab or get AI recommendations and bookmark the places you want to revisit.'**
  String get savedEmptySubtitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask about destinations, trekking, food...'**
  String get chatPlaceholder;

  /// No description provided for @chatGreeting.
  ///
  /// In en, this message translates to:
  /// **'Namaste! Ask me about destinations, trekking, homestays, safety, transport, food, or culture.'**
  String get chatGreeting;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet - some features unavailable'**
  String get noInternet;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @offlineMap.
  ///
  /// In en, this message translates to:
  /// **'Offline map'**
  String get offlineMap;

  /// No description provided for @onlineMap.
  ///
  /// In en, this message translates to:
  /// **'Online map'**
  String get onlineMap;

  /// No description provided for @preparingMap.
  ///
  /// In en, this message translates to:
  /// **'Preparing map'**
  String get preparingMap;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
