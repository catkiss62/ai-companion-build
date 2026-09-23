import 'package:ai_companion_localfirst/core/mcp/cedar_solo_episode_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_outcome_bookkeeper.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreground resume resets only an already-due solo checkpoint', () {
    final now = DateTime(2026, 9, 23, 12);
    final active = CedarSoloEpisodeState(
      gameId: 'fishing',
      startedAt: now.subtract(const Duration(minutes: 5)),
      stateChangeCount: 1,
    );
    final due = CedarSoloEpisodeState(
      gameId: 'fishing',
      startedAt: now.subtract(const Duration(minutes: 30)),
      stateChangeCount: 3,
      checkpointPending: true,
      checkpointReason: 'state_change_limit',
    );

    expect(
      CedarPlayOutcomeBookkeeper.episodeForOutcome(
        stored: active,
        now: now,
        isStateChange: true,
        origin: CedarPlayBookkeepingOrigin.userTurn,
      ),
      same(active),
    );
    final resumed = CedarPlayOutcomeBookkeeper.episodeForOutcome(
      stored: due,
      now: now,
      isStateChange: true,
      origin: CedarPlayBookkeepingOrigin.userTurn,
    );
    expect(resumed.startedAt, now);
    expect(resumed.stateChangeCount, 0);
    expect(resumed.checkpointPending, isFalse);
  });

  final now = DateTime(2026, 9, 20, 1);

  McpToolOutcome outcome({
    String text = '',
    Object? structured,
    bool isError = false,
  }) =>
      McpToolOutcome(
        content: text.isEmpty
            ? const <McpContentBlock>[]
            : <McpContentBlock>[
                McpContentBlock(kind: McpContentKind.text, text: text),
              ],
        isError: isError,
        structuredContent: structured,
      );

  test('three successful state changes create one resumable checkpoint', () {
    var state = CedarSoloEpisodePolicy.start('fishing', now);
    for (var i = 0; i < 3; i++) {
      state = CedarSoloEpisodePolicy.recordOutcome(
        state: state,
        now: now.add(Duration(minutes: i + 1)),
        action: 'cast',
        succeeded: true,
        antiAddiction: const CedarAntiAddictionSignal(),
      );
    }

    expect(state.stateChangeCount, 3);
    expect(state.checkpointPending, isTrue);
    expect(state.checkpointReason, 'state_change_limit');
  });

  test('read-only, failed, platform and exit actions do not spend episode steps', () {
    var state = CedarSoloEpisodePolicy.start('fishing', now);
    for (final entry in <(String, bool)>[
      ('state', true),
      ('cast', false),
      ('announcements', true),
      ('rest', true),
      ('leave', true),
    ]) {
      state = CedarSoloEpisodePolicy.recordOutcome(
        state: state,
        now: now,
        action: entry.$1,
        succeeded: entry.$2,
        antiAddiction: const CedarAntiAddictionSignal(),
      );
    }

    expect(state.stateChangeCount, 0);
    expect(state.checkpointPending, isFalse);
  });

  test('twenty-five minutes creates checkpoint without another move', () {
    final state = CedarSoloEpisodePolicy.checkpointIfDue(
      CedarSoloEpisodePolicy.start('travel', now),
      now.add(const Duration(minutes: 25)),
    );

    expect(state.checkpointPending, isTrue);
    expect(state.checkpointReason, 'duration_limit');
  });

  test('structured anti-addiction lock carries permission and recovery time', () {
    final signal = CedarAntiAddictionParser.inspect(
      outcome(structured: <String, Object?>{
        'anti_addiction': <String, Object?>{
          'status': 'locked',
          'allow_self_reset': true,
          'resume_after_seconds': 1800,
        },
      }),
      now: now,
    );

    expect(signal.level, CedarAntiAddictionLevel.locked);
    expect(signal.allowSelfReset, isTrue);
    expect(signal.resumeAt, now.add(const Duration(minutes: 30)));
    expect(signal.source, 'structured');
  });

  test('explicit reminder text is accepted but an ordinary game lock is not', () {
    final reminder = CedarAntiAddictionParser.inspect(
      outcome(text: '防沉迷提醒：你已经连续游玩较多轮，建议休息一下。'),
      now: now,
    );
    final ordinary = CedarAntiAddictionParser.inspect(
      outcome(text: '矿井入口已锁定，需要先找到钥匙。'),
      now: now,
    );

    expect(reminder.level, CedarAntiAddictionLevel.reminder);
    expect(ordinary.level, CedarAntiAddictionLevel.none);
    expect(ordinary.allowSelfReset, isNull);
  });

  test('anti-addiction reminder forces checkpoint without inventing reset consent', () {
    final state = CedarSoloEpisodePolicy.recordOutcome(
      state: CedarSoloEpisodePolicy.start('fishing', now),
      now: now.add(const Duration(minutes: 2)),
      action: 'state',
      succeeded: true,
      antiAddiction: const CedarAntiAddictionSignal(
        level: CedarAntiAddictionLevel.reminder,
        source: 'explicit_text',
      ),
    );

    expect(state.checkpointPending, isTrue);
    expect(state.checkpointReason, 'anti_addiction_reminder');
    expect(state.allowSelfReset, isFalse);
  });
}
