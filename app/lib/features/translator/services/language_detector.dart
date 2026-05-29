import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class LanguageDetectionResult {
  final String languageCode;
  final bool isRomanNepali;
  final double confidence;

  const LanguageDetectionResult({
    required this.languageCode,
    required this.isRomanNepali,
    required this.confidence,
  });
}

class LanguageDetector {
  final RomanNepaliDetector romanNepaliDetector;

  const LanguageDetector({required this.romanNepaliDetector});

  LanguageDetectionResult detect(String text) {
    if (_containsDevanagari(text)) {
      return const LanguageDetectionResult(
        languageCode: 'ne-NP',
        isRomanNepali: false,
        confidence: 0.98,
      );
    }

    if (romanNepaliDetector.isRomanNepali(text)) {
      return const LanguageDetectionResult(
        languageCode: 'ne-NP',
        isRomanNepali: true,
        confidence: 0.75,
      );
    }

    return const LanguageDetectionResult(
      languageCode: 'en-US',
      isRomanNepali: false,
      confidence: 0.90,
    );
  }

  bool _containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }
}

class RomanNepaliDetector {
  static const _fallbackWords = <String>{
    'namaste',
    'namaskar',
    'dhanyabad',
    'dhanyavaad',
    'tapai',
    'tapaiko',
    'timi',
    'malai',
    'mero',
    'ma',
    'hami',
    'hamro',
    'kotha',
    'khana',
    'paani',
    'pani',
    'bistaar',
    'bistari',
    'ramro',
    'naramro',
    'gardai',
    'garnu',
    'garnus',
    'huncha',
    'hunchha',
    'cha',
    'chha',
    'ho',
    'hoina',
    'haina',
    'hajur',
    'dai',
    'didi',
    'bhai',
    'bahini',
    'sanchai',
    'theek',
    'thik',
    'kati',
    'kaha',
    'kata',
    'kahile',
    'kasari',
    'kina',
    'ke',
    'yo',
    'tyo',
    'yaha',
    'tyaha',
    'bato',
    'gaun',
    'ghar',
    'hotel',
    'homestay',
    'bazar',
    'mandir',
    'gumba',
    'paisa',
    'rupiya',
    'sasto',
    'mahango',
    'chaiyo',
    'chahiyo',
    'chahincha',
    'chahinchha',
    'chahiye',
    'dinus',
    'dinu',
    'linus',
    'basnu',
    'basna',
    'jana',
    'auna',
    'aaunu',
    'jane',
    'aauchha',
    'lagcha',
    'lagyo',
    'bhayo',
    'parcha',
    'parchha',
    'mildaina',
    'milcha',
    'sakchu',
    'sakincha',
    'bujhina',
    'bujhiyena',
    'madat',
    'maddat',
    'doctor',
    'aspatal',
    'ausadhi',
    'bhok',
    'tirkha',
    'mitho',
    'piro',
    'chiya',
    'kafi',
    'dal',
    'bhat',
    'taato',
    'chiso',
    'naramro',
    'sajilo',
    'garo',
    'tadha',
    'najik',
    'mathi',
    'tala',
    'sidha',
    'baya',
    'daya',
    'sathi',
    'subha',
    'prabhat',
    'sanjha',
    'rati',
    'aaja',
    'bholi',
    'hijo',
    'ahile',
    'pachi',
    'chadai',
  };

  Set<String> _words = _fallbackWords;

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/intelligence/nepali_stopwords.json',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final romanWords = (decoded['romanNepali'] as List? ?? const [])
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty);
      _words = {..._fallbackWords, ...romanWords};
    } catch (_) {
      _words = _fallbackWords;
    }
  }

  bool isRomanNepali(String text) {
    final tokens = _tokens(text);
    if (tokens.isEmpty) return false;

    final matches = tokens.where(_words.contains).length;
    if (matches >= 2) return true;
    if (matches == 1 && tokens.length <= 4) return true;

    final joined = tokens.join(' ');
    return joined.contains('malai ') ||
        joined.contains(' tapai') ||
        joined.contains(' cha') ||
        joined.contains(' chha') ||
        joined.contains(' huncha') ||
        joined.contains(' chahincha');
  }

  List<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
