import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rural_tourism_app/config/app_config.dart';
import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/features/translator/data/services/language_detector.dart';
import 'package:rural_tourism_app/features/translator/data/services/roman_nepali_converter.dart';

enum TranslationDirection {
  autoDetect,
  englishToNepali,
  nepaliToEnglish,
}

enum TranslationSource {
  phrasebook,
  template,
  online,
  fallback,
}

class TranslationResult {
  final String translatedText;
  final String detectedSourceLang;
  final double confidence;
  final TranslationSource source;
  final bool isOffline;
  final String? romanized;
  final String? matchedEnglish;
  final String? matchedCategory;
  final String? warningMessage;

  const TranslationResult({
    required this.translatedText,
    required this.detectedSourceLang,
    required this.confidence,
    required this.source,
    required this.isOffline,
    this.romanized,
    this.matchedEnglish,
    this.matchedCategory,
    this.warningMessage,
  });
}

class TourismPhrasebookEntry {
  final String id;
  final String english;
  final String nepali;
  final String romanNepali;
  final List<String> aliases;
  final String category;
  final String context;
  final bool urgent;

  const TourismPhrasebookEntry({
    required this.id,
    required this.english,
    required this.nepali,
    required this.romanNepali,
    required this.aliases,
    required this.category,
    required this.context,
    this.urgent = false,
  });

  factory TourismPhrasebookEntry.fromJson(Map<String, dynamic> json) {
    final romanNepali = json['romanNepali']?.toString().trim();
    final romanized = (json['romanized'] as List? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return TourismPhrasebookEntry(
      id: json['id']?.toString() ?? '',
      english: json['english']?.toString().trim() ?? '',
      nepali: json['nepali']?.toString().trim() ?? '',
      romanNepali: (romanNepali != null && romanNepali.isNotEmpty)
          ? romanNepali
          : (romanized.isEmpty ? '' : romanized.first),
      aliases: romanized,
      category: _normalizeCategory(json['category']?.toString() ?? 'general'),
      context: json['context']?.toString() ?? 'tourism',
      urgent: json['urgent'] == true,
    );
  }

  static String _normalizeCategory(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'homestay') return 'accommodation';
    if (normalized == 'health') return 'emergency';
    if (normalized == 'price' || normalized == 'time') return 'shopping';
    if (normalized == 'greeting') return 'greetings';
    return normalized;
  }
}

class TranslationService {
  static const _onlineTimeout = Duration(seconds: 10);
  static const _myMemoryDailyLimit = 5000;
  static const _myMemoryWarningLimit = 4500;
  static const _myMemoryCounterPrefix = 'mymemory_words_';
  static const _genericPlaceSuffixes = {
    'base',
    'camp',
    'high',
    'village',
    'lake',
    'temple',
    'dham',
    'hill',
    'view',
    'viewpoint',
    'homestay',
    'reserve',
    'trail',
    'trek',
    'area',
  };
  static const _genericSingleWordAliases = {
    'lake',
    'temple',
    'village',
    'hill',
    'camp',
    'homestay',
    'reserve',
    'bridge',
    'bridges',
    'trek',
    'trail',
  };
  static const _nepaliNouns = {
    'apple': 'स्याउ',
    'banana': 'केरा',
    'orange': 'सुन्तला',
    'room': 'कोठा',
    'bed': 'ओछ्यान',
    'blanket': 'कम्बल',
    'hotel': 'होटल',
    'homestay': 'होमस्टे',
    'guesthouse': 'गेस्टहाउस',
    'water': 'पानी',
    'food': 'खाना',
    'meal': 'खाना',
    'rice': 'भात',
    'dal': 'दाल',
    'tea': 'चिया',
    'coffee': 'कफी',
    'milk': 'दूध',
    'vegetarian food': 'शाकाहारी खाना',
    'medicine': 'औषधि',
    'doctor': 'डाक्टर',
    'hospital': 'अस्पताल',
    'ambulance': 'एम्बुलेन्स',
    'help': 'मद्दत',
    'toilet': 'शौचालय',
    'bathroom': 'शौचालय',
    'bus': 'बस',
    'jeep': 'जिप',
    'taxi': 'ट्याक्सी',
    'ticket': 'टिकट',
    'guide': 'गाइड',
    'porter': 'भरिया',
    'map': 'नक्सा',
    'wifi': 'वाइफाइ',
    'charger': 'चार्जर',
    'phone': 'फोन',
    'project': 'प्रोजेक्ट',
    'my project': 'मेरो प्रोजेक्ट',
    'price': 'मूल्य',
    'discount': 'छुट',
    'fever': 'ज्वरो',
    'headache': 'टाउको दुखाइ',
    'stomach pain': 'पेट दुखाइ',
    'pain': 'दुखाइ',
    'bus stop': 'बस स्टप',
    'trail': 'बाटो',
    'trekking permit': 'ट्रेकिङ अनुमति',
    'permit': 'अनुमति',
    'tims': 'टिम्स',
    'english': 'अंग्रेजी',
  };
  static const _englishNouns = {
    'स्याउ': 'apple',
    'केरा': 'banana',
    'सुन्तला': 'orange',
    'कोठा': 'a room',
    'ओछ्यान': 'a bed',
    'कम्बल': 'a blanket',
    'होटल': 'a hotel',
    'होमस्टे': 'a homestay',
    'गेस्टहाउस': 'a guesthouse',
    'पानी': 'water',
    'खाना': 'food',
    'भात': 'rice',
    'दाल': 'dal',
    'चिया': 'tea',
    'कफी': 'coffee',
    'दूध': 'milk',
    'शाकाहारी खाना': 'vegetarian food',
    'औषधि': 'medicine',
    'डाक्टर': 'a doctor',
    'अस्पताल': 'a hospital',
    'एम्बुलेन्स': 'an ambulance',
    'मद्दत': 'help',
    'शौचालय': 'the toilet',
    'बस': 'a bus',
    'जिप': 'a jeep',
    'ट्याक्सी': 'a taxi',
    'टिकट': 'a ticket',
    'गाइड': 'a guide',
    'भरिया': 'a porter',
    'नक्सा': 'a map',
    'ज्वरो': 'fever',
    'टाउको दुखाइ': 'a headache',
    'पेट दुखाइ': 'stomach pain',
    'दुखाइ': 'pain',
    'बस स्टप': 'the bus stop',
    'बाटो': 'the trail',
    'ट्रेकिङ अनुमति': 'a trekking permit',
    'अनुमति': 'a permit',
    'टिम्स': 'TIMS',
    'अंग्रेजी': 'English',
  };
  static const _romanEnglishNouns = {
    'syau': 'apple',
    'kera': 'banana',
    'suntala': 'orange',
    'kotha': 'a room',
    'hotel': 'a hotel',
    'homestay': 'a homestay',
    'paani': 'water',
    'pani': 'water',
    'khana': 'food',
    'bhat': 'rice',
    'dal': 'dal',
    'daal': 'dal',
    'chiya': 'tea',
    'chai': 'tea',
    'kafi': 'coffee',
    'ausadhi': 'medicine',
    'doctor': 'a doctor',
    'aspatal': 'a hospital',
    'madat': 'help',
    'maddat': 'help',
    'shauchalaya': 'the toilet',
    'toilet': 'the toilet',
    'bus': 'a bus',
    'jeep': 'a jeep',
    'taxi': 'a taxi',
    'ticket': 'a ticket',
    'guide': 'a guide',
    'porter': 'a porter',
    'jhwaro': 'fever',
    'jaro': 'fever',
    'tauko dukheko': 'a headache',
    'pet dukheko': 'stomach pain',
    'bus stop': 'the bus stop',
    'permit': 'a permit',
    'tims': 'TIMS',
  };
  static const _properNounTransliterations = {
    'ram': 'राम',
    'sita': 'सीता',
    'gita': 'गीता',
    'geeta': 'गीता',
    'hari': 'हरि',
    'shyam': 'श्याम',
    'maya': 'माया',
    'anjali': 'अञ्जली',
    'suman': 'सुमन',
    'sujan': 'सुजन',
    'bikash': 'विकास',
    'bikas': 'विकास',
    'ramesh': 'रमेश',
    'suresh': 'सुरेश',
    'paila': 'पाइला',
    'nepal': 'नेपाल',
    'nepali': 'नेपाली',
    'pokhara': 'पोखरा',
    'kathmandu': 'काठमाडौं',
    'gandaki': 'गण्डकी',
    'kaski': 'कास्की',
    'lamjung': 'लमजुङ',
    'tanahun': 'तनहुँ',
    'mustang': 'मुस्ताङ',
    'gorkha': 'गोरखा',
    'baglung': 'बागलुङ',
    'parbat': 'पर्वत',
    'myagdi': 'म्याग्दी',
    'nawalpur': 'नवलपुर',
    'syangja': 'स्याङ्जा',
    'ghandruk': 'घान्द्रुक',
    'dhampus': 'धम्पुस',
    'sikles': 'सिक्लेस',
    'lwang': 'ल्वाङ',
    'astam': 'अस्ताम',
    'begnas': 'बेगनास',
    'rupa': 'रुपा',
    'lake': 'ताल',
    'jomsom': 'जोमसोम',
    'marpha': 'मार्फा',
    'kagbeni': 'कागबेनी',
    'muktinath': 'मुक्तिनाथ',
    'manang': 'मनाङ',
    'pisang': 'पिसाङ',
    'braga': 'ब्रागा',
    'ghalegaun': 'घलेगाउँ',
    'bhujung': 'भुजुङ',
    'rainaskot': 'राइनासकोट',
    'bandipur': 'बन्दीपुर',
    'sirubari': 'सिरुबारी',
    'lo': 'लो',
    'manthang': 'मन्थाङ',
    'tilicho': 'तिलिचो',
    'barpak': 'बारपाक',
    'laprak': 'लाप्राक',
    'mardi': 'मार्दी',
    'himal': 'हिमाल',
    'annapurna': 'अन्नपूर्ण',
    'machhapuchhre': 'माछापुच्छ्रे',
    'dhorpatan': 'ढोरपाटन',
    'panchase': 'पञ्चासे',
    'kushma': 'कुश्मा',
    'kalika': 'कालिका',
    'devghat': 'देवघाट',
    'dham': 'धाम',
    'amaltari': 'अमलटारी',
    'chitwan': 'चितवन',
    'temple': 'मन्दिर',
    'village': 'गाउँ',
    'hill': 'डाँडा',
    'camp': 'क्याम्प',
    'high': 'हाई',
    'base': 'बेस',
    'reserve': 'आरक्ष',
    'homestay': 'होमस्टे',
  };

