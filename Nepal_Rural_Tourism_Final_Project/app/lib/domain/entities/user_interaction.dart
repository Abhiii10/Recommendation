enum InteractionType {
  click,
  bookmark,
  dwell,
}

class UserInteraction {
  final String destinationId;
  final InteractionType type;
  final List<String> categories;
  final List<String> tags;
  final DateTime timestamp;

  const UserInteraction({
    required this.destinationId,
    required this.type,
    required this.categories,
    required this.tags,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'destination_id': destinationId,
        'type': type.name,
        'categories': categories,
        'tags': tags,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory UserInteraction.fromJson(Map<String, dynamic> json) {
    return UserInteraction(
      destinationId: json['destination_id'] as String,
      type: InteractionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InteractionType.click,
      ),
      categories: List<String>.from(json['categories'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}