import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/translation_service.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  bool _loading = false;
  bool _englishToNepali = true;
  String _output = '';

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _output = '';
    });

    final result = await TranslationService.translate(
      text: text,
      englishToNepali: _englishToNepali,
    );

    if (!mounted) return;

    setState(() {
      _output = result;
      _loading = false;
    });
  }

  Future<void> _speak() async {
    if (_output.trim().isEmpty) return;

    await _tts.stop();
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.setLanguage(_englishToNepali ? 'ne-NP' : 'en-US');
    await _tts.speak(_output);
  }

  void _swapDirection() {
    setState(() {
      _englishToNepali = !_englishToNepali;
      _output = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel = _englishToNepali ? 'English' : 'Nepali';
    final targetLabel = _englishToNepali ? 'Nepali' : 'English';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translation direction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _LangBox(label: sourceLabel),
                      ),
                      IconButton(
                        onPressed: _swapDirection,
                        icon: const Icon(Icons.swap_horiz),
                        tooltip: 'Swap languages',
                      ),
                      Expanded(
                        child: _LangBox(label: targetLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Enter text in $sourceLabel',
                      hintText: _englishToNepali
                          ? 'Example: Welcome to rural tourism in Nepal.'
                          : 'उदाहरण: नेपालमा ग्रामीण पर्यटनमा स्वागत छ।',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _translate,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate),
                      label: Text(_loading ? 'Translating...' : 'Translate'),
                    ),
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
                  Text(
                    'Translated output',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _output.isEmpty
                        ? 'Your translated text will appear here.'
                        : _output,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _output.isEmpty ? null : _speak,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Speak'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _output.isEmpty
                            ? null
                            : () {
                                _controller.text = _output;
                                _swapDirection();
                              },
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text('Reverse translate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}