import 'package:flutter/material.dart';

/// Chat message model for the tourism chatbot.
enum MessageSender { user, bot }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// Optional: the detected intent, shown in debug mode only
  final String? detectedIntent;

  /// Optional: confidence score [0,1]
  final double? confidence;

  const ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.detectedIntent,
    this.confidence,
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
  }) =>
      ChatMessage(
        text: text,
        sender: MessageSender.bot,
        timestamp: DateTime.now(),
        detectedIntent: detectedIntent,
        confidence: confidence,
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
