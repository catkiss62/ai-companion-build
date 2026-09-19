import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

McpToolOutcome _outcome(Map<String, Object?> value) => McpToolOutcome(
      content: <McpContentBlock>[
        McpContentBlock(
          kind: McpContentKind.text,
          text: jsonEncode(value),
        ),
      ],
      isError: false,
      structuredContent: value,
    );

String _toolCallSse(Map<String, Object?> arguments) {
  final event = jsonEncode(<String, Object?>{
    'choices': <Object?>[
      <String, Object?>{
        'delta': <String, Object?>{
          'tool_calls': <Object?>[
            <String, Object?>{
              'index': 0,
              'id': 'cedar-call',
              'type': 'function',
              'function': <String, Object?>{
                'name': 'cedar_toy_play',
                'arguments': jsonEncode(arguments),
              },
            },
          ],
        },
        'finish_reason': 'tool_calls',
      },
    ],
  });
  return 'data: $event\n\ndata: [DONE]\n\n';
}

String _verificationResponse() => jsonEncode(<String, Object?>{
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{
            'content': jsonEncode(<String, Object?>{
              'next_actor': 'wait',
              'share_level': 'quiet',
              'resume_after_seconds': 0,
            }),
          },
          'finish_reason': 'stop',
        },
      ],
    });

Map<String, Object?> _plannerMove(int revision, int row, int col) =>
    <String, Object?>{
      'game': 'duel',
      'action': 'move',
      'params_json': jsonEncode(<String, Object?>{
        'room_id': 'ROOM1234',
        'revision': revision,
        'wait': true,
        'move': <String, Object?>{'row': row, 'col': col},
      }),
      'participation_mode': 'multiplayer',
      'invitation_approved': true,
    };

Map<String, Object?> _waitingOutcome(int revision) => <String, Object?>{
      'ok': true,
      'status': 'playing',
      'room_id': 'ROOM1234',
      'revision': revision,
      'your_turn': false,
      'current_actor': <String, Object?>{
        'player_id': 'human-1',
        'role': 'human',
      },
      'wait_scope': 'current_request_only',
      'next_call': <String, Object?>{
        'game': 'duel',
        'action': 'state',
        'params': <String, Object?>{
          'room_id': 'ROOM1234',
          'wait': true,
        },
      },
    };

Map<String, Object?> _companionTurnOutcome(int revision) => <String, Object?>{
      'ok': true,
      'status': 'playing',
      'room_id': 'ROOM1234',
      'revision': revision,
      'your_turn': true,
      'current_actor': <String, Object?>{
        'player_id': 'ai-1',
        'role': 'ai',
      },
      'events': <Object?>[
        <String, Object?>{
          'name': 'human-1',
          'move': <String, Object?>{'row': 8, 'col': 8},
        },
      ],
    };

