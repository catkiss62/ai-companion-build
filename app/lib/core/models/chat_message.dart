import 'message_attachment.dart';
import 'chat_segment.dart';

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
    this.attachments = const <MessageAttachment>[],
    this.expectsReply = true,
    this.segments = const <ChatSegment>[],
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
  final List<MessageAttachment> attachments;
  final bool expectsReply;
  final List<ChatSegment> segments;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasAttachments => attachments.isNotEmpty;
  List<ChatSegment> get displaySegments => segments.isNotEmpty
      ? segments
      : isAssistant
          ? ChatSegmentCodec.parseAssistantText(content)
          : const <ChatSegment>[];

  String get promptContent {
    if (!hasAttachments) return content;
    final caption = content.trim();
    final observations = attachments.where((item) => item.isImage).map((item) {
      if (item.visionCompleted) {
        return '[用户发送了一张图片；视觉模型观察：${item.visionSummary.trim()}]';
      }
      if (item.visionFailed) {
        return '[用户发送了一张图片；视觉识别失败，未取得图片内容]';
      }
      return '[用户发送了一张图片；视觉识别尚未完成]';
    }).toList(growable: false);
    final label = observations.join('\n');
    return caption.isEmpty ? label : '$label\n附言：$caption';
  }

  ChatMessage copyWith({
    String? content,
    String? reasoningContent,
    String? model,
    bool? isProactive,
    String? proactiveIntent,
    String? proactiveDelivery,
    List<MessageAttachment>? attachments,
    bool? expectsReply,
    List<ChatSegment>? segments,
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
      attachments: attachments ?? this.attachments,
      expectsReply: expectsReply ?? this.expectsReply,
      segments: segments ?? this.segments,
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
        'expects_reply': expectsReply ? 1 : 0,
        'segments_json': ChatSegmentCodec.encode(segments),
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
        'attachments': attachments.map((item) => item.toJson()).toList(),
        'expects_reply': expectsReply,
        'segments': segments.map((item) => item.toJson()).toList(),
      };

  factory ChatMessage.fromDb(
    Map<String, Object?> row, {
    List<MessageAttachment> attachments = const <MessageAttachment>[],
  }) {
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
      attachments: attachments,
      expectsReply: (row['expects_reply'] as int? ?? 1) == 1,
      segments: ChatSegmentCodec.decode(
        row['segments_json'] as String?,
        fallbackText: (row['content'] as String?) ?? '',
      ),
    );
  }
}
