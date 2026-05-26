import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import '../translation/roman_nepali_normalizer.dart';
import '../translation/translation_intent_model.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen>
    with TickerProviderStateMixin {
  final TranslationService _service = TranslationService.instance;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _conversationController = TextEditingController();
  final TextEditingController _phrasebookSearch = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final TabController _tabController;

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _ready = false;
  bool _loading = false;
  bool _speechReady = false;
  bool _listening = false;
  bool _nepaliTtsAvailable = true;

  String? _error;

  TranslationMode _mode = TranslationMode.autoDetect;
  TranslationResult? _currentResult;

  String _selectedCategory = 'greetings';
  String _searchQuery = '';

  List<PhrasebookEntry> _categoryEntries = [];
  List<TranslationHistoryEntry> _history = [];

  final List<_ConversationMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    _conversationController.dispose();
    _phrasebookSearch.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speech.stop();

    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      await _initSpeech();
      await _initTts();

      _loadCategory(_selectedCategory);
      _refreshHistory();

      if (!mounted) return;

      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = e.toString());
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
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
    } catch (_) {
      _speechReady = false;
    }
  }

  Future<void> _initTts() async {
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);

    try {
      final languages = await _tts.getLanguages as List?;
      final hasNepali = languages?.any(
            (language) => language.toString().toLowerCase().contains('ne'),
          ) ??
          false;

      if (!mounted) return;

      setState(() => _nepaliTtsAvailable = hasNepali);
    } catch (_) {
      if (!mounted) return;

      setState(() => _nepaliTtsAvailable = false);
    }
  }

  Future<void> _translateText() async {
    final text = _inputController.text.trim();

    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _currentResult = null;
    });

    final result = await _translateSafely(text);

    if (!mounted) return;

    setState(() {
      _currentResult = result;
      _loading = false;
    });

    _refreshHistory();

    if (result.isSuccess) {
      await _speakResult(result);
    }
  }

  Future<void> _sendConversationMessage() async {
    final text = _conversationController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _messages.add(_ConversationMessage(text: text, isUser: true));
      _conversationController.clear();
    });

    final result = await _translateSafely(text);

    if (!mounted) return;

    setState(() {
      _messages.add(
        _ConversationMessage(
          text: result.isSuccess
              ? result.translatedText
              : result.errorMessage ?? 'No suitable translation found.',
          isUser: false,
          result: result,
        ),
      );
      _loading = false;
    });

    _refreshHistory();
    _scrollConversationToBottom();

    if (result.isSuccess) {
      final lang = result.strategy == TranslationStrategy.phrasebookMatch ||
              result.strategy == TranslationStrategy.intentModel
          ? (RomanNepaliNormalizer.isDevanagari(result.translatedText)
              ? 'ne-NP'
              : 'en-US')
          : 'en-US';

      await _speakText(result.translatedText, lang);
    }
  }

  Future<TranslationResult> _translateSafely(String text) async {
    try {
      return await _service.translate(
        input: text,
        mode: _mode,
        allowOnline: true,
      );
    } catch (_) {
      return const TranslationResult(
        translatedText: '',
        strategy: TranslationStrategy.noResult,
        confidence: 0,
        errorMessage:
            'Translation failed. Try again or use the offline phrasebook.',
      );
    }
  }

  Future<void> _listenInto(TextEditingController controller) async {
    if (!_speechReady) {
      _showSnack('Speech recognition is not available.');
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() => _listening = false);
      return;
    }

    final locale = _mode == TranslationMode.nepaliToEnglish ? 'ne_NP' : 'en_US';

    setState(() => _listening = true);

    await _speech.listen(
      localeId: locale,
      onResult: (result) {
        controller.text = result.recognizedWords;
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );

        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
    );
  }

  Future<void> _speakResult(TranslationResult result) async {
    if (!result.isSuccess) return;

    final effectiveMode = _resolveOutputMode(result.translatedText);

    await _speakText(
      result.translatedText,
      effectiveMode == TranslationMode.englishToNepali ? 'ne-NP' : 'en-US',
    );
  }

  TranslationMode _resolveOutputMode(String output) {
    if (RomanNepaliNormalizer.isDevanagari(output)) {
      return TranslationMode.englishToNepali;
    }

    return TranslationMode.nepaliToEnglish;
  }

  Future<void> _speakText(String text, String lang) async {
    if (text.trim().isEmpty) return;

    if (lang == 'ne-NP' && !_nepaliTtsAvailable) {
      _showSnack(
        'Nepali voice not installed. Go to Settings -> Language -> Text-to-Speech to install it.',
      );
      return;
    }

    await _tts.stop();
    await _tts.setLanguage(lang);
    await _tts.speak(text);
  }

  Future<void> _copy(String text) async {
    if (text.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied');
  }

  Future<void> _share(String text) async {
    if (text.trim().isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _loadCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _categoryEntries = _service.entriesByCategory(category);
    });
  }

  void _refreshHistory() {
    setState(() => _history = _service.history);
  }

  Future<void> _clearHistory() async {
    await _service.clearHistory();
    _refreshHistory();
    _showSnack('History cleared');
  }

  void _scrollConversationToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tourism Translator')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Translation module failed to load:\n\n$_error'),
          ),
        ),
      );
    }

    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourism Translator'),
        actions: [
          IconButton(
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear history',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.translate), text: 'Text'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Conversation'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Phrasebook'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildModeBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTextTab(),
                _buildConversationTab(),
                _buildPhrasebookTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: TranslationMode.values.map((mode) {
            final selected = _mode == mode;
            final icon = mode == TranslationMode.englishToNepali
                ? Icons.arrow_forward_rounded
                : mode == TranslationMode.nepaliToEnglish
                    ? Icons.arrow_back_rounded
                    : Icons.swap_horiz_rounded;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _mode = mode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        mode.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    final result = _currentResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_alt_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Translate common tourism phrases offline using a phrasebook, Roman Nepali support, and smart intent matching. Online translation is used only when no good offline match is found.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _inputController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Enter English, नेपाली, or Roman Nepali',
            hintText: 'Example: malai paani chaiyo',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => _listenInto(_inputController),
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _translateText,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.translate),
          label: Text(_loading ? 'Translating...' : 'Translate'),
        ),
        const SizedBox(height: 18),
        if (result != null) _buildResultCard(result),
      ],
    );
  }

  Widget _buildResultCard(TranslationResult result) {
    final output = result.isSuccess
        ? result.translatedText
        : result.errorMessage ?? 'No suitable translation found.';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.mountainTeal.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.mountainTeal.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _TranslationSourceChip(result: result),
              ),
              Chip(
                label: Text(result.confidencePercent),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (result.intent != null) ...[
            const SizedBox(height: 6),
            Text(
              'Intent: ${result.intent}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          SelectableText(
            output,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (result.romanized != null && result.romanized!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.romanized!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (result.alternatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Alternatives',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.alternatives.take(4).map((alternative) {
                return InputChip(
                  label: Text(alternative),
                  onPressed: () => _copy(alternative),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copy(output),
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              OutlinedButton.icon(
                onPressed: () => _speakResult(result),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Speak'),
              ),
              OutlinedButton.icon(
                onPressed: () => _share(output),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ],
          ),
          if (result.intent != null) _buildRelatedPhrases(result.intent!),
        ],
      ),
    );
  }

  Widget _buildRelatedPhrases(String intentId) {
    final categories = TranslationIntentModel.intentToPhrasebookCategories(
      intentId,
    );

    if (categories.isEmpty) return const SizedBox.shrink();

    final entries = categories
        .expand((category) => _service.entriesByCategory(category))
        .take(4)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map((entry) {
          return ActionChip(
            label: Text(entry.english),
            onPressed: () {
              _inputController.text = entry.english;
              _tabController.animateTo(0);
              _translateText();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConversationTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Start a conversation between a tourist and a local host.',
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];

                    return Align(
                      alignment: message.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.text),
                            if (message.result != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${message.result!.strategyLabel} · ${message.result!.confidencePercent}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _listenInto(_conversationController),
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
                Expanded(
                  child: TextField(
                    controller: _conversationController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendConversationMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _sendConversationMessage,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhrasebookTab() {
    final entries = _searchQuery.isEmpty
        ? _categoryEntries
        : _service.allEntries
            .where(
              (entry) =>
                  entry.english.toLowerCase().contains(_searchQuery) ||
                  entry.nepali.contains(_searchQuery) ||
                  entry.romanized.any(
                    (romanized) =>
                        romanized.toLowerCase().contains(_searchQuery),
                  ),
            )
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _phrasebookSearch,
            decoration: const InputDecoration(
              hintText: 'Search phrases...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (query) {
              setState(() {
                _searchQuery = query.toLowerCase().trim();
              });
            },
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: PhrasebookCategory.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = PhrasebookCategory.all[index];

              return ChoiceChip(
                selected: _selectedCategory == category.id,
                label: Text('${category.emoji} ${category.label}'),
                onSelected: (_) => _loadCategory(category.id),
              );
            },
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No phrases in this category.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];

                    return Card(
                      child: ListTile(
                        title: Text(entry.english),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.nepali,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (entry.romanized.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  entry.romanized.first,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () => _speakText(entry.nepali, 'ne-NP'),
                        ),
                        onTap: () {
                          _inputController.text = entry.english;
                          _tabController.animateTo(0);
                          _translateText();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('No translation history yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _history[index];

        return Card(
          child: ListTile(
            title: Text(entry.inputText),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.outputText),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.mode.label} · ${_strategyLabel(entry.strategy)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.replay),
              onPressed: () {
                _inputController.text = entry.inputText;
                _mode = entry.mode;
                _tabController.animateTo(0);
                setState(() {});
              },
            ),
          ),
        );
      },
    );
  }

  String _strategyLabel(TranslationStrategy strategy) {
    switch (strategy) {
      case TranslationStrategy.phrasebookMatch:
        return 'Offline phrasebook';
      case TranslationStrategy.intentModel:
        return 'Offline model';
      case TranslationStrategy.onlineFallback:
        return 'Online translation';
      case TranslationStrategy.noResult:
        return 'No match';
    }
  }
}

class _ConversationMessage {
  final String text;
  final bool isUser;
  final TranslationResult? result;

  const _ConversationMessage({
    required this.text,
    required this.isUser,
    this.result,
  });
}

class _TranslationSourceChip extends StatelessWidget {
  final TranslationResult result;

  const _TranslationSourceChip({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNoMatch = result.strategy == TranslationStrategy.noResult;
    final color = isNoMatch
        ? colorScheme.error
        : result.isOffline
            ? colorScheme.tertiary
            : colorScheme.primary;
    final icon = isNoMatch
        ? Icons.error_outline_rounded
        : result.isOffline
            ? Icons.offline_bolt_rounded
            : Icons.cloud_done_rounded;
    final label = isNoMatch
        ? 'No match'
        : result.isOffline
            ? result.strategyLabel
            : 'Online translation';

    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: color.withValues(alpha: 0.24)),
      ),
    );
  }
}
