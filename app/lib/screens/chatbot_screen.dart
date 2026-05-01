import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/chat_message.dart';
import '../models/destination.dart';
import '../services/chatbot_service.dart';
import '../services/llm_chat_api_service.dart';
import '../services/translation_service.dart';

class ChatbotScreen extends StatefulWidget {
  final List<Destination> destinations;

  const ChatbotScreen({
    super.key,
    required this.destinations,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final LlmChatApiService _llmService = const LlmChatApiService();

  late final ChatbotService _service;

  final List<ChatMessage> _messages = [];
  List<QuickSuggestion> _suggestions = [];

  bool _loading = true;
  bool _botTyping = false;
  bool _ttsPlaying = false;
  String? _ttsSpeaking;

  @override
  void initState() {
    super.initState();
    _service = ChatbotService(destinations: widget.destinations);
    unawaited(_initTts());
    unawaited(_init());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      if (!mounted) return;

      setState(() {
        _ttsPlaying = false;
        _ttsSpeaking = null;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;

      setState(() {
        _ttsPlaying = false;
        _ttsSpeaking = null;
      });
    });

    _tts.setErrorHandler((_) {
      if (!mounted) return;

      setState(() {
        _ttsPlaying = false;
        _ttsSpeaking = null;
      });
    });
  }

  Future<void> _init() async {
    await _service.init();

    if (!mounted) return;

    setState(() {
      _messages.add(_service.greetingMessage());
      _suggestions = _service.initialSuggestions();
      _loading = false;
    });

    _scrollToBottom();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty || _botTyping || _loading) {
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(ChatMessage.fromUser(trimmed));
      _suggestions = [];
      _botTyping = true;
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final localResponse = _service.respond(trimmed);

    ChatMessage response = localResponse;

    try {
      final geminiAnswer = await _llmService.ask(trimmed);

      response = ChatMessage.fromBot(
        geminiAnswer,
        detectedIntent: localResponse.detectedIntent,
        confidence: localResponse.confidence,
      );
    } catch (_) {
      response = localResponse;
    }

    if (!mounted) return;

    setState(() {
      _messages.add(response);
      _suggestions = _service.suggestionsForIntent(
        response.detectedIntent ?? 'fallback',
      );
      _botTyping = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _speak(String text) async {
    if (_ttsPlaying && _ttsSpeaking == text) {
      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _ttsPlaying = false;
        _ttsSpeaking = null;
      });

      return;
    }

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _ttsPlaying = true;
      _ttsSpeaking = text;
    });

    await _tts.speak(text);
  }

  Future<void> _translate(ChatMessage message) async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Translating to Nepali…')),
            ],
          ),
        );
      },
    );

    try {
      final translated = await TranslationService.translate(
        text: message.text,
        englishToNepali: true,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Nepali Translation'),
            content: SelectableText(translated.text),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation failed — check your connection.'),
        ),
      );
    }
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(_service.greetingMessage());
      _suggestions = _service.initialSuggestions();
      _botTyping = false;
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tourism Assistant',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Gemini Flash · Offline fallback',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    itemCount: _messages.length + (_botTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_botTyping && index == _messages.length) {
                        return _TypingIndicator(colorScheme: colorScheme);
                      }

                      return _buildBubble(
                        message: _messages[index],
                        colorScheme: colorScheme,
                        theme: theme,
                      );
                    },
                  ),
          ),
          if (_suggestions.isNotEmpty && !_botTyping) ...[
            _buildSuggestions(colorScheme),
          ],
          _buildInputBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  suggestion.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor:
                    colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                onPressed: () => _send(suggestion.message),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              enabled: !_loading && !_botTyping,
              decoration: InputDecoration(
                hintText: 'Ask about destinations, trekking, food…',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
              backgroundColor: colorScheme.primary,
            ),
            onPressed: (_loading || _botTyping)
                ? null
                : () => _send(_controller.text),
            child: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required ChatMessage message,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color:
                          isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: (_ttsPlaying && _ttsSpeaking == message.text)
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          label: (_ttsPlaying && _ttsSpeaking == message.text)
                              ? 'Stop'
                              : 'Listen',
                          color: colorScheme.primary,
                          onTap: () => _speak(message.text),
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.translate_rounded,
                          label: 'Nepali',
                          color: colorScheme.secondary,
                          onTap: () => _translate(message),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;

  const _TypingIndicator({
    required this.colorScheme,
  });

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value - index * 0.15).clamp(0.0, 1.0);
    final wave = phase < 0.5 ? 2 * phase : 2 * (1 - phase);
    return 0.3 + 0.7 * (0.5 + 0.5 * wave);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.travel_explore_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(
                          alpha: _dotOpacity(index),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}