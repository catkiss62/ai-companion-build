import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_arcade_skill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guide = '[存档槽] 每游戏5槽，params 传 slot=1-5（缺省1；游客单槽）。'
      '空槽导入免 confirm，覆盖需 confirm=true。';

  test('five-slot contract is scoped to games whose live guide declares it',
      () {
    expect(CedarSaveSlotPolicy.supportsFiveSlots(guide), isTrue);
    expect(
      CedarSaveSlotPolicy.supportsFiveSlots('room_id 表示多人房间'),
      isFalse,
    );
    final prompt = CedarSaveSlotPolicy.promptGuidance(guide, '');
    expect(prompt, contains('slot=1..5'));
    expect(prompt, contains('不同 game 的同号槽也互不覆盖'));
    expect(prompt, contains('官方人类前端或服务自动建立'));
    expect(CedarToyArcadeSkill.prompt, contains('可自主选择已知空槽'));
  });

  test('autonomy can use a known empty slot but cannot confirm overwrite', () {
    expect(
      CedarSaveSlotPolicy.blocksAutonomousAction(
        guide: guide,
        lastOutcome: '',
        action: 'eco_new',
        params: const {'slot': 3},
      ),
      isFalse,
    );
    expect(
      CedarSaveSlotPolicy.blocksAutonomousAction(
        guide: guide,
        lastOutcome: '',
        action: 'eco_new',
        params: const {'slot': 3, 'confirm': true},
      ),
      isTrue,
    );
  });

  test('existing turn-zero save redirects autonomy from new to continue', () {
    const outcome = '检测到该 player_id 已有池塘（turn：0）。'
        '覆盖后原存档将无法恢复；如确认覆盖请重新调用并带 confirm: true';
    expect(CedarSaveSlotPolicy.outcomeIndicatesExistingSave(outcome), isTrue);
    expect(
      CedarSaveSlotPolicy.blocksAutonomousAction(
        guide: guide,
        lastOutcome: outcome,
        action: 'eco_new',
        params: const {'slot': 1},
      ),
      isTrue,
    );
    expect(
      CedarSaveSlotPolicy.blocksAutonomousAction(
        guide: guide,
        lastOutcome: outcome,
        action: 'eco_observe',
        params: const {'slot': 1},
      ),
      isFalse,
    );
  });

  test('destructive overwrite requires affirmative user wording', () {
    expect(
      CedarSaveSlotPolicy.userExplicitlyApprovesOverwrite('可以，覆盖 2 号档吧'),
      isTrue,
    );
    expect(
      CedarSaveSlotPolicy.userExplicitlyApprovesOverwrite('为什么要覆盖存档？'),
      isFalse,
    );
    expect(
      CedarSaveSlotPolicy.userExplicitlyApprovesOverwrite('不要覆盖旧档'),
      isFalse,
    );
    expect(
      CedarSaveSlotPolicy.userExplicitlyApprovesOverwrite('我不想覆盖旧档'),
      isFalse,
    );
  });
}