  final http.Client _client;
  final RomanNepaliDetector _romanDetector;
  final RomanNepaliConverter _romanConverter;

  late final LanguageDetector _languageDetector;
  bool _initialized = false;
  List<TourismPhrasebookEntry> _phrasebook = [];
  List<_DestinationTerm> _destinationTerms = [];

  TranslationService({
    http.Client? client,
    RomanNepaliDetector? romanDetector,
    RomanNepaliConverter? romanConverter,
  })  : _client = client ?? http.Client(),
        _romanDetector = romanDetector ?? RomanNepaliDetector(),
        _romanConverter = romanConverter ?? const RomanNepaliConverter() {
    _languageDetector = LanguageDetector(romanNepaliDetector: _romanDetector);
  }

  List<TourismPhrasebookEntry> get phrasebookEntries =>
      List.unmodifiable(_phrasebook);

  Future<void> initialize() async {
    if (_initialized) return;
    await Future.wait([
      _romanDetector.load(),
      _loadPhrasebook(),
      _loadDestinationTerms(),
    ]);
    _initialized = true;
  }

  // Translation priority chain:
  // exact phrasebook -> fuzzy phrasebook -> offline slot templates
  // -> Roman Nepali conversion -> MyMemory
  // -> backend Claude fallback -> graceful failure
  Future<TranslationResult> translateText(
    String text,
    TranslationDirection direction, {
    bool allowOnline = true,
  }) async {
    if (!_initialized) await initialize();

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _failure(
        detectedSourceLang: 'unknown',
        message: 'Enter text to translate.',
      );
    }

    final detected = _languageDetector.detect(trimmed);
    final pair = _resolvePair(detected, direction);
    _log(
      'start input="${_debugPreview(trimmed)}" direction=${direction.name} '
      'allowOnline=$allowOnline detected=${detected.languageCode} '
      'roman=${detected.isRomanNepali} pair=${pair.sourceLang}->${pair.targetLang}',
    );

    final exact = _matchPhrasebook(trimmed, pair, exactOnly: true);
    if (exact != null) {
      _logResult('exact phrasebook', exact);
      return exact;
    }
    _log('exact phrasebook -> no match');

    final fuzzy = _matchPhrasebook(trimmed, pair);
    if (fuzzy != null && fuzzy.confidence > 0.80) {
      _logResult('fuzzy phrasebook', fuzzy);
      return fuzzy;
    }
    if (fuzzy == null) {
      _log('fuzzy phrasebook -> no match');
    } else {
      _logResult(
        'fuzzy phrasebook',
        fuzzy,
        fallthrough: 'confidence <= 0.80',
      );
    }

