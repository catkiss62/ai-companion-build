class ProactiveFeedback {
  const ProactiveFeedback({
    required this.id,
    required this.proactiveMessageId,
    required this.sentAt,
    required this.createdAt,
    this.thoughtId,
    this.topicKey = '',
    this.threadId,
    this.intentKind = '',
    this.deliveryStyle = '',
    this.userResponseMessageId,
    this.responseLatencySeconds,
    this.responseBucket = 'pending',
    this.userTextLength = 0,
    this.responseQuality,
    this.outcome = 'pending',
    this.outcomeScore,
    this.processedAt,
    this.contextHourBucket = '',
    this.contextActivity = 'unknown',
    this.contextBusy = 0,
    this.timingFit,
    this.topicFit,
  });

  final String id;
  final String proactiveMessageId;
  final String? thoughtId;
  final String topicKey;
  final String? threadId;
  final String intentKind;
  final String deliveryStyle;
  final DateTime sentAt;
  final String? userResponseMessageId;
  final int? responseLatencySeconds;
  final String responseBucket;
  final int userTextLength;
  final double? responseQuality;
  final String outcome;
  final double? outcomeScore;
  final DateTime? processedAt;
  final DateTime createdAt;
  final String contextHourBucket;
  final String contextActivity;
  final double contextBusy;
  final double? timingFit;
  final double? topicFit;

  bool get responded => userResponseMessageId != null;
  bool get outcomeProcessed => processedAt != null;

  factory ProactiveFeedback.fromDb(Map<String, Object?> row) => ProactiveFeedback(
        id: row['id'] as String,
        proactiveMessageId: row['proactive_message_id'] as String,
        thoughtId: row['thought_id'] as String?,
        topicKey: row['topic_key'] as String? ?? '',
        threadId: row['thread_id'] as String?,
        intentKind: row['intent_kind'] as String? ?? '',
        deliveryStyle: row['delivery_style'] as String? ?? '',
        sentAt: DateTime.fromMillisecondsSinceEpoch(row['sent_at'] as int),
        userResponseMessageId: row['user_response_message_id'] as String?,
        responseLatencySeconds: row['response_latency_seconds'] as int?,
        responseBucket: row['response_bucket'] as String? ?? 'pending',
        userTextLength: row['user_text_length'] as int? ?? 0,
        responseQuality: (row['response_quality'] as num?)?.toDouble(),
        outcome: row['outcome'] as String? ?? 'pending',
        outcomeScore: (row['outcome_score'] as num?)?.toDouble(),
        processedAt: row['processed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['processed_at'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        contextHourBucket: row['context_hour_bucket'] as String? ?? '',
        contextActivity: row['context_activity'] as String? ?? 'unknown',
        contextBusy: ((row['context_busy'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble(),
        timingFit: (row['timing_fit'] as num?)?.toDouble(),
        topicFit: (row['topic_fit'] as num?)?.toDouble(),
      );
}
