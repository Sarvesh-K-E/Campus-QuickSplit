class AppAction {
  final String id;
  final String title;
  final String subtitle;
  final String actionType;
  final DateTime timestamp;

  AppAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionType,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'action_type': actionType,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AppAction.fromMap(Map<String, dynamic> map) {
    return AppAction(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'] ?? '',
      actionType: map['action_type'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