    final template = _tryOfflineTemplate(trimmed, pair, detected.isRomanNepali);
    if (template != null) {
      _logResult('offline template', template);
      return template;
    }
    _log('offline template -> no match');

    if (detected.isRomanNepali) {
      final devanagari = _romanConverter.convert(trimmed);
      _log('roman nepali conversion -> "${_debugPreview(devanagari)}"');
      final romanMatch = _matchPhrasebook(
        devanagari,
        pair,
        romanDetected: true,
      );
      if (romanMatch != null && romanMatch.confidence > 0.80) {
        _logResult('roman phrasebook', romanMatch);
        return romanMatch;
      }
      if (romanMatch == null) {
        _log('roman phrasebook -> no match');
      } else {
        _logResult(
          'roman phrasebook',
          romanMatch,
          fallthrough: 'confidence <= 0.80',
        );
      }
    }

    if (!allowOnline) {
      final result = _backendOfflineFailure(
        detectedSourceLang: pair.sourceLang,
      );
      _logResult('failure', result, fallthrough: 'online disabled');
      return result;
    }

    final onlineInput =
        detected.isRomanNepali ? _romanConverter.convert(trimmed) : trimmed;
    final online = await _tryMyMemory(
      onlineInput,
      pair,
      romanDetected: detected.isRomanNepali,
    );
    if (online != null && online.source == TranslationSource.online) {
      _logResult('MyMemory', online);
      return online;
    }
    if (online == null) {
      _log('MyMemory -> no usable translation');
    } else {
      _logResult('MyMemory', online, fallthrough: 'warning only');
    }

    final backend = await _tryClaudeBackend(
      trimmed,
      direction,
      pair,
      romanDetected: detected.isRomanNepali,
    );
    if (backend != null) {
      _logResult('backend', backend);
      return backend;
    }

