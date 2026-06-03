import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/features/chatbot/domain/models/chat_message.dart';

class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen> {
  static bool _aiProviderNoticeShownThisSession = false;

  static const List<({String label, String code})> _languages = [
    (label: 'English', code: 'en'),
    (label: 'Nepali', code: 'ne'),
    (label: 'Hindi', code: 'hi'),
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  String _selectedLanguage = 'en';
  bool _isLoading = false;
  bool _showAiProviderNotice = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage.fromBot(
        'Namaste! 🙏 I can help you explore rural Nepal destinations even offline.\n'
        'Ask me about places, trekking, budget, season, transport, or homestays.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Uri _uri(String path) {
    return BackendConfig.uri(path);
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) {
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(ChatMessage.fromUser(trimmed));
      _messages.add(ChatMessage.fromBot('thinking...'));
      _isLoading = true;
    });
    _scrollToBottom();

    final answer = await _offlineChat(trimmed, _selectedLanguage);

    if (!mounted) {
      return;
    }

    setState(() {
      _messages[_messages.length - 1] = ChatMessage.fromBot(answer);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<String> _offlineChat(String question, String lang) async {
    try {
      final response = await http
          .post(
            _uri('/chat/offline'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question,
              'language': lang,
              'top_k': 5,
              'history': [],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (_isAiProviderConfigError(response.statusCode, response.body)) {
          _showAiProviderConfigBanner();
          return 'AI chat is in offline mode. Add GROQ_API_KEY or '
              'GEMINI_API_KEY to backend/.env and restart Docker for full '
              'AI responses.';
        }
        return 'Offline chat unavailable. Check your connection to the backend.';
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final answer = data['answer']?.toString().trim();
      return answer == null || answer.isEmpty
          ? 'Sorry, no answer available.'
          : answer;
    } on TimeoutException {
      return 'Request timed out. The backend may be starting up — try again.';
    } catch (_) {
      return 'Offline chat unavailable. Check your connection to the backend.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isAiProviderConfigError(int statusCode, String body) {
    final lower = body.toLowerCase();
    return statusCode == 503 ||
        lower.contains('no ai provider configured') ||
        lower.contains('groq_api_key') ||
        lower.contains('gemini_api_key') ||
        lower.contains('not configured');
  }

  void _showAiProviderConfigBanner() {
    if (_aiProviderNoticeShownThisSession || !mounted) return;
    _aiProviderNoticeShownThisSession = true;
    setState(() => _showAiProviderNotice = true);
  }

  void _dismissAiProviderConfigBanner() {
    setState(() => _showAiProviderNotice = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded),
            SizedBox(width: 8),
            Text('Offline Chat'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Language',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        items: _languages
                            .map(
                              (language) => DropdownMenuItem<String>(
                                value: language.code,
                                child: Text(language.label),
                              ),
                            )
                            .toList(),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(
                      Icons.offline_bolt_rounded,
                      size: 18,
                    ),
                    label: const Text('Offline mode'),
                    backgroundColor: Colors.orange.shade100,
                    side: BorderSide.none,
                  ),
                  if (_showAiProviderNotice) ...[
                    const SizedBox(height: 10),
                    _buildAiProviderNoticeBanner(),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            _InputBar(
              controller: _controller,
              isLoading: _isLoading,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiProviderNoticeBanner() {
    final color = Colors.orange.shade700;

    return Material(
      color: Colors.orange.shade900.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: color, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'AI chat is in offline mode. Add GROQ_API_KEY or '
                'GEMINI_API_KEY to backend/.env and restart Docker for '
                'full AI responses.',
                style: TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: _dismissAiProviderConfigBanner,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isUser ? Colors.white : Colors.grey.shade900,
            fontStyle: message.text == 'thinking...' ? FontStyle.italic : null,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Ask about Nepal tourism...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: isLoading ? null : onSend,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isLoading ? null : () => onSend(controller.text),
              icon: const Icon(Icons.send_rounded),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}
