import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/destination.dart';
import '../services/chatbot_service.dart';
import '../services/llm_chat_api_service.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import 'translation_screen.dart';

class ChatbotScreen extends StatefulWidget {
  final List<Destination> destinations;
  final VoidCallback? onOpenAbout;

  const ChatbotScreen({
    super.key,
    required this.destinations,
    this.onOpenAbout,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final LlmChatApiService _llmService = LlmChatApiService();

  late final ChatbotService _service;

  final List<ChatMessage> _messages = [];
  List<QuickSuggestion> _suggestions = [];

  bool _loading = true;
  bool _botTyping = false;
  bool _ttsPlaying = false;
  bool? _llmOnline;
  String? _ttsSpeaking;

  @override
  void initState() {
    super.initState();
    _service = ChatbotService(destinations: widget.destinations);
    unawaited(_initTts());
    unawaited(_init());
    unawaited(_refreshLlmStatus());
  }

  @override
  void dispose() {
    _llmService.clearHistory();
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

    final l10n = AppLocalizations.of(context);

    setState(() {
      _messages.add(
        ChatMessage.fromBot(
          l10n.chatGreeting,
          detectedIntent: 'greeting',
          confidence: 1.0,
        ),
      );
      _suggestions = _service.initialSuggestions();
      _loading = false;
    });

    _scrollToBottom();
  }

  Future<void> _send(String text) async {
    HapticFeedback.lightImpact();
    final trimmed = text.trim();

    if (trimmed.isEmpty || _botTyping || _loading) {
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();

    final likelyEmergency = _service.isEmergencyLike(trimmed);

    setState(() {
      _messages.add(ChatMessage.fromUser(trimmed));
      _suggestions = [];
      _botTyping = !likelyEmergency;
    });

    _scrollToBottom();

    if (!likelyEmergency) {
      await Future.delayed(const Duration(milliseconds: 320));
    }

    if (!mounted) return;

    final response = await _service.respondAdvanced(
      trimmed,
      allowOnlineEnhancement: !likelyEmergency,
    );

    if (!mounted) return;

    setState(() {
      _messages.add(response);
      _suggestions = _service.suggestionsFromAdvanced(response);
      _botTyping = false;
      _llmOnline = response.responseMode == ChatResponseMode.onlineLlm
          ? true
          : _llmOnline == true
              ? true
              : false;
    });

    _scrollToBottom();
  }

  Future<void> _refreshLlmStatus() async {
    final online = await _llmService.isHealthy();
    if (!mounted) return;
    _setLlmOnline(online);
  }

  void _setLlmOnline(bool online) {
    if (!mounted) return;
    setState(() {
      _llmOnline = online;
    });
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

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dial $number from your phone app.')),
      );
    }
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
      final translated = await TranslationService.instance.translate(
        input: message.text,
        mode: TranslationMode.englishToNepali,
        allowOnline: true,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Nepali Translation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  translated.isSuccess
                      ? translated.translatedText
                      : translated.errorMessage ?? 'Translation unavailable.',
                ),
                const SizedBox(height: 12),
                Text(
                  '${translated.strategyLabel} · ${translated.confidencePercent}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: translated.isSuccess
                    ? () {
                        _speak(translated.translatedText);
                      }
                    : null,
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Listen'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translation failed: $e'),
        ),
      );
    }
  }

  void _clearChat() {
    _llmService.clearHistory();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage.fromBot(
            l10n.chatGreeting,
            detectedIntent: 'greeting',
            confidence: 1.0,
          ),
        );
      _suggestions = _service.initialSuggestions();
      _botTyping = false;
    });

    _scrollToBottom();
  }

  void _openTranslation() {
    unawaited(HapticFeedback.selectionClick());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TranslationScreen(),
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    unawaited(HapticFeedback.selectionClick());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear chat?'),
          content: const Text(
            'This will remove the current conversation and reset the chatbot history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                unawaited(HapticFeedback.selectionClick());
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                unawaited(HapticFeedback.selectionClick());
                Navigator.of(context).pop(true);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;
    _clearChat();
  }

  Future<void> _showBotMessageMenu(
    ChatMessage message,
    Offset globalPosition,
  ) async {
    HapticFeedback.selectionClick();
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'read',
          child: Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 18),
              SizedBox(width: 8),
              Text('Read aloud'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 8),
              Text('Copy'),
            ],
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'read':
        await _speak(message.text);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied response')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
                Text(
                  l10n.chatTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _llmOnline == true
                      ? 'Online LLM ready'
                      : _llmOnline == false
                          ? 'Offline fallback active'
                          : 'Checking LLM status',
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
          if (widget.onOpenAbout != null)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'About',
              onPressed: widget.onOpenAbout,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear chat',
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Open translation',
        onPressed: _openTranslation,
        child: const Icon(Icons.translate_rounded),
      ),
      body: DecoratedBox(
        decoration: AppTheme.scaffoldDecorationFor(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildModeBanner(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      itemCount: _messages.length + (_botTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_botTyping && index == _messages.length) {
                          return const _TypingIndicator();
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
      ),
    );
  }

  Widget _buildModeBanner() {
    final cs = Theme.of(context).colorScheme;
    final isOnline = _llmOnline == true;
    final color = isOnline ? cs.primary : cs.tertiary;
    final icon =
        isOnline ? Icons.auto_awesome_rounded : Icons.offline_bolt_rounded;
    final label = isOnline ? 'AI Mode' : 'Offline Mode';
    final body = isOnline
        ? 'Online LLM responses are available.'
        : _llmOnline == null
            ? 'Checking whether the AI server is reachable.'
            : 'Offline fallback answers are active.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh status',
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(_refreshLlmStatus());
            },
            icon: Icon(Icons.refresh_rounded, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme colorScheme) {
    return _QuickSuggestions(
      suggestions: _suggestions,
      onSelected: (suggestion) => _send(suggestion.message),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
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
                hintText: l10n.chatPlaceholder,
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
          Semantics(
            label: 'Send message',
            button: true,
            child: FilledButton(
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
    final isEmergency = !isUser && message.isEmergency;
    final bubbleTextStyle = TextStyle(
      color: isUser
          ? colorScheme.onPrimary
          : isEmergency
              ? colorScheme.onErrorContainer
              : Colors.white,
      fontSize: 14,
      height: 1.5,
    );

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
                GestureDetector(
                  onLongPressStart: isUser
                      ? null
                      : (details) => _showBotMessageMenu(
                            message,
                            details.globalPosition,
                          ),
                  child: isEmergency
                      ? _EmergencyCard(
                          message: message,
                          onCall: _dial,
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? colorScheme.primary : null,
                            gradient: isUser
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      AppTheme.mountainTeal,
                                      AppTheme.highlandSage,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(isUser ? 18 : 4),
                              topRight: const Radius.circular(20),
                              bottomLeft: const Radius.circular(20),
                              bottomRight: Radius.circular(isUser ? 4 : 20),
                            ),
                          ),
                          child: isUser
                              ? Text(
                                  message.text,
                                  style: bubbleTextStyle,
                                )
                              : MarkdownBody(
                                  data: message.text,
                                  styleSheet: MarkdownStyleSheet(
                                    p: bubbleTextStyle,
                                    strong: bubbleTextStyle.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    listBullet: bubbleTextStyle,
                                    h1: bubbleTextStyle.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                    h2: bubbleTextStyle.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    h3: bubbleTextStyle.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                    blockSpacing: 8,
                                    listIndent: 16,
                                  ),
                                  shrinkWrap: true,
                                ),
                        ),
                ),
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ResponseSourceBadge(message: message),
                        if (message.detectedLanguageLabel != null)
                          _LanguageBadge(label: message.detectedLanguageLabel!),
                        if ((message.confidence ?? 1) < 0.70)
                          _ConfidenceIndicator(
                            confidence: message.confidence ?? 0,
                          ),
                        if (!message.isEmergency)
                          _ActionButton(
                            icon: Icons.translate_rounded,
                            label: 'Nepali',
                            color: colorScheme.secondary,
                            onTap: () => _translate(message),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isUser ? 0 : 2,
                    right: isUser ? 2 : 0,
                  ),
                  child: Text(
                    _relativeTime(message.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
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

  String _relativeTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }

    return '${difference.inDays}d ago';
  }
}

class _QuickSuggestions extends StatefulWidget {
  final List<QuickSuggestion> suggestions;
  final ValueChanged<QuickSuggestion> onSelected;

  const _QuickSuggestions({
    required this.suggestions,
    required this.onSelected,
  });

  @override
  State<_QuickSuggestions> createState() => _QuickSuggestionsState();
}

class _QuickSuggestionsState extends State<_QuickSuggestions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: double.infinity,
          color: cs.surface.withValues(alpha: 0.86),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.suggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(suggestion.icon, size: 14),
                    label: Text(suggestion.text),
                    onPressed: () {
                      unawaited(HapticFeedback.selectionClick());
                      widget.onSelected(suggestion);
                    },
                    backgroundColor: cs.primaryContainer.withValues(alpha: 0.7),
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponseSourceBadge extends StatelessWidget {
  final ChatMessage message;

  const _ResponseSourceBadge({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = message.responseMode == ChatResponseMode.onlineLlm;
    final isEmergency = message.isEmergency;
    final color = isOnline ? colorScheme.primary : colorScheme.tertiary;
    final effectiveColor = isEmergency ? colorScheme.error : color;
    final label = message.responseSourceLabel ??
        (isOnline ? 'Online enhancement' : 'Offline knowledge base');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEmergency
                ? Icons.emergency_rounded
                : isOnline
                    ? Icons.cloud_done_rounded
                    : Icons.offline_bolt_rounded,
            size: 12,
            color: effectiveColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  final String label;

  const _LanguageBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceIndicator extends StatelessWidget {
  final double confidence;

  const _ConfidenceIndicator({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final value = confidence.clamp(0.0, 1.0);
    final color = value >= 0.80
        ? Colors.green
        : value >= 0.60
            ? Colors.orange
            : Theme.of(context).colorScheme.error;
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Confidence: ${(value * 100).round()}%',
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

class _EmergencyCard extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String> onCall;

  const _EmergencyCard({
    required this.message,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final contacts = (message.metadata['contacts'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: colorScheme.error, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_rounded, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergency protocol',
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MarkdownBody(
            data: message.text,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: colorScheme.onErrorContainer,
                height: 1.45,
              ),
              listBullet: TextStyle(color: colorScheme.onErrorContainer),
              strong: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            shrinkWrap: true,
          ),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: contacts.map((contact) {
                final number = contact['number']?.toString() ?? '';
                final name = contact['name']?.toString() ?? number;
                return ActionChip(
                  avatar: const Icon(Icons.call_rounded, size: 16),
                  label: Text('$name $number'),
                  onPressed: number.isEmpty ? null : () => onCall(number),
                  backgroundColor: colorScheme.surface,
                  labelStyle: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ],
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
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
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
  const _TypingIndicator();

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
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.mountainTeal, AppTheme.highlandSage],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(controller: _controller, offset: 0.0),
                const SizedBox(width: 5),
                _TypingDot(controller: _controller, offset: 0.33),
                const SizedBox(width: 5),
                _TypingDot(controller: _controller, offset: 0.66),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  final AnimationController controller;
  final double offset;

  const _TypingDot({
    required this.controller,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final value = sin((controller.value + offset) * pi).clamp(0.0, 1.0);
        return Opacity(
          opacity: 0.45 + (value * 0.55),
          child: Transform.scale(
            scale: 0.72 + (value * 0.42),
            child: const CircleAvatar(
              radius: 4,
              backgroundColor: Colors.white70,
            ),
          ),
        );
      },
    );
  }
}
