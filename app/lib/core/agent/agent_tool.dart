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

enum AgentToolStatus { requested, running, succeeded, noResult, failed, blocked }

extension AgentToolStatusKey on AgentToolStatus {
  String get key => switch (this) {
        AgentToolStatus.requested => 'requested',
        AgentToolStatus.running => 'running',
        AgentToolStatus.succeeded => 'succeeded',
        AgentToolStatus.noResult => 'no_result',
        AgentToolStatus.failed => 'failed',
        AgentToolStatus.blocked => 'blocked',
      };
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
  });

  final String toolId;
  final AgentToolStatus status;
  final String displayText;
  final String promptData;
  final int resultCount;
  final String errorCode;

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
