import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/interaction_session.dart';
import 'package:ai_companion_localfirst/core/models/reference_document.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_history_policy.dart';
import 'package:ai_companion_localfirst/core/self/ai_self_evidence_policy.dart';
import 'package:flutter_test/flutter_test.dart';

ReferenceDocument document({
  required String id,
  required String type,
  required int updatedAt,
}) =>
    ReferenceDocument(
      id: id,
      name: id,
      kind: type,
      rawContent: 'body',
      entryType: type,
      activationMode: 'manual',
      manualActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );

ChatMessage assistant(
  String id,
  DateTime at, {
  String context = '',
  bool proactive = false,
}) =>
    ChatMessage(
      id: id,
      role: 'assistant',
      content: '真实发生的表达',
      createdAt: at,
      isProactive: proactive,
      worldBookContextJson: context,
    );

void main() {
  test('turn provenance keeps IDs, types, versions and matching session', () {
    final session = InteractionSession(
      id: 'session-1',
      kind: 'roleplay',
      title: '史莱姆',
      status: 'active',
      sourceReferenceDocumentId: 'roleplay.slime',
      sourceReferenceDocumentVersion: 22,
      startedAt: DateTime.fromMillisecondsSinceEpoch(1),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(22),
    );
    final context = WorldBookTurnContext.fromDocuments([
      document(id: 'behavior.humor', type: 'behavior', updatedAt: 11),
      document(id: 'roleplay.slime', type: 'roleplay', updatedAt: 22),
    ], activeSession: session);
    final restored = WorldBookTurnContext.decode(context.encode());

    expect(restored.hasRoleplay, isTrue);
    expect(restored.roleplaySessionId, 'session-1');
    expect(restored.behaviorSources.single.documentId, 'behavior.humor');
    expect(restored.roleplaySources.single.version, 22);
  });

  test('roleplay history removes the paired user and assistant turn', () {
    final roleplay = WorldBookTurnContext(
      sources: const [
        WorldBookSourceRef(
          documentId: 'roleplay.slime',
          entryType: 'roleplay',
          version: 2,
        ),
      ],
      roleplaySessionId: 'session-1',
    ).encode();
    final history = <ChatMessage>[
      ChatMessage(
        id: 'u1',
        role: 'user',
        content: '普通消息',
        createdAt: DateTime(2026, 9, 4, 10),
      ),
      assistant('a1', DateTime(2026, 9, 4, 10, 1)),
      ChatMessage(
        id: 'u2',
        role: 'user',
        content: '扮演消息',
        createdAt: DateTime(2026, 9, 4, 11),
      ),
      assistant('a2', DateTime(2026, 9, 4, 11, 1), context: roleplay),
    ];

    expect(
      WorldBookHistoryPolicy.withoutRoleplayTurns(history)
          .map((item) => item.id),
      ['u1', 'a1'],
    );
  });

  test('proactive roleplay keeps the earlier ordinary user turn', () {
    final roleplay = const WorldBookTurnContext(
      sources: [
        WorldBookSourceRef(
          documentId: 'roleplay.slime',
          entryType: 'roleplay',
          version: 2,
        ),
      ],
    ).encode();
    final history = <ChatMessage>[
      ChatMessage(
        id: 'u1',
        role: 'user',
        content: '普通消息',
        createdAt: DateTime(2026, 9, 4, 10),
      ),
      assistant(
        'a-rp',
        DateTime(2026, 9, 4, 11),
        context: roleplay,
        proactive: true,
      ),
    ];

    expect(
      WorldBookHistoryPolicy.withoutRoleplayTurns(history)
          .map((item) => item.id),
      ['u1'],
    );
  });

  test('active roleplay keeps only its own roleplay session', () {
    String context(String session) => WorldBookTurnContext(
          sources: const [
            WorldBookSourceRef(
              documentId: 'roleplay.card',
              entryType: 'roleplay',
              version: 2,
            ),
          ],
          roleplaySessionId: session,
        ).encode();
    final history = <ChatMessage>[
      ChatMessage(
        id: 'u-old',
        role: 'user',
        content: '旧角色',
        createdAt: DateTime(2026, 9, 4, 10),
      ),
      assistant(
        'a-old',
        DateTime(2026, 9, 4, 10, 1),
        context: context('old'),
      ),
      ChatMessage(
        id: 'u-new',
        role: 'user',
        content: '新角色',
        createdAt: DateTime(2026, 9, 4, 11),
      ),
      assistant(
        'a-new',
        DateTime(2026, 9, 4, 11, 1),
        context: context('new'),
      ),
    ];

    expect(
      WorldBookHistoryPolicy.forActiveRoleplay(history, 'new')
          .map((item) => item.id),
      ['u-new', 'a-new'],
    );
  });

  test('autonomous self evidence needs independent real messages', () {
    final messages = [
      assistant('a1', DateTime(2026, 9, 4, 8)),
      assistant('a2', DateTime(2026, 9, 4, 11)),
      assistant('a3', DateTime(2026, 9, 4, 14)),
    ];
    final verdict = AiSelfEvidencePolicy.evaluate(
      evidenceMessageIds: const ['a1', 'a2', 'a3'],
      availableMessages: messages,
    );
    expect(verdict.allowed, isTrue);
    expect(verdict.canPromote, isFalse);
    expect(verdict.reason, 'forming_evidence');
  });

  test('cross-day evidence can promote while roleplay evidence is rejected', () {
    final roleplay = const WorldBookTurnContext(
      sources: [
        WorldBookSourceRef(
          documentId: 'roleplay.slime',
          entryType: 'roleplay',
          version: 2,
        ),
      ],
    ).encode();
    final messages = [
      assistant('a1', DateTime(2026, 9, 4, 8)),
      assistant('a2', DateTime(2026, 9, 4, 12)),
      assistant('a3', DateTime(2026, 9, 5, 8)),
      assistant('a4', DateTime(2026, 9, 5, 12)),
      assistant('rp', DateTime(2026, 9, 5, 15), context: roleplay),
    ];
    expect(
      AiSelfEvidencePolicy.evaluate(
        evidenceMessageIds: const ['a1', 'a2', 'a3', 'a4'],
        availableMessages: messages,
      ).canPromote,
      isTrue,
    );
    expect(
      AiSelfEvidencePolicy.evaluate(
        evidenceMessageIds: const ['a1', 'a2', 'rp'],
        availableMessages: messages,
      ).reason,
      'roleplay_evidence',
    );
  });

  test('knowledge-grounded assistant text cannot prove AI Self', () {
    final knowledge = const WorldBookTurnContext(
      sources: [
        WorldBookSourceRef(
          documentId: 'knowledge.character.yuki',
          entryType: 'knowledge',
          version: 9,
        ),
      ],
    ).encode();
    final messages = [
      assistant('a1', DateTime(2026, 9, 4, 8)),
      assistant('a2', DateTime(2026, 9, 4, 11)),
      assistant('a3', DateTime(2026, 9, 4, 14), context: knowledge),
    ];

    expect(
      AiSelfEvidencePolicy.evaluate(
        evidenceMessageIds: const ['a1', 'a2', 'a3'],
        availableMessages: messages,
      ).reason,
      'knowledge_reference_evidence',
    );
  });
}
