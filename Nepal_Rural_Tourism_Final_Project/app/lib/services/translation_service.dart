import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _baseUrl = "https://libretranslate.de/translate";

  static Future<String> translate({
    required String text,
    required bool englishToNepali,
  }) async {
    final input = text.trim();
    if (input.isEmpty) return "Enter text";

    final source = englishToNepali ? "en" : "ne";
    final target = englishToNepali ? "ne" : "en";

    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "q": input,
          "source": source,
          "target": target,
          "format": "text"
        }),
      );

      print("STATUS: ${res.statusCode}");
      print("BODY: ${res.body}");

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return data["translatedText"];
      }

      return "Translation failed";
    } catch (e) {
      print("ERROR: $e");
      return "Network error";
    }
  }
}