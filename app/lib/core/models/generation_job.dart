class GenerationJob {
  const GenerationJob({
    required this.id,
    required this.userMessageId,
    required this.assistantMessageId,
    required this.status,
    required this.attempts,
    required this.model,
    required this.reasoningEffort,
    required this.thinking,
    required this.partialReasoning,
    required this.partialContent,
    required this.runToken,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
    this.startedAt,
    this.completedAt,
    this.lastCheckpointAt,
    this.nextRetryAt,
    this.lastError = '',
    this.resumeReason = '',
  });

  final String id;
  final String userMessageId;
  final String assistantMessageId;
  final String status;
  final int attempts;
  final String model;
  final String reasoningEffort;
  final bool thinking;
  final String partialReasoning;
  final String partialContent;
  final String runToken;
  final String? deviceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastCheckpointAt;
  final DateTime? nextRetryAt;
  final String lastError;
  final String resumeReason;

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'cancelled';

  bool get isBlocking => !isTerminal;

  factory GenerationJob.fromDb(Map<String, Object?> row) => GenerationJob(
        id: row['id'] as String,
        userMessageId: row['user_message_id'] as String,
        assistantMessageId: row['assistant_message_id'] as String,
        status: row['status'] as String? ?? 'pending',
        attempts: row['attempts'] as int? ?? 0,
        model: row['model'] as String? ?? 'deepseek-v4-pro',
        reasoningEffort: row['reasoning_effort'] as String? ?? 'high',
        thinking: (row['thinking'] as int? ?? 1) != 0,
        partialReasoning: row['partial_reasoning'] as String? ?? '',
        partialContent: row['partial_content'] as String? ?? '',
        runToken: row['run_token'] as String? ?? '',
        deviceId: row['device_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        startedAt: _date(row['started_at']),
        completedAt: _date(row['completed_at']),
        lastCheckpointAt: _date(row['last_checkpoint_at']),
        nextRetryAt: _date(row['next_retry_at']),
        lastError: row['last_error'] as String? ?? '',
        resumeReason: row['resume_reason'] as String? ?? '',
      );

  static DateTime? _date(Object? value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}
