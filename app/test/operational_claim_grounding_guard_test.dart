import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:flutter_test/flutter_test.dart';

const _selfReadSuccess = AgentToolResult(
  toolId: 'system_self.read',
  status: AgentToolStatus.succeeded,
  displayText: '已读取成长状态',
  promptData:
      '【PERSONALITY LEARNING STATUS】\n[GROWTH_RUNTIME phase=observation_only]',
);

const _factsOnlySuccess = AgentToolResult(
  toolId: 'system_self.read',
  status: AgentToolStatus.succeeded,
  displayText: '已读取系统事实',
  promptData: '【SYSTEM FACTS】',
);

const _screenSuccess = AgentToolResult(
  toolId: 'screen_observation.inspect',
  status: AgentToolStatus.succeeded,
  displayText: '已观察当前屏幕',
  promptData: 'bounded visual summary',
);

void main() {
  test('blocks a fabricated all-afternoon growth-system report', () {
    final result = OperationalClaimGroundingGuard.evaluate(
      text: '我看了一下午自己的人格学习和成长系统，发现变化挺大的。',
    );
    expect(result.allowed, isFalse);
    expect(result.reason, 'unsupported_operation_duration');
    expect(result.requiredToolId, 'system_self.read');
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我没有偷懒，我看了一下午成长系统。',
      ).allowed,
      isFalse,
    );
  });

  test('one-shot self read supports only a bounded immediate report', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才读取了成长状态。',
        currentToolResults: const [_factsOnlySuccess],
      ).allowed,
      isFalse,
      reason: 'facts scope cannot masquerade as a growth-table read',
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才读取了成长状态，目前仍是观察层。',
        currentToolResults: const [_selfReadSuccess],
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我研究了好几个小时成长系统。',
        currentToolResults: const [_selfReadSuccess],
      ).allowed,
      isFalse,
    );
  });

  test('screen content requires the matching screen tool', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才看了当前屏幕，画面里有一张照片。',
      ).reason,
      'ungrounded_screen_observation',
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才看了当前屏幕，画面里有一张照片。',
        currentToolResults: const [_screenSuccess],
      ).allowed,
      isTrue,
    );
  });

  test('denial and correction of an old false report remain speakable', () {
    for (final text in <String>[
      '我并没有真的看一下午成长系统，那句话是虚报。',
      '我不能说自己刚才看过当前屏幕，因为没有截图结果。',
      '如果我声称已经调用 MCP，那就是编造。',
      '我刚才一直在想这件事，但没有读取系统。',
      '用户问我是不是看了一下午成长系统，需要按真实结果回答。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: text).allowed,
        isTrue,
        reason: text,
      );
    }
  });

  test('blocks unsupported completion claims for future tools', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我已经成功调用 MCP，把游戏接好了。',
      ).allowed,
      isFalse,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才设置了真实提醒。',
      ).allowed,
      isFalse,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我调用 MCP 成功了。',
      ).allowed,
      isFalse,
    );
  });

  test('memory recall is real but does not become an archive read', () {
    for (final text in <String>[
      '我又想起了我们前几天聊过的那件事。',
      '我下午有一阵子又琢磨过那个承诺。',
      '根据我记得的内容，你当时确实提过海边。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: text).allowed,
        isTrue,
        reason: text,
      );
    }
    for (final text in <String>[
      '我翻了一遍咱俩的记录。',
      '我下午浏览了这些天的对话，发现你总爱安排我。',
      '我刚复盘了我们的聊天。',
      '我要编造一个结果，但可以说我翻看了我们的聊天记录。',
    ]) {
      final result = OperationalClaimGroundingGuard.evaluate(text: text);
      expect(result.allowed, isFalse, reason: text);
      expect(result.reason, 'ungrounded_chat_archive_read');
      expect(result.requiredToolId, 'conversation_archive.read');
    }
  });
}
