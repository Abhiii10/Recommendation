import 'package:flutter/material.dart';

/// Chat message model for the tourism chatbot.
enum MessageSender { user, bot }

enum ChatResponseMode { onlineLlm, offlineFallback }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// Optional: the detected intent, shown in debug mode only
  final String? detectedIntent;

  /// Optional: confidence score [0,1]
  final double? confidence;

  final ChatResponseMode? responseMode;
  final bool isEmergency;
  final String? responseSourceLabel;
  final String? detectedLanguageLabel;
  final List<String> advancedSuggestions;
  final Map<String, dynamic> metadata;

  const ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.detectedIntent,
    this.confidence,
    this.responseMode,
    this.isEmergency = false,
    this.responseSourceLabel,
    this.detectedLanguageLabel,
    this.advancedSuggestions = const [],
    this.metadata = const {},
  });

  bool get isUser => sender == MessageSender.user;
  bool get isBot => sender == MessageSender.bot;

  static ChatMessage fromUser(String text) => ChatMessage(
        text: text,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      );

  static ChatMessage fromBot(
    String text, {
    String? detectedIntent,
    double? confidence,
    ChatResponseMode? responseMode,
    bool isEmergency = false,
    String? responseSourceLabel,
    String? detectedLanguageLabel,
    List<String> advancedSuggestions = const [],
    Map<String, dynamic> metadata = const {},
  }) =>
      ChatMessage(
        text: text,
        sender: MessageSender.bot,
        timestamp: DateTime.now(),
        detectedIntent: detectedIntent,
        confidence: confidence,
        responseMode: responseMode,
        isEmergency: isEmergency,
        responseSourceLabel: responseSourceLabel,
        detectedLanguageLabel: detectedLanguageLabel,
        advancedSuggestions: advancedSuggestions,
        metadata: metadata,
      );
}

/// Suggested quick-reply chip shown below the input bar
class QuickSuggestion {
  final String text;
  final String message;
  final IconData icon;

  const QuickSuggestion(
    this.text, {
    required this.icon,
    String? message,
  }) : message = message ?? text;

  String get label => text;
}
