import '../models/message_attachment.dart';

enum AgentToolRisk { readOnly, proposal, privileged }

extension AgentToolRiskKey on AgentToolRisk {
  String get key => switch (this) {
        AgentToolRisk.readOnly => 'read_only',
        AgentToolRisk.proposal => 'proposal',
        AgentToolRisk.privileged => 'privileged',
      };
}

enum AgentToolOrigin { userTurn, autonomous }

extension AgentToolOriginKey on AgentToolOrigin {
  String get key => switch (this) {
        AgentToolOrigin.userTurn => 'user_turn',
        AgentToolOrigin.autonomous => 'autonomous',
      };
}

enum AgentToolStatus {
  requested,
  running,
  succeeded,
  noResult,
  failed,
  blocked,
  stopped,
}

extension AgentToolStatusKey on AgentToolStatus {
  String get key => switch (this) {
        AgentToolStatus.requested => 'requested',
        AgentToolStatus.running => 'running',
        AgentToolStatus.succeeded => 'succeeded',
        AgentToolStatus.noResult => 'no_result',
        AgentToolStatus.failed => 'failed',
        AgentToolStatus.blocked => 'blocked',
        AgentToolStatus.stopped => 'stopped',
      };
}

AgentToolStatus agentToolStatusFromKey(String value) => switch (value) {
      'succeeded' => AgentToolStatus.succeeded,
      'no_result' => AgentToolStatus.noResult,
      'failed' => AgentToolStatus.failed,
      'blocked' => AgentToolStatus.blocked,
      'stopped' => AgentToolStatus.stopped,
      'running' => AgentToolStatus.running,
      _ => AgentToolStatus.requested,
    };

class AgentToolOutcomeRecord {
  const AgentToolOutcomeRecord({
    required this.id,
    required this.jobId,
    required this.assistantMessageId,
    required this.toolId,
    required this.status,
    required this.resultCount,
    required this.startedAt,
    required this.finishedAt,
    required this.sourceDeviceLabel,
    this.displayText = '',
  });

  final String id;
  final String jobId;
  final String assistantMessageId;
  final String toolId;
  final AgentToolStatus status;
  final int resultCount;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String sourceDeviceLabel;
  /// User-facing tool outcome, stored separately from diagnostic metadata.
  final String displayText;

  Duration get duration => finishedAt.difference(startedAt);

  factory AgentToolOutcomeRecord.fromDb(Map<String, Object?> row) =>
      AgentToolOutcomeRecord(
        id: row['id'] as String? ?? '',
        jobId: row['job_id'] as String? ?? '',
        assistantMessageId: row['assistant_message_id'] as String? ?? '',
        toolId: row['tool_id'] as String? ?? '',
        status: agentToolStatusFromKey(row['status'] as String? ?? ''),
        resultCount: (row['result_count'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['started_at'] as num?)?.toInt() ?? 0,
        ),
        finishedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['finished_at'] as num?)?.toInt() ?? 0,
        ),
        sourceDeviceLabel: row['source_device_label'] as String? ?? '',
        displayText: row['display_text'] as String? ?? '',
      );
}

class AgentToolDefinition {
  const AgentToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.risk,
    required this.executable,
    required this.userTurnAvailable,
    required this.autonomousAvailable,
  });

  final String id;
  final String title;
  final String description;
  final AgentToolRisk risk;
  final bool executable;
  final bool userTurnAvailable;
  final bool autonomousAvailable;
}

class AgentToolCall {
  const AgentToolCall({
    required this.toolId,
    required this.arguments,
    required this.reasonTag,
  });

  final String toolId;
  final Map<String, String> arguments;
  final String reasonTag;
}

class AgentToolPlan {
  const AgentToolPlan({this.calls = const []});

  final List<AgentToolCall> calls;
  bool get isEmpty => calls.isEmpty;
}

class AgentToolResult {
  const AgentToolResult({
    required this.toolId,
    required this.status,
    required this.displayText,
    required this.promptData,
    this.resultCount = 0,
    this.errorCode = '',
    this.attachments = const <MessageAttachment>[],
    this.mediaUsageKeys = const <String>[],
    this.terminalCommitPending = false,
    this.continuationRecommended = false,
    this.submittedArguments = const <String, Object?>{},
  });

  final String toolId;
  final AgentToolStatus status;
  final String displayText;
  final String promptData;
  final int resultCount;
  final String errorCode;
  /// Files prepared by a real media tool for the current assistant message.
  /// They become visible only if the generation job commits atomically.
  final List<MessageAttachment> attachments;
  /// Opaque local repetition-guard keys recorded only after that commit wins.
  final List<String> mediaUsageKeys;
  /// A media operation whose terminal success exists only if the enclosing
  /// assistant message and its attachment win the durable commit.
  final bool terminalCommitPending;
  /// The executor resolved a high-confidence state saying the bounded task
  /// still belongs to the companion. This may keep the current planning loop
  /// open; it never expands the global round/call budget.
  final bool continuationRecommended;
  /// Sanitized arguments that actually crossed the executor boundary. These
  /// are final-expression grounding facts, never permission to replay a call.
  final Map<String, Object?> submittedArguments;

  bool get succeeded => status == AgentToolStatus.succeeded;
}

class AgentToolActivity {
  const AgentToolActivity({
    required this.toolId,
    required this.status,
    required this.text,
  });

  final String toolId;
  final AgentToolStatus status;
  final String text;

  bool get active =>
      status == AgentToolStatus.requested || status == AgentToolStatus.running;
}
