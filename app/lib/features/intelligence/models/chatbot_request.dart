class ChatbotRequest {
  final String text;
  final String conversationId;
  final bool allowOnlineEnhancement;
  final String? preferredLanguageCode;

  const ChatbotRequest({
    required this.text,
    required this.conversationId,
    this.allowOnlineEnhancement = true,
    this.preferredLanguageCode,
  });
}
