class PostTurnJob {
  const PostTurnJob({
    required this.id,
    required this.userMessageId,
    required this.assistantMessageId,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.lastError = '',
    this.runToken = '',
    this.resultJson = '',
    this.startedAt,
    this.heartbeatAt,
    this.nextRetryAt,
    this.modelCompletedAt,
    this.desireAppliedAt,
    this.specialStyleTrialId = '',
    this.specialStyleKey = '',
  });

  final String id;
  final String userMessageId;
  final String assistantMessageId;
  final String status;
  final int attempts;
  final String lastError;
  final String runToken;
  final String resultJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? heartbeatAt;
  final DateTime? nextRetryAt;
  final DateTime? modelCompletedAt;
  final DateTime? desireAppliedAt;
  final String specialStyleTrialId;
  final String specialStyleKey;

  bool get isRunning => status == 'running' && runToken.isNotEmpty;
  bool get hasProposal => resultJson.trim().isNotEmpty;

  factory PostTurnJob.fromDb(Map<String, Object?> row) => PostTurnJob(
        id: row['id'] as String,
        userMessageId: row['user_message_id'] as String,
        assistantMessageId: row['assistant_message_id'] as String,
        status: row['status'] as String? ?? 'pending',
        attempts: (row['attempts'] as num?)?.toInt() ?? 0,
        lastError: row['last_error'] as String? ?? '',
        runToken: row['run_token'] as String? ?? '',
        resultJson: row['result_json'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        startedAt: row['started_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        heartbeatAt: row['heartbeat_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['heartbeat_at'] as int),
        nextRetryAt: row['next_retry_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['next_retry_at'] as int),
        modelCompletedAt: row['model_completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['model_completed_at'] as int),
        desireAppliedAt: row['desire_applied_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['desire_applied_at'] as int),
        specialStyleTrialId: row['special_style_trial_id'] as String? ?? '',
        specialStyleKey: row['special_style_key'] as String? ?? '',
      );
}
