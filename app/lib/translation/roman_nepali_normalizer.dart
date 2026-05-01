class RomanNepaliNormalizer {
  RomanNepaliNormalizer._();

  static final RegExp _devanagariRegex = RegExp(r'[\u0900-\u097F]');
  static final RegExp _latinRegex = RegExp(r'[A-Za-z]');

  static const Map<String, String> _aliases = {
    'namastay': 'namaste',
    'namste': 'namaste',
    'namaskar': 'namaste',
    'ma': 'ma',
    'maa': 'ma',
    'maile': 'maile',
    'mailay': 'maile',
    'mailey': 'maile',
    'moile': 'maile',
    'moiley': 'maile',
    'malai': 'malai',
    'malay': 'malai',
    'malaai': 'malai',
    'malaii': 'malai',
    'pani': 'pani',
    'paani': 'pani',
    'panee': 'pani',
    'panii': 'pani',
    'khana': 'khana',
    'khaana': 'khana',
    'food': 'khana',
    'bhok': 'bhok',
    'vok': 'bhok',
    'bhukh': 'bhok',
    'bhook': 'bhok',
    'tirkha': 'tirkha',
    'tirka': 'tirkha',
    'trikha': 'tirkha',
    'chaiyo': 'chaiyo',
    'chahiyo': 'chaiyo',
    'chahiyoo': 'chaiyo',
    'chaincha': 'chaiyo',
    'chainxa': 'chaiyo',
    'need': 'chaiyo',
    'want': 'chaiyo',
    'dinus': 'dinus',
    'dinu': 'dinus',
    'dinuna': 'dinus na',
    'dinuhos': 'dinus',
    'dinuos': 'dinus',
    'plz': 'please',
    'pls': 'please',
    'khaye': 'khaye',
    'khae': 'khaye',
    'khay': 'khaye',
    'khayen': 'khaye',
    'khayein': 'khaye',
    'lagyo': 'lagyo',
    'lageo': 'lagyo',
    'lagyocha': 'lagyo cha',
    'lagyochha': 'lagyo cha',
    'cha': 'cha',
    'chha': 'cha',
    'xa': 'cha',
    'xha': 'cha',
    '6': 'cha',
    'chaina': 'chaina',
    'xaina': 'chaina',
    'chhaina': 'chaina',
    'kata': 'kata',
    'kataa': 'kata',
    'kaha': 'kata',
    'kahaa': 'kata',
    'ka': 'kata',
    'where': 'kata',
    'kati': 'kati',
    'katti': 'kati',
    'katiko': 'kati',
    'paisa': 'paisa',
    'price': 'paisa',
    'cost': 'paisa',
    'samaya': 'samaya',
    'samay': 'samaya',
    'time': 'samaya',
    'lagcha': 'lagcha',
    'lagxa': 'lagcha',
    'lagchha': 'lagcha',
    'tadha': 'tadha',
    'tada': 'tadha',
    'taadha': 'tadha',
    'far': 'tadha',
    'busstop': 'bus stop',
    'bus-stop': 'bus stop',
    'homestay': 'homestay',
    'home-stay': 'homestay',
    'kotha': 'kotha',
    'bazar': 'market',
    'bazaar': 'market',
    'mandir': 'temple',
    'foto': 'photo',
    'sidha': 'straight',
    'sida': 'straight',
    'baya': 'left',
    'daya': 'right',
    'madat': 'help',
    'maddat': 'help',
    'sahayata': 'help',
    'birami': 'sick',
    'biraami': 'sick',
    'ghaite': 'injured',
    'ghaito': 'injured',
  };

  static bool isDevanagari(String value) {
    return _devanagariRegex.hasMatch(value);
  }

  static String detectScript(String value) {
    final hasDevanagari = _devanagariRegex.hasMatch(value);
    final hasLatin = _latinRegex.hasMatch(value);

    if (hasDevanagari && hasLatin) return 'mixed';
    if (hasDevanagari) return 'devanagari';
    if (hasLatin && looksLikeRomanNepali(value)) return 'roman_nepali';
    if (hasLatin) return 'english';

    return 'unknown';
  }

  static bool looksLikeRomanNepali(String value) {
    final cleaned = _basicClean(value);
    final tokens = cleaned.split(' ').where((token) => token.isNotEmpty);

    const markers = {
      'malai',
      'maile',
      'pani',
      'paani',
      'khana',
      'chaiyo',
      'chahiyo',
      'dinus',
      'kata',
      'kaha',
      'cha',
      'chha',
      'xa',
      'kati',
      'lagcha',
      'bhok',
      'tirkha',
      'kotha',
      'homestay',
      'mandir',
      'bazar',
      'doctor',
      'madat',
    };

    var hits = 0;

    for (final token in tokens) {
      if (markers.contains(token) || _aliases.containsKey(token)) hits++;
    }

    return hits >= 1;
  }

  static String normalize(String value) {
    if (value.trim().isEmpty) return '';

    if (isDevanagari(value) && !_latinRegex.hasMatch(value)) {
      return value
          .replaceAll(RegExp(r'[।!?.,;:()\[\]{}"“”‘’]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final cleaned = _basicClean(value);
    final tokens = cleaned.split(' ');
    final output = <String>[];

    for (final rawToken in tokens) {
      if (rawToken.trim().isEmpty) continue;

      if (_devanagariRegex.hasMatch(rawToken)) {
        output.add(rawToken);
        continue;
      }

      final normalized = _normalizeLatinToken(rawToken);

      if (normalized.contains(' ')) {
        output.addAll(normalized.split(' ').where((item) => item.isNotEmpty));
      } else {
        output.add(normalized);
      }
    }

    return output.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> tokenize(String value) {
    final normalized = normalize(value);

    if (normalized.isEmpty) return [];

    return normalized
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .where((token) {
      if (_devanagariRegex.hasMatch(token)) return true;
      return token.length > 1;
    }).toList();
  }

  static String _basicClean(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeLatinToken(String token) {
    final direct = _aliases[token];
    if (direct != null) return direct;

    var reduced = token.replaceAll('-', '');

    reduced = reduced.replaceAll(RegExp(r'a{2,}'), 'a');
    reduced = reduced.replaceAll(RegExp(r'i{2,}'), 'i');
    reduced = reduced.replaceAll(RegExp(r'e{2,}'), 'e');
    reduced = reduced.replaceAll(RegExp(r'o{2,}'), 'o');
    reduced = reduced.replaceAll(RegExp(r'u{2,}'), 'u');

    if (reduced.endsWith('chha')) {
      reduced = reduced.replaceFirst(RegExp(r'chha$'), 'cha');
    } else if (reduced.endsWith('xa')) {
      reduced = reduced.replaceFirst(RegExp(r'xa$'), 'cha');
    }

    return _aliases[reduced] ?? reduced;
  }
}