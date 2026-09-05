import 'dart:convert';

import 'interaction_session.dart';
import 'reference_document.dart';

class WorldBookSourceRef {
  const WorldBookSourceRef({
    required this.documentId,
    required this.entryType,
    required this.version,
  });

  final String documentId;
  final String entryType;
  final int version;

  bool get isBehavior => entryType == 'behavior';
  bool get isRoleplay => entryType == 'roleplay';
  bool get isKnowledge => entryType == 'knowledge';

  Map<String, Object?> toJson() => <String, Object?>{
        'document_id': documentId,
        'entry_type': entryType,
        'version': version,
      };

  factory WorldBookSourceRef.fromJson(Map<String, Object?> json) {
    final type = json['entry_type']?.toString() ?? 'knowledge';
    return WorldBookSourceRef(
      documentId: json['document_id']?.toString() ?? '',
      entryType: const {'knowledge', 'behavior', 'roleplay'}.contains(type)
          ? type
          : 'knowledge',
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorldBookTurnContext {
  const WorldBookTurnContext({
    this.sources = const <WorldBookSourceRef>[],
    this.roleplaySessionId = '',
  });

  final List<WorldBookSourceRef> sources;
  final String roleplaySessionId;

  bool get hasRoleplay =>
      roleplaySessionId.isNotEmpty || sources.any((item) => item.isRoleplay);
  List<WorldBookSourceRef> get behaviorSources =>
      sources.where((item) => item.isBehavior).toList(growable: false);
  List<WorldBookSourceRef> get roleplaySources =>
      sources.where((item) => item.isRoleplay).toList(growable: false);
  List<WorldBookSourceRef> get knowledgeSources =>
      sources.where((item) => item.isKnowledge).toList(growable: false);

  String encode() {
    if (sources.isEmpty && roleplaySessionId.isEmpty) return '';
    return jsonEncode(<String, Object?>{
      'v': 1,
      'sources': sources.map((item) => item.toJson()).toList(growable: false),
      if (roleplaySessionId.isNotEmpty)
        'roleplay_session_id': roleplaySessionId,
    });
  }

  static WorldBookTurnContext fromDocuments(
    Iterable<ReferenceDocument> documents, {
    InteractionSession? activeSession,
  }) {
    final byId = <String, WorldBookSourceRef>{};
    for (final document in documents) {
      byId[document.id] = WorldBookSourceRef(
        documentId: document.id,
        entryType: document.entryType,
        version: document.updatedAt.millisecondsSinceEpoch,
      );
    }
    final roleplayIds = byId.values
        .where((item) => item.isRoleplay)
        .map((item) => item.documentId)
        .toSet();
    final sessionMatches = activeSession != null &&
        activeSession.isActive &&
        activeSession.sourceReferenceDocumentId.isNotEmpty &&
        roleplayIds.contains(activeSession.sourceReferenceDocumentId);
    final boundedSources = byId.values.toList(growable: false)
      ..sort((left, right) {
        int rank(WorldBookSourceRef item) => item.isRoleplay
            ? 0
            : item.isBehavior
                ? 1
                : 2;
        return rank(left).compareTo(rank(right));
      });
    return WorldBookTurnContext(
      sources: List<WorldBookSourceRef>.unmodifiable(boundedSources.take(24)),
      roleplaySessionId: sessionMatches ? activeSession.id : '',
    );
  }

  factory WorldBookTurnContext.decode(String raw) {
    if (raw.trim().isEmpty) return const WorldBookTurnContext();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const WorldBookTurnContext();
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final sources = (map['sources'] as List?)
              ?.whereType<Map>()
              .map((item) => WorldBookSourceRef.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ))
              .where((item) => item.documentId.isNotEmpty)
              .take(24)
              .toList(growable: false) ??
          const <WorldBookSourceRef>[];
      return WorldBookTurnContext(
        sources: sources,
        roleplaySessionId: map['roleplay_session_id']?.toString() ?? '',
      );
    } catch (_) {
      return const WorldBookTurnContext();
    }
  }
}