    final result = BackendConfig.health.value?.reachable == false
        ? _backendOfflineFailure(
            detectedSourceLang: pair.sourceLang,
            warningMessage: online?.warningMessage,
          )
        : _allMethodsFailed(
            detectedSourceLang: pair.sourceLang,
            warningMessage: online?.warningMessage,
          );
    _logResult('failure', result);
    return result;
  }

  _LanguagePair _resolvePair(
    LanguageDetectionResult detected,
    TranslationDirection direction,
  ) {
    final detectedSource = detected.languageCode;
    final detectedTarget = detectedSource == 'ne-NP' ? 'en-US' : 'ne-NP';

    switch (direction) {
      case TranslationDirection.autoDetect:
        return _LanguagePair(detectedSource, detectedTarget);
      case TranslationDirection.englishToNepali:
        return const _LanguagePair('en-US', 'ne-NP');
      case TranslationDirection.nepaliToEnglish:
        return const _LanguagePair('ne-NP', 'en-US');
    }
  }

  TranslationResult? _matchPhrasebook(
    String input,
    _LanguagePair pair, {
    bool exactOnly = false,
    bool romanDetected = false,
  }) {
    final scored = _phrasebook
        .map(
          (entry) => _PhraseScore(
            entry,
            _scoreEntry(input, entry, pair),
          ),
        )
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) return null;
    final best = scored.first;
    final exact = best.score >= 0.999;
    if (exactOnly && !exact) return null;
    if (!exactOnly && best.score <= 0.80) return null;

    return TranslationResult(
      translatedText: _outputFor(best.entry, pair),
      detectedSourceLang: pair.sourceLang,
      confidence: _displayConfidence(
        best.score,
        exactPhrasebook: exact,
        romanDetected: romanDetected && !exact,
      ),
      source: TranslationSource.phrasebook,
      isOffline: true,
      romanized: pair.targetLang == 'ne-NP' ? best.entry.romanNepali : null,
      matchedEnglish: best.entry.english,
      matchedCategory: best.entry.category,
    );
  }

  double _scoreEntry(
    String input,
    TourismPhrasebookEntry entry,
    _LanguagePair pair,
  ) {
    final inputNorm = _normalize(input);
    final candidates = pair.sourceLang == 'en-US'
        ? [entry.english]
        : [entry.nepali, entry.romanNepali, ...entry.aliases];

    var best = 0.0;
    for (final candidate in candidates) {
      final candidateNorm = _normalize(candidate);
      if (candidateNorm.isEmpty) continue;
      if (inputNorm == candidateNorm) return 1.0;
      best = math.max(best, _similarity(inputNorm, candidateNorm));
    }
    return best;
  }

  TranslationResult? _tryOfflineTemplate(
    String input,
    _LanguagePair pair,
    bool romanDetected,
  ) {
    final directPlace = _findDestinationTerm(input);
    if (directPlace != null) {
      return TranslationResult(
        translatedText: pair.targetLang == 'ne-NP'
            ? directPlace.nepaliName
            : directPlace.englishName,
        detectedSourceLang: pair.sourceLang,
        confidence: 0.95,
        source: TranslationSource.template,
        isOffline: true,
        romanized: pair.targetLang == 'ne-NP' ? directPlace.englishName : null,
        matchedCategory: 'destination',
      );
    }

    if (pair.targetLang == 'ne-NP') {
      return _tryEnglishToNepaliTemplate(input, pair, romanDetected);
    }
    return _tryNepaliToEnglishTemplate(input, pair, romanDetected);
  }

  TranslationResult? _tryEnglishToNepaliTemplate(
    String input,
    _LanguagePair pair,
    bool romanDetected,
  ) {
    final staticTemplate = _englishStaticTemplate(input, pair, romanDetected);
    if (staticTemplate != null) return staticTemplate;

    final name = _firstCapture(
      input,
      RegExp(
        r"^(?:my name is|my name's|i am called|call me)\s+(.+)$",
        caseSensitive: false,
      ),
    );
    if (name != null) {
      final translatedName = _toNepaliProperNoun(name);
      return _templateResult(
        'मेरो नाम $translatedName हो।',
        pair,
        romanized: 'Mero naam ${_cleanSlot(name)} ho.',
        romanDetected: romanDetected,
        category: 'identity',
      );
    }

    final placeQuestion = _firstCapture(
      input,
      RegExp(
        r"^(?:where is|where's)\s+(?:the\s+)?(.+?)\??$",
        caseSensitive: false,
      ),
    );
    if (placeQuestion != null) {
      final place = _toNepaliNounOrPlace(placeQuestion);
      return _templateResult(
        '$place कहाँ छ?',
        pair,
        romanized: '${_cleanSlot(placeQuestion)} kaha cha?',
        romanDetected: romanDetected,
        category: 'directions',
      );
    }

    final goToPlace = _firstCapture(
      input,
      RegExp(
        r'^(?:i want to go to|i need to go to|i would like to go to|take me to|please take me to|can you take me to)\s+(.+)$',
        caseSensitive: false,
      ),
    );
    if (goToPlace != null) {
      final place = _toNepaliProperNoun(goToPlace);
      return _templateResult(
        'म $place जान चाहन्छु।',
        pair,
        romanized: 'Ma ${_cleanSlot(goToPlace)} jana chahanchu.',
        romanDetected: romanDetected,
        category: 'transport',
      );
    }

    final goingToPlace = _firstCapture(
      input,
      RegExp(
        r"^(?:i am going to|i'm going to)\s+(.+)$",
        caseSensitive: false,
      ),
    );
    if (goingToPlace != null) {
      final place = _toNepaliProperNoun(goingToPlace);
      return _templateResult(
        'म $place जाँदै छु।',
        pair,
        romanized: 'Ma ${_cleanSlot(goingToPlace)} jandai chu.',
        romanDetected: romanDetected,
        category: 'transport',
      );
    }

    final currentlyDoing = _firstCapture(
      input,
      RegExp(
        r"^(?:i am currently doing|i'm currently doing)\s+(.+)$",
        caseSensitive: false,
      ),
    );
    if (currentlyDoing != null) {
      final thing = _toNepaliNounOrPlace(currentlyDoing);
      return _templateResult(
        'म हाल $thing गर्दैछु।',
        pair,
        romanized: 'Ma haal ${_cleanSlot(currentlyDoing)} gardai chu.',
        romanDetected: romanDetected,
        category: 'communication',
      );
    }

    final needThing = _firstCapture(
      input,
      RegExp(
        r'^(?:i need|i want|i would like)\s+(?:a\s+|an\s+|the\s+)?(.+)$',
        caseSensitive: false,
      ),
    );
    if (needThing != null) {
      final thing = _toNepaliNounOrPlace(needThing);
      return _templateResult(
        'मलाई $thing चाहिन्छ।',
        pair,
        romanized: 'Malai ${_cleanSlot(needThing)} chahincha.',
        romanDetected: romanDetected,
        category: 'tourism',
      );
    }

    final hasThing = _firstCapture(
      input,
      RegExp(
        r'^(?:do you have|have you got)\s+(?:a\s+|an\s+|the\s+)?(.+?)\??$',
        caseSensitive: false,
      ),
    );
    if (hasThing != null) {
      final thing = _toNepaliNounOrPlace(hasThing);
      return _templateResult(
        'के तपाईंसँग $thing छ?',
        pair,
        romanized: 'Ke tapaisanga ${_cleanSlot(hasThing)} cha?',
        romanDetected: romanDetected,
        category: 'tourism',
      );
    }

    final priceThing = _firstCapture(
      input,
      RegExp(
        r'^(?:how much is|what is the price of)\s+(?:a\s+|an\s+|the\s+)?(.+?)\??$',
        caseSensitive: false,
      ),
    );
    if (priceThing != null) {
      final thing = _toNepaliNounOrPlace(priceThing);
      return _templateResult(
        '$thing कति पर्छ?',
        pair,
        romanized: '${_cleanSlot(priceThing)} kati parcha?',
        romanDetected: romanDetected,
        category: 'shopping',
      );
    }

    final findThing = _firstCapture(
      input,
      RegExp(
        r'^(?:where can i find|where do i find|where is the nearest)\s+(?:a\s+|an\s+|the\s+)?(.+?)\??$',
        caseSensitive: false,
      ),
    );
    if (findThing != null) {
      final thing = _toNepaliNounOrPlace(findThing);
      return _templateResult(
        'नजिकै $thing कहाँ पाइन्छ?',
        pair,
        romanized: 'Najikai ${_cleanSlot(findThing)} kaha paincha?',
        romanDetected: romanDetected,
        category: 'directions',
      );
    }

    final farPlace = _firstCapture(
      input,
      RegExp(
        r'^(?:how far is|how far to)\s+(?:the\s+)?(.+?)\??$',
        caseSensitive: false,
      ),
    );
    if (farPlace != null) {
      final place = _toNepaliProperNoun(farPlace);
      return _templateResult(
        '$place कति टाढा छ?',
        pair,
        romanized: '${_cleanSlot(farPlace)} kati tadha cha?',
        romanDetected: romanDetected,
        category: 'directions',
      );
    }

    final timePlace = _firstCapture(
      input,
      RegExp(
        r'^(?:how long does it take to|how long to)\s+(?:go to\s+)?(.+?)\??$',
        caseSensitive: false,
      ),
    );
    if (timePlace != null) {
      final place = _toNepaliProperNoun(timePlace);
      return _templateResult(
        '$place पुग्न कति समय लाग्छ?',
        pair,
        romanized: '${_cleanSlot(timePlace)} pugna kati samaya lagcha?',
        romanDetected: romanDetected,
        category: 'transport',
      );
    }

    final giveThing = _firstCapture(
      input,
      RegExp(
        r'^(?:please give me|give me|can i get|may i get)\s+(?:a\s+|an\s+|the\s+)?(.+)$',
        caseSensitive: false,
      ),
    );
    if (giveThing != null) {
      final thing = _toNepaliNounOrPlace(giveThing);
      return _templateResult(
        'कृपया मलाई $thing दिनुहोस्।',
        pair,
        romanized: 'Kripaya malai ${_cleanSlot(giveThing)} dinuhos.',
        romanDetected: romanDetected,
        category: 'tourism',
      );
    }

    return null;
  }

  TranslationResult? _englishStaticTemplate(
    String input,
    _LanguagePair pair,
    bool romanDetected,
  ) {
    final normalized = _normalize(input);
    final templates = <String, ({String ne, String roman, String category})>{
      'hi': (ne: 'नमस्ते', roman: 'Namaste', category: 'greetings'),
      'hello there': (
        ne: 'नमस्ते',
        roman: 'Namaste',
        category: 'greetings',
      ),
      'hey': (ne: 'नमस्ते', roman: 'Namaste', category: 'greetings'),
      'bye': (ne: 'बिदाइ', roman: 'Bidai', category: 'greetings'),
      'goodbye': (ne: 'बिदाइ', roman: 'Bidai', category: 'greetings'),
      'see you': (ne: 'बिदाइ', roman: 'Bidai', category: 'greetings'),
      'ok': (ne: 'ठिक छ', roman: 'Thik cha', category: 'communication'),
      'okay': (ne: 'ठिक छ', roman: 'Thik cha', category: 'communication'),
      'alright': (
        ne: 'ठिक छ',
        roman: 'Thik cha',
        category: 'communication',
      ),
      'yes': (ne: 'हो', roman: 'Ho', category: 'communication'),
      'no': (ne: 'होइन', roman: 'Hoina', category: 'communication'),
      'maybe': (ne: 'सायद', roman: 'Sayad', category: 'communication'),
      'sorry': (
        ne: 'माफ गर्नुहोस्',
        roman: 'Maaf garnuhos',
        category: 'communication',
      ),
      'i am sorry': (
        ne: 'माफ गर्नुहोस्',
        roman: 'Maaf garnuhos',
        category: 'communication',
      ),
      'thank you very much': (
        ne: 'धेरै धन्यवाद',
        roman: 'Dherai dhanyabad',
        category: 'greetings',
      ),
      'i am hungry': (
        ne: 'मलाई भोक लाग्यो।',
        roman: 'Malai bhok lagyo.',
        category: 'food',
      ),
      'i m hungry': (
        ne: 'मलाई भोक लाग्यो।',
        roman: 'Malai bhok lagyo.',
        category: 'food',
      ),
      'i am thirsty': (
        ne: 'मलाई तिर्खा लाग्यो।',
        roman: 'Malai tirkha lagyo.',
        category: 'food',
      ),
      'i m thirsty': (
        ne: 'मलाई तिर्खा लाग्यो।',
        roman: 'Malai tirkha lagyo.',
        category: 'food',
      ),
      'i am sick': (
        ne: 'म बिरामी छु।',
        roman: 'Ma birami chu.',
        category: 'emergency',
      ),
      'i m sick': (
        ne: 'म बिरामी छु।',
        roman: 'Ma birami chu.',
        category: 'emergency',
      ),
      'i am lost': (
        ne: 'म बाटो हराएँ।',
        roman: 'Ma bato haraye.',
        category: 'directions',
      ),
      'i am tired': (
        ne: 'म थाकेको छु।',
        roman: 'Ma thakeko chu.',
        category: 'tourism',
      ),
      'i have fever': (
        ne: 'मलाई ज्वरो आएको छ।',
        roman: 'Malai jhwaro aayeko cha.',
        category: 'emergency',
      ),
      'i have a fever': (
        ne: 'मलाई ज्वरो आएको छ।',
        roman: 'Malai jhwaro aayeko cha.',
        category: 'emergency',
      ),
      'i have headache': (
        ne: 'मेरो टाउको दुखेको छ।',
        roman: 'Mero tauko dukheko cha.',
        category: 'emergency',
      ),
      'i have a headache': (
        ne: 'मेरो टाउको दुखेको छ।',
        roman: 'Mero tauko dukheko cha.',
        category: 'emergency',
      ),
      'my stomach hurts': (
        ne: 'मेरो पेट दुखेको छ।',
        roman: 'Mero pet dukheko cha.',
        category: 'emergency',
      ),
      'call a doctor': (
        ne: 'डाक्टरलाई बोलाउनुहोस्।',
        roman: 'Doctorlai bolaunuhos.',
        category: 'emergency',
      ),
      'call the police': (
        ne: 'प्रहरीलाई बोलाउनुहोस्।',
        roman: 'Praharilai bolaunuhos.',
        category: 'emergency',
      ),
      'call an ambulance': (
        ne: 'एम्बुलेन्स बोलाउनुहोस्।',
        roman: 'Ambulance bolaunuhos.',
        category: 'emergency',
      ),
      'i am vegetarian': (
        ne: 'म शाकाहारी हुँ।',
        roman: 'Ma shakahari hu.',
        category: 'food',
      ),
      'i need vegetarian food': (
        ne: 'मलाई शाकाहारी खाना चाहिन्छ।',
        roman: 'Malai shakahari khana chahincha.',
        category: 'food',
      ),
      'do you speak english': (
        ne: 'के तपाईं अंग्रेजी बोल्नुहुन्छ?',
        roman: 'Ke tapai angreji bolnuhuncha?',
        category: 'communication',
      ),
      'please speak slowly': (
        ne: 'कृपया बिस्तारै बोल्नुहोस्।',
        roman: 'Kripaya bistaarai bolnuhos.',
        category: 'communication',
      ),
      'i do not understand': (
        ne: 'मैले बुझिनँ।',
        roman: 'Maile bujhina.',
        category: 'communication',
      ),
      'i dont understand': (
        ne: 'मैले बुझिनँ।',
        roman: 'Maile bujhina.',
        category: 'communication',
      ),
      'i don t understand': (
        ne: 'मैले बुझिनँ।',
        roman: 'Maile bujhina.',
        category: 'communication',
      ),
      'can you help me': (
        ne: 'के तपाईं मलाई मद्दत गर्न सक्नुहुन्छ?',
        roman: 'Ke tapai malai maddat garna saknuhuncha?',
        category: 'emergency',
      ),
    };

    final template = templates[normalized];
    if (template == null) return null;
    return _templateResult(
      template.ne,
      pair,
      romanized: template.roman,
      romanDetected: romanDetected,
      category: template.category,
    );
  }

  TranslationResult? _tryNepaliToEnglishTemplate(
    String input,
    _LanguagePair pair,
    bool romanDetected,
  ) {
    final staticTemplate = _nepaliStaticTemplate(input, pair, romanDetected);
    if (staticTemplate != null) return staticTemplate;

    final devanagariName = _firstCapture(
      input,
      RegExp(r'^मेरो\s+नाम\s+(.+?)\s+हो[।.!?]*$'),
    );
    if (devanagariName != null) {
      return _templateResult(
        'My name is ${_toEnglishPhrase(devanagariName)}.',
        pair,
        romanDetected: romanDetected,
        category: 'identity',
      );
    }

    final devanagariNeed = _firstCapture(
      input,
      RegExp(r'^मलाई\s+(.+?)\s+चाहिन्छ[।.!?]*$'),
    );
    if (devanagariNeed != null) {
      return _templateResult(
        'I need ${_toEnglishPhrase(devanagariNeed)}.',
        pair,
        romanDetected: romanDetected,
        category: 'tourism',
      );
    }

    final devanagariWhere = _firstCapture(
      input,
      RegExp(r'^(.+?)\s+कहाँ\s+छ[।.!?]*$'),
    );
    if (devanagariWhere != null) {
      return _templateResult(
        'Where is ${_toEnglishPhrase(devanagariWhere)}?',
        pair,
        romanDetected: romanDetected,
        category: 'directions',
      );
    }

    final roman = _normalize(input);
    final romanName = _firstCapture(
      roman,
      RegExp(r'^mero\s+(?:naam|nam|name)\s+(.+?)\s+ho$'),
    );
    if (romanName != null) {
      return _templateResult(
        'My name is ${_toTitleCase(romanName)}.',
        pair,
        romanDetected: romanDetected,
        category: 'identity',
      );
    }

    final romanNeed = _firstCapture(
      roman,
      RegExp(
        r'^malai\s+(.+?)\s+(?:chahincha|chahinchha|chaincha|chahiye|chaiyo|chahiyo)$',
      ),
    );
    if (romanNeed != null) {
      return _templateResult(
        'I need ${_toEnglishPhrase(romanNeed)}.',
        pair,
        romanDetected: romanDetected,
        category: 'tourism',
      );
    }

    final romanWhere = _firstCapture(
      roman,
      RegExp(r'^(.+?)\s+(?:kaha|kata)\s+(?:cha|chha|ho)$'),
    );
    if (romanWhere != null) {
      return _templateResult(
        'Where is ${_toEnglishPhrase(romanWhere)}?',
        pair,
        romanDetected: romanDetected,
        category: 'directions',
      );
    }

    final romanGo = _firstCapture(
      roman,
      RegExp(r'^ma\s+(.+?)\s+jana\s+chahanchu$'),
    );
    if (romanGo != null) {
      return _templateResult(
        'I want to go to ${_toEnglishPhrase(romanGo)}.',
        pair,
        romanDetected: romanDetected,
        category: 'transport',
      );
    }

    return null;
  }

  TranslationResult? _nepaliStaticTemplate(
    String input,
    _LanguagePair pair,
    bool romanDetected,
  ) {
    final normalized = _normalize(input);
    final templates = <String, ({String en, String category})>{
      'मलाई भोक लाग्यो': (en: 'I am hungry.', category: 'food'),
      'malai bhok lagyo': (en: 'I am hungry.', category: 'food'),
      'मलाई तिर्खा लाग्यो': (en: 'I am thirsty.', category: 'food'),
      'malai tirkha lagyo': (en: 'I am thirsty.', category: 'food'),
      'म बिरामी छु': (en: 'I am sick.', category: 'emergency'),
      'ma birami chu': (en: 'I am sick.', category: 'emergency'),
      'म बाटो हराएँ': (en: 'I am lost.', category: 'directions'),
      'ma bato haraye': (en: 'I am lost.', category: 'directions'),
      'मलाई ज्वरो आएको छ': (en: 'I have a fever.', category: 'emergency'),
      'malai jhwaro aayeko cha': (
        en: 'I have a fever.',
        category: 'emergency',
      ),
      'मेरो टाउको दुखेको छ': (
        en: 'I have a headache.',
        category: 'emergency',
      ),
      'mero tauko dukheko cha': (
        en: 'I have a headache.',
        category: 'emergency',
      ),
      'मेरो पेट दुखेको छ': (
        en: 'My stomach hurts.',
        category: 'emergency',
      ),
      'mero pet dukheko cha': (
        en: 'My stomach hurts.',
        category: 'emergency',
      ),
      'मैले बुझिनँ': (
        en: 'I do not understand.',
        category: 'communication',
      ),
      'maile bujhina': (
        en: 'I do not understand.',
        category: 'communication',
      ),
      'कृपया बिस्तारै बोल्नुहोस्': (
        en: 'Please speak slowly.',
        category: 'communication',
      ),
      'kripaya bistaarai bolnuhos': (
        en: 'Please speak slowly.',
        category: 'communication',
      ),
      'म शाकाहारी हुँ': (en: 'I am vegetarian.', category: 'food'),
      'ma shakahari hu': (en: 'I am vegetarian.', category: 'food'),
    };

    final template = templates[normalized];
    if (template == null) return null;
    return _templateResult(
      template.en,
      pair,
      romanDetected: romanDetected,
      category: template.category,
    );
  }

  TranslationResult _templateResult(
    String translatedText,
    _LanguagePair pair, {
    String? romanized,
    required bool romanDetected,
    required String category,
  }) {
    return TranslationResult(
      translatedText: translatedText,
      detectedSourceLang: pair.sourceLang,
      confidence: _displayConfidence(0.88, romanDetected: romanDetected),
      source: TranslationSource.template,
      isOffline: true,
      romanized: romanized,
      matchedCategory: category,
    );
  }

  String? _firstCapture(String input, RegExp pattern) {
    final match = pattern.firstMatch(input.trim());
    if (match == null || match.groupCount < 1) return null;
    return _cleanSlot(match.group(1) ?? '');
  }

  String _cleanSlot(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[।.!?]+$'), '')
        .trim();
  }

  String _toNepaliNounOrPlace(String value) {
    final place = _findDestinationTerm(value);
    if (place != null) return place.nepaliName;

    final cleaned = _cleanSlot(value);
    final normalized = _normalize(cleaned);
    final whole = _nepaliNouns[normalized];
    if (whole != null) return whole;

    final converted = cleaned.split(RegExp(r'\s+')).map((token) {
      final key = _normalize(token);
      return _nepaliNouns[key] ??
          _properNounTransliterations[key] ??
          RomanNepaliConverter.wordMap[key] ??
          token;
    }).join(' ');
    return converted.trim().isEmpty ? cleaned : converted;
  }

  String _toNepaliProperNoun(String value) {
    final place = _findDestinationTerm(value);
    if (place != null) return place.nepaliName;

    final cleaned = _cleanSlot(value);
    final normalized = _normalize(cleaned);
    final direct = _properNounTransliterations[normalized];
    if (direct != null) return direct;

    final converted = cleaned.split(RegExp(r'\s+')).map((token) {
      final key = _normalize(token);
      return _properNounTransliterations[key] ??
          RomanNepaliConverter.wordMap[key] ??
          token;
    }).join(' ');
    return converted.trim().isEmpty ? cleaned : converted;
  }

  String _toEnglishPhrase(String value) {
    final cleaned = _cleanSlot(value);
    final place = _findDestinationTerm(cleaned);
    if (place != null) return place.englishName;

    final normalized = _normalize(cleaned);
    final roman = _romanEnglishNouns[normalized];
    if (roman != null) return roman;

    final direct = _englishNouns[cleaned] ?? _englishNouns[normalized];
    if (direct != null) return direct;

    return cleaned;
  }

  String _toTitleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map(
          (token) => token.length == 1
              ? token.toUpperCase()
              : token[0].toUpperCase() + token.substring(1),
        )
        .join(' ');
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    final aTokens = a.split(' ').where((item) => item.isNotEmpty).toSet();
    final bTokens = b.split(' ').where((item) => item.isNotEmpty).toSet();
    var tokenScore = 0.0;
    if (aTokens.isNotEmpty && bTokens.isNotEmpty) {
      final intersection = aTokens.intersection(bTokens).length;
      final union = aTokens.union(bTokens).length;
      tokenScore = (intersection / union) * 0.40 +
          (intersection / math.min(aTokens.length, bTokens.length)) * 0.60;
    }

    final distance = _levenshtein(a, b);
    final charScore = 1 - (distance / math.max(a.length, b.length));
    return math.max(tokenScore, charScore.clamp(0.0, 1.0));
  }

  Future<TranslationResult?> _tryMyMemory(
    String input,
    _LanguagePair pair, {
    required bool romanDetected,
  }) async {
    _log('MyMemory -> request "${_debugPreview(input)}"');
    final quota = await _reserveMyMemoryWords(input);
    if (!quota.allowed) {
      _log('MyMemory -> quota exceeded');
      return _onlineFailureNotice(
        pair,
        'Daily limit reached. Try again tomorrow.',
      );
    }

    try {
      final uri = Uri.https(
        'api.mymemory.translated.net',
        '/get',
        {
          'q': input,
          'langpair': '${pair.sourceLang}|${pair.targetLang}',
        },
      );
      final response = await _client.get(uri).timeout(_onlineTimeout);
      _log('MyMemory -> status ${response.statusCode}');
      if (response.statusCode == 429) {
        return _onlineFailureNotice(
          pair,
          'Daily limit reached. Try again tomorrow.',
        );
      }
      if (response.statusCode != 200) {
        _log('MyMemory -> ignored non-200 response');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['responseData'] as Map<String, dynamic>?;
      final translated = data?['translatedText']?.toString().trim() ?? '';
      final translatedLower = translated.toLowerCase();
      if (translatedLower.startsWith('mymemory warning')) {
        final warning = translatedLower.contains('limit') ||
                translatedLower.contains('quota') ||
                translatedLower.contains('daily')
            ? 'Daily limit reached. Try again tomorrow.'
            : 'No internet connection for online translation.';
        _log('MyMemory -> warning response: ${_debugPreview(translated)}');
        return _onlineFailureNotice(pair, warning);
      }
      if (translated.isEmpty || _normalize(translated) == _normalize(input)) {
        _log('MyMemory -> empty or unchanged translation');
        return null;
      }

      final confidence = _parseMatch(data?['match']);
      final displayedConfidence = _displayConfidence(
        confidence,
        romanDetected: romanDetected,
      );
      final lowConfidenceWarning = confidence < 0.4
          ? 'Low confidence online translation. Please verify before using.'
          : null;
      _log(
        'MyMemory -> translated confidence=$displayedConfidence '
        'raw=$confidence warning=${lowConfidenceWarning ?? quota.warning ?? 'none'}',
      );
      return TranslationResult(
        translatedText: translated,
        detectedSourceLang: pair.sourceLang,
        confidence: displayedConfidence,
        source: TranslationSource.online,
        isOffline: false,
        warningMessage: lowConfidenceWarning ?? quota.warning,
      );
    } on TimeoutException catch (error) {
      _log('MyMemory -> timeout: $error');
      return _onlineFailureNotice(
        pair,
        'No internet connection for online translation.',
      );
    } on http.ClientException catch (error) {
      _log('MyMemory -> network error: $error');
      return _onlineFailureNotice(
        pair,
        'No internet connection for online translation.',
      );
    } catch (error) {
      _log('MyMemory -> failed: $error');
      return _onlineFailureNotice(
        pair,
        'No internet connection for online translation.',
      );
    }
  }

  Future<TranslationResult?> _tryClaudeBackend(
    String input,
    TranslationDirection direction,
    _LanguagePair pair, {
    required bool romanDetected,
  }) async {
    if (BackendConfig.health.value?.reachable == false) {
      _log('backend -> skipped because health is unreachable');
      return null;
    }

    try {
      _log('backend -> POST ${BackendConfig.uri('/translate')}');
      final response = await _client
          .post(
            BackendConfig.uri('/translate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': input,
              'direction': direction.name,
              'context': 'tourism',
            }),
          )
          .timeout(_onlineTimeout);

      _log('backend -> status ${response.statusCode}');
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = decoded['translated']?.toString().trim() ?? '';
      if (translated.isEmpty) {
        _log('backend -> empty translation');
        return null;
      }

      return TranslationResult(
        translatedText: translated,
        detectedSourceLang: pair.sourceLang,
        confidence: _displayConfidence(
          _parseMatch(decoded['confidence']),
          romanDetected: romanDetected,
        ),
        source: TranslationSource.fallback,
        isOffline: false,
        romanized: decoded['roman']?.toString(),
      );
    } catch (error) {
      _log('backend -> failed: $error');
      return null;
    }
  }

  Future<_QuotaReservation> _reserveMyMemoryWords(String input) async {
    final count = input
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .length;
    final dayKey = DateTime.now().toIso8601String().substring(0, 10);
    final key = '$_myMemoryCounterPrefix$dayKey';
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(key) ?? 0;
    final next = used + count;

    if (next > _myMemoryDailyLimit) {
      return const _QuotaReservation(
        allowed: false,
        warning: 'Daily limit reached. Try again tomorrow.',
      );
    }

    await prefs.setInt(key, next);
    if (next >= _myMemoryWarningLimit) {
      return _QuotaReservation(
        allowed: true,
        warning:
            'MyMemory free limit is almost used today ($next/$_myMemoryDailyLimit words).',
      );
    }

    return const _QuotaReservation(allowed: true);
  }

  double _parseMatch(Object? value) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    if (value is String) {
      return (double.tryParse(value) ?? 0.0).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  double _displayConfidence(
    double confidence, {
    bool exactPhrasebook = false,
    bool romanDetected = false,
  }) {
    if (exactPhrasebook) return 1.0;
    var value = confidence.clamp(0.0, 1.0);
    if (romanDetected) value = math.min(value, 0.75);
    return math.min(value, 0.95);
  }

  String _outputFor(TourismPhrasebookEntry entry, _LanguagePair pair) {
    return pair.targetLang == 'ne-NP' ? entry.nepali : entry.english;
  }

  TranslationResult _backendOfflineFailure({
    required String detectedSourceLang,
    String? warningMessage,
  }) {
    return _failure(
      detectedSourceLang: detectedSourceLang,
      message:
          'No match found offline. Start the backend at ${AppConfig.baseUrl} for full translation.',
      warningMessage: warningMessage,
    );
  }

  TranslationResult _allMethodsFailed({
    required String detectedSourceLang,
    String? warningMessage,
  }) {
    return _failure(
      detectedSourceLang: detectedSourceLang,
      message: 'Could not translate. Try a simpler or common tourism phrase.',
      warningMessage: warningMessage,
    );
  }

  TranslationResult _onlineFailureNotice(
    _LanguagePair pair,
    String message,
  ) {
    return TranslationResult(
      translatedText: message,
      detectedSourceLang: pair.sourceLang,
      confidence: 0,
      source: TranslationSource.fallback,
      isOffline: false,
      warningMessage: message,
    );
  }

  TranslationResult _failure({
    required String detectedSourceLang,
    required String message,
    String? warningMessage,
  }) {
    return TranslationResult(
      translatedText: message,
      detectedSourceLang: detectedSourceLang,
      confidence: 0,
      source: TranslationSource.fallback,
      isOffline: false,
      warningMessage: warningMessage,
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('TranslationService: $message');
    }
  }

  void _logResult(
    String step,
    TranslationResult result, {
    String? fallthrough,
  }) {
    final suffix = fallthrough == null ? '' : ' -> $fallthrough';
    _log(
      '$step -> source=${result.source.name} offline=${result.isOffline} '
      'confidence=${result.confidence.toStringAsFixed(2)} '
      'text="${_debugPreview(result.translatedText)}"'
      '${result.warningMessage == null ? '' : ' warning="${result.warningMessage}"'}'
      '$suffix',
    );
  }

  String _debugPreview(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 80 ? compact : '${compact.substring(0, 77)}...';
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('।', ' ')
        .replaceAll(RegExp(r'[^\u0900-\u097Fa-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .join(' ');
  }

  int _levenshtein(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
        current[j + 1] = math.min(insert, math.min(delete, replace));
      }
      previous.setAll(0, current);
    }

    return previous[b.length];
  }

  Future<void> _loadPhrasebook() async {
    final loaded = <TourismPhrasebookEntry>[];
    await _loadPhrasebookAsset(
      'assets/data/intelligence/phrasebook_enhanced.json',
      loaded,
    );
    await _loadPhrasebookAsset('assets/data/phrasebook.json', loaded);

    final byEnglish = <String, TourismPhrasebookEntry>{};
    for (final entry in loaded) {
      if (entry.english.isEmpty || entry.nepali.isEmpty) continue;
      byEnglish.putIfAbsent(_normalize(entry.english), () => entry);
    }
    _phrasebook = byEnglish.values.toList(growable: false);
  }

  Future<void> _loadPhrasebookAsset(
    String path,
    List<TourismPhrasebookEntry> target,
  ) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entries = decoded['entries'] as List? ?? const [];
      target.addAll(
        entries.whereType<Map>().map(
              (item) => TourismPhrasebookEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
      );
    } catch (_) {}
  }

  Future<void> _loadDestinationTerms() async {
    try {
      final raw = await rootBundle.loadString('assets/data/destinations.json');
      final decoded = jsonDecode(raw);
      final items = decoded is List
          ? decoded
          : decoded is Map
              ? decoded['destinations'] as List? ?? const []
              : const [];

      final terms = <_DestinationTerm>[];
      for (final item in items.whereType<Map>()) {
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        terms.add(_buildDestinationTerm(name));
      }

      _destinationTerms = terms;
    } catch (_) {
      _destinationTerms = const [
        _DestinationTerm(
          englishName: 'Pokhara',
          nepaliName: 'पोखरा',
          aliases: {'pokhara'},
        ),
        _DestinationTerm(
          englishName: 'Ghandruk',
          nepaliName: 'घान्द्रुक',
          aliases: {'ghandruk'},
        ),
        _DestinationTerm(
          englishName: 'Mardi Himal',
          nepaliName: 'मार्दी हिमाल',
          aliases: {'mardi himal', 'mardi'},
        ),
      ];
    }
  }

  _DestinationTerm _buildDestinationTerm(String name) {
    final aliases = _destinationAliases(name);
    final nepaliName = _transliterateDestinationName(name);
    final normalizedNepali = _normalize(nepaliName);
    if (normalizedNepali.isNotEmpty) aliases.add(normalizedNepali);
    return _DestinationTerm(
      englishName: name,
      nepaliName: nepaliName,
      aliases: aliases,
    );
  }

  Set<String> _destinationAliases(String name) {
    final normalized = _normalize(name);
    final aliases = <String>{if (normalized.isNotEmpty) normalized};
    final tokens = normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    if (tokens.length > 1) {
      var end = tokens.length;
      while (end > 1 && _genericPlaceSuffixes.contains(tokens[end - 1])) {
        end--;
      }
      if (end > 0 && end < tokens.length) {
        aliases.add(tokens.take(end).join(' '));
      }

      aliases.add(tokens.take(2).join(' '));

      final first = tokens.first;
      if (first.length >= 5 && !_genericSingleWordAliases.contains(first)) {
        aliases.add(first);
      }
    }

    return aliases.where((alias) => alias.length >= 3).toSet();
  }

  String _transliterateDestinationName(String name) {
    return name.replaceAll('&', 'and').split(RegExp(r'\s+')).map((token) {
      final clean = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final key = clean.toLowerCase();
      if (key.isEmpty) return token;
      return _properNounTransliterations[key] ?? token;
    }).join(' ');
  }

  _DestinationTerm? _findDestinationTerm(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return null;
    for (final term in _destinationTerms) {
      if (term.aliases.contains(normalized)) return term;
    }
    return null;
  }
}

class _DestinationTerm {
  final String englishName;
  final String nepaliName;
  final Set<String> aliases;

  const _DestinationTerm({
    required this.englishName,
    required this.nepaliName,
    required this.aliases,
  });
}

class _LanguagePair {
  final String sourceLang;
  final String targetLang;

  const _LanguagePair(this.sourceLang, this.targetLang);
}

class _PhraseScore {
  final TourismPhrasebookEntry entry;
  final double score;

  const _PhraseScore(this.entry, this.score);
}

class _QuotaReservation {
  final bool allowed;
  final String? warning;

  const _QuotaReservation({
    required this.allowed,
    this.warning,
  });
}