void main() {
  sqfliteFfiInit();

  group('Cedar durable room state machine', () {
    late AppDatabase db;

    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
      await db.setSetting('active_brain', '1');
      await db.setSetting('transfer_lock', '0');
      await db.setSetting('cedar_toy_enabled', '1');
      await db.setSetting(CedarToyAutonomyEngine.enabledKey, '1');
    });

    tearDown(() => db.closeForTesting());

    test('terminal outcome remains pending until the visible reply commits',
        () async {
      final store = CedarToyActivityStore(db);
      await store.recordGuide(
        gameId: 'duel',
        gameTitle: '双弈',
        guide: 'actions: new rooms state move',
      );
      final finished = await store.recordPlay(
        gameId: 'duel',
        action: 'move',
        outcome: _outcome(<String, Object?>{
          'ok': true,
          'status': 'finished',
          'winner': 'ai-1',
        }),
        mode: CedarParticipationMode.multiplayer,
        nextActor: 'finished',
        shareLevel: 'required',
        invitationApproved: true,
      );

      expect(finished.phase, CedarActivityPhase.completed);
      expect(finished.hasPendingTerminalDelivery, isTrue);
      expect((await store.loadState()).hasUserTurnContinuation, isTrue);
      expect(
        await store.markTerminalDelivered(
          gameId: 'duel',
          terminalKey: 'wrong-key',
        ),
        isFalse,
      );
      expect(
        await store.markTerminalDelivered(
          gameId: 'duel',
          terminalKey: finished.pendingTerminalKey,
        ),
        isTrue,
      );
      expect((await store.load())!.hasPendingTerminalDelivery, isFalse);
    });

    test('a restored unique room list hydrates before claiming user turn',
        () async {
      final store = CedarToyActivityStore(db);
      final now = DateTime.now();
      final stale = CedarGameSession(
        id: 'duel-restored',
        gameId: 'duel',
        gameTitle: '双弈',
        guide: 'actions: rooms state move',
        guideComplete: true,
        mode: CedarParticipationMode.multiplayer,
        phase: CedarActivityPhase.waitingUser,
        lastAction: 'rooms',
        lastOutcome: jsonEncode(<String, Object?>{
          'rooms': <Object?>[
            <String, Object?>{'room_id': 'ONLYROOM'},
          ],
        }),
        nextActor: 'user',
        invitationApproved: true,
        updatedAt: now.subtract(const Duration(hours: 2)),
      );
      await db.setSetting(
        CedarToyActivityStore.stateSettingKey,
        jsonEncode(CedarToyActivityState(
          activeGameId: 'duel',
          sessions: <String, CedarGameSession>{'duel': stale},
          updatedAt: now,
        ).toJson()),
      );

      final hydrated = (await store.loadState()).activeSession!;

      expect(hydrated.nextActor, 'wait');
      expect(hydrated.phase, CedarActivityPhase.waitingRemote);
      expect(hydrated.continuationAction, 'state');
      expect(hydrated.continuationParamsJson, contains('ONLYROOM'));
      expect(hydrated.waitingReason, contains('同步'));
    });

    test('new -> own turn -> move -> wait -> remote move -> own move',
        () async {
      final store = CedarToyActivityStore(db);
      await store.recordGuide(
        gameId: 'duel',
        gameTitle: '双弈',
        guide: 'actions: new rooms state move; params: room_id revision wait',
      );
      await store.recordPlay(
        gameId: 'duel',
        action: 'new',
        outcome: _outcome(_companionTurnOutcome(0)),
        mode: CedarParticipationMode.multiplayer,
        nextActor: 'companion',
        shareLevel: 'quiet',
        invitationApproved: true,
      );

      final serverOutcomes = <Map<String, Object?>>[
        _waitingOutcome(1),
        _companionTurnOutcome(2),
        _waitingOutcome(3),
      ];
      final submitted = <Map<String, Object?>>[];
      final mcpHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final method = body['method']?.toString() ?? '';
        if (method == 'notifications/initialized') {
          return http.Response('{}', 202);
        }
        if (method == 'initialize') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': <String, Object?>{},
            }),
            200,
          );
        }
        final params = (body['params'] as Map).cast<String, Object?>();
        final arguments = (params['arguments'] as Map).cast<String, Object?>();
        final playParams = (arguments['params'] as Map).cast<String, Object?>();
        submitted.add(<String, Object?>{
          'action': arguments['action'],
          'params': playParams,
        });
        final outcome = serverOutcomes.removeAt(0);
        return http.Response(
          jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': body['id'],
            'result': <String, Object?>{
              'content': <Object?>[
                <String, Object?>{
                  'type': 'text',
                  'text': jsonEncode(outcome),
                },
              ],
              'structuredContent': outcome,
              'isError': false,
            },
          }),
          200,
        );
      });

      var planningRound = 0;
      var verificationCalls = 0;
      final ai = DeepSeekClient(
        streamClientFactory: () => MockClient((request) async {
          planningRound++;
          return http.Response(
            _toolCallSse(
              planningRound == 1
                  ? _plannerMove(0, 7, 7)
                  : _plannerMove(2, 7, 8),
            ),
            200,
            headers: const <String, String>{
              'content-type': 'text/event-stream',
            },
          );
        }),
        jsonClientFactory: () => MockClient((request) async {
          verificationCalls++;
          return http.Response(
            _verificationResponse(),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );
      final engine = CedarToyAutonomyEngine(
        db: db,
        ai: ai,
        secureConfig: SecureConfig.instance,
        tokenReader: () async => 'ctai_v1_test',
        apiKeyReader: () async => 'test-key',
        endpointReader: () async => DeepSeekClient.defaultEndpoint,
        clientFactory: (token) => CedarToyClient(
          token: token,
          transport: McpHttpClient(
            endpoint: Uri.parse('https://example.invalid/mcp'),
            client: mcpHttp,
          ),
        ),
      );

      final future = DateTime.now().add(const Duration(days: 2));
      final now = DateTime(future.year, future.month, future.day, 2, 1);
      expect((await engine.continueDue(now: now)).state, 'played_one_step');
      var session = (await store.load())!;
      expect(session.lastAction, 'move');
      expect(session.nextActor, 'wait');
      expect(session.continuationAction, 'state');
      expect((submitted[0]['params'] as Map)['wait'], isFalse);

      expect(
        (await engine.continueDue(now: now.add(const Duration(minutes: 1))))
            .state,
        'played_one_step',
      );
      session = (await store.load())!;
      expect(session.nextActor, 'wait');
      expect(session.hasContinuationCall, isTrue);
      expect(submitted.map((item) => item['action']).toList(), <String>[
        'move',
        'state',
        'move',
      ]);
      expect((submitted[1]['params'] as Map)['wait'], isTrue);
      expect((submitted[2]['params'] as Map)['wait'], isFalse);
      expect(planningRound, 2);
      expect(verificationCalls, 0,
          reason: 'authoritative Cedar state must persist without a model wait');
      ai.close();
    });

    test('a timed-out duel write becomes a read-only reconciliation', () async {
      final store = CedarToyActivityStore(db);
      await store.recordGuide(
        gameId: 'duel',
        guide: 'actions: new rooms state move',
      );
      await store.markWriteOutcomeUncertain(
        gameId: 'duel',
        action: 'new',
        params: const <String, Object?>{
          'game_type': 'gomoku',
          'wait': false,
        },
      );

      final session = (await store.load())!;
      expect(session.nextActor, 'wait');
      expect(session.continuationAction, 'rooms');
      expect(session.continuationWaitScope, 'write_reconcile_once');
      expect(session.needsContinuation, isTrue);
    });

    test('provider HTTP failure remains visible instead of becoming other',
        () async {
      final store = CedarToyActivityStore(db);
      await store.recordGuide(
        gameId: 'duel',
        guide: 'actions: new rooms state move; params: room_id revision wait',
      );
      await store.recordPlay(
        gameId: 'duel',
        action: 'new',
        outcome: _outcome(_companionTurnOutcome(0)),
        mode: CedarParticipationMode.multiplayer,
        nextActor: 'companion',
        shareLevel: 'quiet',
        invitationApproved: true,
      );

      final ai = DeepSeekClient(
        streamClientFactory: () => MockClient((request) async => http.Response(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{
                  'message': 'unsupported tool request',
                },
              }),
              400,
            )),
      );
      final engine = CedarToyAutonomyEngine(
        db: db,
        ai: ai,
        secureConfig: SecureConfig.instance,
        tokenReader: () async => 'ctai_v1_test',
        apiKeyReader: () async => 'test-key',
        endpointReader: () async => DeepSeekClient.defaultEndpoint,
        clientFactory: (token) => CedarToyClient(
          token: token,
          transport: McpHttpClient(
            endpoint: Uri.parse('https://example.invalid/mcp'),
            client: MockClient((request) async =>
                throw StateError('MCP must not run after planner failure')),
          ),
        ),
      );

      expect(
        (await engine.continueDue(
          now: DateTime.now().add(const Duration(minutes: 1)),
        ))
            .state,
        'execution_failed',
      );
      expect(
        await db.getSetting('cedar_toy_last_execution_error_category'),
        'provider_http_400',
      );
      expect(
        await db.getSetting('cedar_toy_last_execution_error_detail'),
        contains('unsupported tool request'),
      );
      ai.close();
    });

    test('game-hall switch pauses and removes the continuation clock', () async {
      final store = CedarToyActivityStore(db);
      await store.recordGuide(gameId: 'duel', guide: 'new state move');
      await store.recordPlay(
        gameId: 'duel',
        action: 'move',
        outcome: _outcome(_waitingOutcome(1)),
        mode: CedarParticipationMode.multiplayer,
        nextActor: 'wait',
        shareLevel: 'quiet',
        invitationApproved: true,
      );
      expect(await store.nextContinuationDelay(DateTime.now()), isNotNull);

      await db.setSetting('cedar_toy_enabled', '0');
      await store.suspendForSwitch();
      final paused = (await store.load())!;
      expect(paused.phase, CedarActivityPhase.paused);
      expect(paused.nextActionAt, isNull);
      expect(await store.nextContinuationDelay(DateTime.now()), isNull);
    });

    test('Stop terminally cancels an incomplete draft and unblocks backup',
        () async {
      final user = ChatMessage(
        id: 'user-1',
        role: 'user',
        content: '这条回复卡住了',
        createdAt: DateTime.now(),
        deviceId: 'device-1',
      );
      final pending = await db.createGenerationTurn(
        user: user,
        assistantMessageId: 'assistant-1',
        model: 'deepseek-chat',
        reasoningEffort: 'high',
      );
      final running = (await db.claimGenerationJob(pending.id))!;
      final held = await db.holdGenerationJobForUserDecision(
        running.id,
        runToken: running.runToken,
        partialReasoning: 'partial',
        partialContent: 'partial reply',
      );
      expect(held?.status, 'awaiting_confirmation');

      expect(await db.cancelGenerationJobByUser(running.id), isTrue);
      expect((await db.generationJobById(running.id))?.status,
          'cancelled_by_user');
      expect(await db.blockingGenerationJob(), isNull);
      expect(await db.messageById(user.id), isNull);

      final freeze = await db.acquireTransferFreeze(purpose: 'backup_export');
      expect(await db.ownsTransferFreeze(freeze), isTrue);
      expect(await db.releaseTransferFreeze(freeze), isTrue);
    });
  });

  test('duel transport never couples an ordinary action to a long poll', () {
    expect(
      CedarActionTransportPolicy.immediateResponseParams(
        gameId: 'duel',
        params: const <String, Object?>{'wait': true, 'revision': 4},
      ),
      <String, Object?>{'wait': false, 'revision': 4},
    );
    expect(
      CedarActionTransportPolicy.immediateResponseParams(
        gameId: 'fishing',
        params: const <String, Object?>{'wait': true},
      )['wait'],
      isTrue,
    );
  });

  test('visible chat without a writer lease does not block Cedar', () {
    expect(
      CedarContinuationPriorityPolicy.shouldDefer(
        chatTurnLeaseHeld: false,
      ),
      isFalse,
    );
    expect(
      CedarContinuationPriorityPolicy.shouldDefer(
        chatTurnLeaseHeld: true,
      ),
      isTrue,
    );
  });
}
