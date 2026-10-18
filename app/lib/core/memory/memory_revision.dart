import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/memory_item.dart';
import '../models/chat_message.dart';
import '../personality/form_context_snapshot.dart';

/// A local capability bound to the exact memory read before extraction.
/// Persist it beside the proposal; never reconstruct it from a later read or
/// accept a token supplied by the model.
class MemoryRevisionSnapshot {
  const MemoryRevisionSnapshot({required this.id, required this.token,
    this.subjectKey = '', this.content = ''});

  final String id;
  final String token;
  final String subjectKey;
  final String content;

  factory MemoryRevisionSnapshot.capture(MemoryItem item) =>
      MemoryRevisionSnapshot(id: item.id, token: _token(item),
          subjectKey: item.subjectKey, content: item.content);

  static String _token(MemoryItem item) => sha256.convert(utf8.encode(jsonEncode([
        item.id, item.kind, item.content, item.subjectKey, item.semanticType,
        item.status, item.pinned, item.factVersion,
        item.updatedAt.millisecondsSinceEpoch, item.actorKey, item.ownerKey,
        item.relationKey, item.objectKey, item.temporalScope,
        item.importance, item.confidence, item.tags, item.topicKey,
        item.source, item.sourceUserMessageId, item.sourceAssistantMessageId,
        item.sourceContextJson, item.factState, item.attentionState,
        item.recallPolicy, item.spontaneousSalience,
        item.sourceValid, item.evidenceTimeKnown, item.firstObservedAt.millisecondsSinceEpoch,
        item.lastEvidenceAt.millisecondsSinceEpoch, item.createdAt.millisecondsSinceEpoch,
      ]))).toString();

  bool matches(MemoryItem item) => id == item.id && token == _token(item);

  Map<String, Object?> toJson() => {'id': id, 'token': token,
    'subject_key': subjectKey, 'content': content};

  static MemoryRevisionSnapshot? decode(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final token = raw['token'];
    if (id is! String || id.isEmpty || token is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) return null;
    return MemoryRevisionSnapshot(id: id, token: token,
        subjectKey: raw['subject_key'] as String? ?? '',
        content: raw['content'] as String? ?? '');
  }
}

/// Immutable source metadata outlives raw-message retention. Neither forms nor
/// timestamps are inferred from wording, current state, or model proposals.
class MemorySourceContext {
  static String capture(ChatMessage user, ChatMessage assistant) => jsonEncode({
        'user': _message(user), 'assistant': _message(assistant),
      });

  static Map<String, Object?> _message(ChatMessage message) => {
        'message_id': message.id,
        'created_at': message.createdAt.millisecondsSinceEpoch,
        'form_context_json': message.formContextJson,
      };

  static Map<String, dynamic> decode(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  static String preserveOrigin(String current, String previous) {
    final result = decode(current);
    final old = decode(previous);
    final origin = old['origin'] is Map ? old['origin'] : old;
    result['origin'] = origin;
    return jsonEncode(result);
  }

  static String format(String raw) {
    final data = decode(raw);
    if (data.isEmpty) return '来源时间与形态未知（旧记录未保存，不推断）';
    if (data['scene'] == 'model_dialogue') {
      final at = data['created_at'];
      final time = at is num ? DateTime.fromMillisecondsSinceEpoch(at.toInt()).toIso8601String() : '时间未知';
      return '模型对谈经历；$time；DeepSeek/Gemini观点分别归属，用户原话单独标记，讨论不是实际执行';
    }
    String pair(Object? value) {
      final pair = value is Map ? value : const <String, Object?>{};
      if (pair.isEmpty) return '时间与形态未知（旧记录未保存，不推断）';
      String form(String key) {
        final message = pair[key];
        final rawForm = message is Map ? message['form_context_json'] : null;
        return FormContextSnapshot.decode(rawForm is String ? rawForm : '').historicalLabel;
      }
      final user = pair['user'];
      final rawAt = user is Map ? user['created_at'] : null;
      final at = rawAt is num ? rawAt.toInt() : null;
      final time = at == null ? '时间未知' : DateTime.fromMillisecondsSinceEpoch(at).toIso8601String();
      return '$time；用户发言时的她[${form('user')}]；AI回复时的她[${form('assistant')}]';
    }
    if (data['origin'] is Map) return '原经历来源：${pair(data['origin'])}；修订来源：${pair(data)}';
    return '来源：${pair(data)}';
  }
}
