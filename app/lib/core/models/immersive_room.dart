class ImmersiveRoom {
  const ImmersiveRoom({
    required this.id,
    required this.title,
    required this.status,
    required this.novelRules,
    required this.entryContext,
    required this.rollingSummary,
    required this.sceneLedger,
    required this.sharedMemorySummary,
    required this.summarizedMessageCount,
    required this.nsfwActive,
    required this.nsfwManualOverride,
    required this.nsfwRouteSource,
    this.specialStyleKey = '',
    this.specialStyleBinding = 'inherit',
    required this.createdAt,
    required this.updatedAt,
    this.endedAt,
  });

  final String id;
  final String title;
  final String status;
  final String novelRules;
  final String entryContext;
  final String rollingSummary;
  final String sceneLedger;
  final String sharedMemorySummary;
  final int summarizedMessageCount;
  final bool nsfwActive;
  final String nsfwManualOverride;
  final String nsfwRouteSource;
  final String specialStyleKey;
  final String specialStyleBinding;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? endedAt;

  bool get isEnded => status == 'ended';
  bool get isPaused => status == 'paused';

  factory ImmersiveRoom.fromDb(Map<String, Object?> row) => ImmersiveRoom(
        id: row['id'] as String,
        title: row['title'] as String? ?? '未命名房间',
        status: row['status'] as String? ?? 'paused',
        novelRules: row['novel_rules'] as String? ?? '',
        entryContext: row['entry_context'] as String? ?? '',
        rollingSummary: row['rolling_summary'] as String? ?? '',
        sceneLedger: row['scene_ledger'] as String? ?? '',
        sharedMemorySummary: row['shared_memory_summary'] as String? ?? '',
        summarizedMessageCount:
            (row['summarized_message_count'] as num?)?.toInt() ?? 0,
        nsfwActive: row['nsfw_active'] == 1,
        nsfwManualOverride: row['nsfw_manual_override'] as String? ?? '',
        nsfwRouteSource: row['nsfw_route_source'] as String? ?? 'initial',
        specialStyleKey: row['special_style_key'] as String? ?? '',
        specialStyleBinding: row['special_style_binding'] as String? ?? 'inherit',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as num).toInt(),
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['updated_at'] as num).toInt(),
        ),
        endedAt: row['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (row['ended_at'] as num).toInt(),
              ),
      );
}

class ImmersiveMessage {
  const ImmersiveMessage({
    required this.id,
    required this.roomId,
    required this.role,
    required this.content,
    required this.reasoningContent,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String role;
  final String content;
  final String reasoningContent;
  final DateTime createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ImmersiveMessage.fromDb(Map<String, Object?> row) =>
      ImmersiveMessage(
        id: row['id'] as String,
        roomId: row['room_id'] as String,
        role: row['role'] as String,
        content: row['content'] as String? ?? '',
        reasoningContent: row['reasoning_content'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as num).toInt(),
        ),
      );
}
