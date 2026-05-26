import '../models/translation_request.dart';
import '../models/translation_response.dart';
import 'translation_engine.dart';

class NeuralTranslationAdapter implements TranslationEngine {
  bool _available = false;

  bool get isAvailable => _available;

  @override
  Future<void> load() async {
    _available = false;
  }

  @override
  Future<TranslationResponse?> translate(TranslationRequest request) async {
    if (!_available || !request.allowNeural) return null;
    return null;
  }
}
