import 'package:ai_companion_localfirst/core/agent/agent_system_self_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature wording is not mistaken for a recent action request', () {
    expect(
      AgentSystemReadScopeKey.fromInput('我给你做了哪些功能？'),
      AgentSystemReadScope.capabilities,
    );
    expect(
      AgentSystemReadScopeKey.fromInput('你最近自己做了什么？'),
      AgentSystemReadScope.recentOutcomes,
    );
  });

  test('capability catalog separates executable, manual and future abilities', () {
    final facts = AgentSystemFactsPolicy.capabilities(runtime());
    final byId = {for (final fact in facts) fact.id: fact};

    expect(byId['public_web.search']!.access, 'chat_tool+autonomous');
    expect(byId['state.encrypted_backup']!.access, 'manual');
    expect(byId['mcp.games']!.access, 'future');
    expect(byId['mcp.games']!.state, 'not_implemented');
    expect(byId['vision.qwen']!.state, 'configured');
  });

  test('runtime prompt preserves unknown connection state without guessing', () {
    final current = runtime(
      visionConfigured: null,
      accessibilityAuthorized: true,
      accessibilityConnected: null,
    );
    final prompt = AgentSystemFactsPolicy.buildPrompt(
      scope: AgentSystemReadScope.runtime,
      snapshot: AgentSystemSelfSnapshot(
        runtime: current,
        capabilities: AgentSystemFactsPolicy.capabilities(current),
        outcomes: const [],
      ),
    );

    expect(prompt, contains('vision_configured=unknown'));
    expect(prompt, contains('accessibility_authorized=true'));
    expect(prompt, contains('accessibility_connected=unknown'));
    expect(prompt, isNot(contains('mcp.games')));
  });

  test('recent outcome scope reports only bounded structured evidence', () {
    final current = runtime();
    final prompt = AgentSystemFactsPolicy.buildPrompt(
      scope: AgentSystemReadScope.recentOutcomes,
      snapshot: AgentSystemSelfSnapshot(
        runtime: current,
        capabilities: AgentSystemFactsPolicy.capabilities(current),
        outcomes: [
          AgentSelfReadableOutcome(
            capabilityId: 'album.autonomous_review',
            origin: 'background',
            status: 'succeeded',
            outcome: 'saved',
            resultCount: 1,
            occurredAt: DateTime(2026, 8, 30, 20),
          ),
        ],
      ),
    );

    expect(prompt, contains('[RECENT_AGENT_OUTCOME'));
    expect(prompt, contains('capability_name=自主识图并决定是否收藏'));
    expect(prompt, contains('outcome=saved'));
    expect(prompt, contains('outcome_meaning=识别与判断后已经收藏到私人相册'));
    expect(prompt, contains('result_count=1'));
    expect(prompt, isNot(contains('app_version=')));
    expect(prompt, isNot(contains('api_key')));
    expect(prompt, contains('api_secret=false'));
    expect(prompt, contains('database_or_file_path=false'));
  });
}

AgentSystemRuntimeFacts runtime({
  bool? visionConfigured = true,
  bool? accessibilityAuthorized = true,
  bool? accessibilityConnected = true,
}) =>
    AgentSystemRuntimeFacts(
      activeBrain: true,
      transferLocked: false,
      textModelConfigured: true,
      visionConfigured: visionConfigured,
      publicWebEnabled: true,
      phoneEnabled: true,
      perceptionEnabled: true,
      ttsEnabled: true,
      selfDriveEnabled: true,
      thoughtLifecycleEnabled: true,
      aiSelfReflectionEnabled: true,
      relationshipContinuityEnabled: true,
      backgroundBrainReady: true,
      overlayAuthorized: true,
      overlayRunning: true,
      usageAuthorized: true,
      accessibilityAuthorized: accessibilityAuthorized,
      accessibilityConnected: accessibilityConnected,
      notificationAuthorized: true,
      notificationConnected: true,
    );
