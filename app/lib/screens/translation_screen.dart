import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/translation_service.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _englishConversationController =
      TextEditingController();
  final TextEditingController _nepaliConversationController =
      TextEditingController();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();

  bool _englishToNepali = true;
  bool _loading = false;
  bool _speechReady = false;
  bool _listening = false;
  bool _ocrLoading = false;
  bool _conversationLoading = false;

  TranslationResult? _result;
  TranslationResult? _englishConversationResult;
  TranslationResult? _nepaliConversationResult;
  TranslationResult? _ocrResult;
  String _ocrText = '';

  List<TranslationHistoryEntry> _history = [];
  Map<String, Map<String, String>> _phrases = {};
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _refreshHistory();
    _loadPhrases();
  }

  @override
  void dispose() {
    _controller.dispose();
    _englishConversationController.dispose();
    _nepaliConversationController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _listening = false);
        },
      );
      if (!mounted) return;
      setState(() => _speechReady = ready);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechReady = false);
    }
  }

  Future<void> _refreshHistory() async {
    final history = await TranslationService.getHistory();
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _loadPhrases() async {
    final phrases = await TranslationService.getPhrases(
      englishToNepali: _englishToNepali,
    );
    if (!mounted) return;
    setState(() {
      _phrases = phrases;
      _selectedCategory = phrases.keys.isEmpty ? null : phrases.keys.first;
    });
  }

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    final result = await TranslationService.translate(
      text: text,
      englishToNepali: _englishToNepali,
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
    _refreshHistory();
  }

  Future<void> _translateConversation({required bool englishToNepali}) async {
    final controller = englishToNepali
        ? _englishConversationController
        : _nepaliConversationController;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _conversationLoading = true);
    final result = await TranslationService.translate(
      text: text,
      englishToNepali: englishToNepali,
    );

    if (!mounted) return;
    setState(() {
      if (englishToNepali) {
        _englishConversationResult = result;
      } else {
        _nepaliConversationResult = result;
      }
      _conversationLoading = false;
    });
    _refreshHistory();
  }

  Future<void> _listenInto(
    TextEditingController controller, {
    required bool sourceIsEnglish,
    Future<void> Function()? onFinal,
  }) async {
    if (!_speechReady) {
      _showSnack('Speech recognition is not available on this device.');
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      localeId: sourceIsEnglish ? 'en_US' : 'ne_NP',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) async {
        controller.text = result.recognizedWords;
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        if (result.finalResult && onFinal != null) {
          await onFinal();
        }
      },
    );
  }

  Future<void> _speakText(String text, {required bool textIsNepali}) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.setLanguage(textIsNepali ? 'ne-NP' : 'en-US');
    await _tts.speak(text);
  }

  Future<void> _scanImage(ImageSource source) async {
    setState(() {
      _ocrLoading = true;
      _ocrText = '';
      _ocrResult = null;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (image == null) {
        if (!mounted) return;
        setState(() => _ocrLoading = false);
        return;
      }

      final script = _englishToNepali
          ? TextRecognitionScript.latin
          : TextRecognitionScript.devanagiri;
      final recognizer = TextRecognizer(script: script);
      final recognizedText = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      await recognizer.close();

      final extracted = recognizedText.text.trim();
      TranslationResult? translation;
      if (extracted.isNotEmpty) {
        translation = await TranslationService.translate(
          text: extracted,
          englishToNepali: _englishToNepali,
        );
      }

      if (!mounted) return;
      setState(() {
        _ocrText = extracted;
        _ocrResult = translation;
        _controller.text = extracted;
        _result = translation;
        _ocrLoading = false;
      });
      _refreshHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocrLoading = false);
      _showSnack('OCR failed: $e');
    }
  }

  Future<void> _copy(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard');
  }

  void _swapDirection() {
    setState(() {
      _englishToNepali = !_englishToNepali;
      _result = null;
      _ocrResult = null;
      _ocrText = '';
    });
    _loadPhrases();
  }

  void _reverseIntoInput() {
    final result = _result;
    if (result == null || result.text.trim().isEmpty || result.isError) return;
    setState(() {
      _controller.text = result.text;
      _englishToNepali = !_englishToNepali;
      _result = null;
    });
    _loadPhrases();
  }

  Future<void> _clearHistory() async {
    await TranslationService.clearHistory();
    await _refreshHistory();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel = _englishToNepali ? 'English' : 'Nepali';
    final targetLabel = _englishToNepali ? 'Nepali' : 'English';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Translate'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.translate_rounded), text: 'Text'),
              Tab(icon: Icon(Icons.record_voice_over_rounded), text: 'Conversation'),
              Tab(icon: Icon(Icons.document_scanner_outlined), text: 'Camera OCR'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Phrasebook'),
              Tab(icon: Icon(Icons.history_rounded), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTextTranslator(sourceLabel, targetLabel),
            _buildConversationMode(),
            _buildCameraOcr(sourceLabel, targetLabel),
            _buildPhrasebook(),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextTranslator(String sourceLabel, String targetLabel) {
    final result = _result;
    final outputText = result?.text ?? 'Your translated text will appear here.';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RealityCheckCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translation direction',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _LangBox(label: sourceLabel)),
                    IconButton(
                      onPressed: _swapDirection,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      tooltip: 'Swap languages',
                    ),
                    Expanded(child: _LangBox(label: targetLabel)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Enter text in $sourceLabel',
                    hintText: _englishToNepali
                        ? 'Example: Where is the homestay?'
                        : 'उदाहरण: होमस्टे कहाँ छ?',
                    suffixIcon: IconButton(
                      tooltip: 'Voice input',
                      icon: Icon(
                        _listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                      ),
                      onPressed: () => _listenInto(
                        _controller,
                        sourceIsEnglish: _englishToNepali,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _translate,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.translate_rounded),
                        label: Text(_loading ? 'Translating...' : 'Translate'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Scan with camera',
                      onPressed: _ocrLoading
                          ? null
                          : () => _scanImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Translated output',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (result != null)
                      _SourceBadge(result: result),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  outputText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                ),
                if (result?.matchedPhrase != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Matched phrase: ${result!.matchedPhrase}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: result == null || result.text.isEmpty
                          ? null
                          : () => _speakText(
                                result.text,
                                textIsNepali: _englishToNepali,
                              ),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Speak'),
                    ),
                    OutlinedButton.icon(
                      onPressed: result == null || result.text.isEmpty
                          ? null
                          : () => _copy(result.text),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: result == null || result.isError
                          ? null
                          : _reverseIntoInput,
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Reverse'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationMode() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Two-way conversation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Use this in tourist-host conversations. Each half has its own input direction.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _ConversationPane(
          title: 'Tourist speaks English',
          subtitle: 'English → Nepali',
          controller: _englishConversationController,
          result: _englishConversationResult,
          loading: _conversationLoading,
          hint: 'Example: How much is the room per night?',
          onListen: () => _listenInto(
            _englishConversationController,
            sourceIsEnglish: true,
            onFinal: () => _translateConversation(englishToNepali: true),
          ),
          onTranslate: () => _translateConversation(englishToNepali: true),
          onSpeakInput: () => _speakText(
            _englishConversationController.text,
            textIsNepali: false,
          ),
          onSpeakOutput: () => _speakText(
            _englishConversationResult?.text ?? '',
            textIsNepali: true,
          ),
          onCopyOutput: () => _copy(_englishConversationResult?.text ?? ''),
        ),
        const SizedBox(height: 16),
        _ConversationPane(
          title: 'Host speaks Nepali',
          subtitle: 'Nepali → English',
          controller: _nepaliConversationController,
          result: _nepaliConversationResult,
          loading: _conversationLoading,
          hint: 'उदाहरण: कोठा खाली छ?',
          onListen: () => _listenInto(
            _nepaliConversationController,
            sourceIsEnglish: false,
            onFinal: () => _translateConversation(englishToNepali: false),
          ),
          onTranslate: () => _translateConversation(englishToNepali: false),
          onSpeakInput: () => _speakText(
            _nepaliConversationController.text,
            textIsNepali: true,
          ),
          onSpeakOutput: () => _speakText(
            _nepaliConversationResult?.text ?? '',
            textIsNepali: false,
          ),
          onCopyOutput: () => _copy(_nepaliConversationResult?.text ?? ''),
        ),
      ],
    );
  }

  Widget _buildCameraOcr(String sourceLabel, String targetLabel) {
    final result = _ocrResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Camera OCR translation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Scan printed signs, menus, or notice boards. OCR runs through ML Kit text recognition; translation uses the same phrasebook/online fallback chain.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _LangBox(label: sourceLabel)),
                    IconButton(
                      onPressed: _swapDirection,
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    Expanded(child: _LangBox(label: targetLabel)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _ocrLoading
                            ? null
                            : () => _scanImage(ImageSource.camera),
                        icon: _ocrLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt_outlined),
                        label: Text(_ocrLoading ? 'Scanning...' : 'Use camera'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _ocrLoading
                            ? null
                            : () => _scanImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Extracted text', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SelectableText(
                  _ocrText.isEmpty ? 'No text scanned yet.' : _ocrText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_ocrText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _copy(_ocrText),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy extracted text'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Translation',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (result != null) _SourceBadge(result: result),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  result?.text ?? 'OCR translation will appear here.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: result == null || result.text.isEmpty
                          ? null
                          : () => _speakText(
                                result.text,
                                textIsNepali: _englishToNepali,
                              ),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Speak'),
                    ),
                    OutlinedButton.icon(
                      onPressed: result == null || result.text.isEmpty
                          ? null
                          : () => _copy(result.text),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhrasebook() {
    final categories = _phrases.keys.toList();
    final selected = _selectedCategory;
    final phrases = selected == null ? <MapEntry<String, String>>[] :
        (_phrases[selected] ?? {}).entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _englishToNepali ? 'English → Nepali phrases' : 'Nepali → English phrases',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _swapDirection,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Swap'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                selected: category == selected,
                label: Text(_humanizeCategory(category)),
                onSelected: (_) => setState(() => _selectedCategory = category),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: categories.length,
          ),
        ),
        Expanded(
          child: phrases.isEmpty
              ? const Center(child: Text('No phrases available.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final phrase = phrases[index];
                    return Card(
                      child: ListTile(
                        title: Text(phrase.key),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(phrase.value),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Speak translation',
                              onPressed: () => _speakText(
                                phrase.value,
                                textIsNepali: _englishToNepali,
                              ),
                              icon: const Icon(Icons.volume_up_outlined),
                            ),
                            IconButton(
                              tooltip: 'Use phrase',
                              onPressed: () {
                                _controller.text = phrase.key;
                                _translate();
                                _showSnack('Phrase copied to translator');
                              },
                              icon: const Icon(Icons.north_east_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: phrases.length,
                ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent translations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _history.isEmpty ? null : _clearHistory,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _history.isEmpty
              ? const Center(child: Text('No translation history yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    return Card(
                      child: ListTile(
                        title: Text(entry.sourceText),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.translatedText),
                              const SizedBox(height: 6),
                              Text(
                                '${entry.englishToNepali ? 'English → Nepali' : 'Nepali → English'} • ${entry.source.name}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Copy translation',
                          onPressed: () => _copy(entry.translatedText),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                        onTap: () {
                          setState(() {
                            _englishToNepali = entry.englishToNepali;
                            _controller.text = entry.sourceText;
                            _result = TranslationResult(
                              text: entry.translatedText,
                              source: entry.source,
                              originalText: entry.sourceText,
                              englishToNepali: entry.englishToNepali,
                            );
                          });
                          _loadPhrases();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _humanizeCategory(String category) {
    if (category.isEmpty) return category;
    return category[0].toUpperCase() + category.substring(1).replaceAll('_', ' ');
  }
}

class _RealityCheckCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: cs.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Offline free-form Nepali translation is not provided by Google ML Kit. This module uses an offline tourism phrasebook first, then an online translator for free-form sentences.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangBox extends StatelessWidget {
  final String label;

  const _LangBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final TranslationResult result;

  const _SourceBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isOffline
        ? Theme.of(context).colorScheme.tertiary
        : result.isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            result.isOffline
                ? Icons.offline_bolt_outlined
                : result.isError
                    ? Icons.error_outline_rounded
                    : Icons.cloud_done_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            result.sourceLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPane extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final TranslationResult? result;
  final bool loading;
  final String hint;
  final VoidCallback onListen;
  final VoidCallback onTranslate;
  final VoidCallback onSpeakInput;
  final VoidCallback onSpeakOutput;
  final VoidCallback onCopyOutput;

  const _ConversationPane({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.result,
    required this.loading,
    required this.hint,
    required this.onListen,
    required this.onTranslate,
    required this.onSpeakInput,
    required this.onSpeakOutput,
    required this.onCopyOutput,
  });

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (result != null) _SourceBadge(result: result),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                suffixIcon: IconButton(
                  tooltip: 'Speak input',
                  onPressed: onSpeakInput,
                  icon: const Icon(Icons.volume_up_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : onTranslate,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate_rounded),
                  label: const Text('Translate'),
                ),
                OutlinedButton.icon(
                  onPressed: onListen,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text('Listen'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                result?.text ?? 'Translation will appear here.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: result == null ? null : onSpeakOutput,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Speak output'),
                ),
                OutlinedButton.icon(
                  onPressed: result == null ? null : onCopyOutput,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy output'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}