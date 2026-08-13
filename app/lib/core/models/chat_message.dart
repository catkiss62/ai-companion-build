class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.reasoningContent = '',
    this.model,
    this.isProactive = false,
    this.proactiveIntent = '',
    this.proactiveDelivery = '',
    this.deviceId,
  });

  final String id;
  final String role;
  final String content;
  final String reasoningContent;
  final String? model;
  final DateTime createdAt;
  final bool isProactive;
  final String proactiveIntent;
  final String proactiveDelivery;
  final String? deviceId;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? content,
    String? reasoningContent,
    String? model,
    bool? isProactive,
    String? proactiveIntent,
    String? proactiveDelivery,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      model: model ?? this.model,
      createdAt: createdAt,
      isProactive: isProactive ?? this.isProactive,
      proactiveIntent: proactiveIntent ?? this.proactiveIntent,
      proactiveDelivery: proactiveDelivery ?? this.proactiveDelivery,
      deviceId: deviceId,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'role': role,
        'content': content,
        'reasoning_content': reasoningContent,
        'model': model,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_proactive': isProactive ? 1 : 0,
        'proactive_intent': proactiveIntent,
        'proactive_delivery': proactiveDelivery,
        'device_id': deviceId,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'reasoning_content': reasoningContent,
        'model': model,
        'created_at': createdAt.toIso8601String(),
        'is_proactive': isProactive,
        'proactive_intent': proactiveIntent,
        'proactive_delivery': proactiveDelivery,
        'device_id': deviceId,
      };

  factory ChatMessage.fromDb(Map<String, Object?> row) {
    return ChatMessage(
      id: row['id'] as String,
      role: row['role'] as String,
      content: (row['content'] as String?) ?? '',
      reasoningContent: (row['reasoning_content'] as String?) ?? '',
      model: row['model'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      isProactive: (row['is_proactive'] as int? ?? 0) == 1,
      proactiveIntent: row['proactive_intent'] as String? ?? '',
      proactiveDelivery: row['proactive_delivery'] as String? ?? '',
      deviceId: row['device_id'] as String?,
    );
  }
}
