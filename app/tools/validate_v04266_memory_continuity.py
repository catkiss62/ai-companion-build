"""Read-time retrieval boundaries; behavioral SQLite and provider cases run in Flutter CI."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
policy = read('lib/core/memory/conversation_recall_policy.dart')
assert 'messageLimit = 64' in policy and 'characterBudget = 36000' in policy
runner = read('lib/core/ai/durable_generation_runner.dart')
assert 'ConversationRecallPolicy.recentWindow' in runner
assert 'notBefore:' in runner
brain = read('lib/core/memory/memory_brain.dart')
assert 'recallConversationSummaries' in brain and 'recallExperienceSources' in brain
assert 'REAL_USER_HISTORY' in brain and 'strongEvidence' in brain
expander = read('lib/core/memory/memory_query_expander.dart')
assert 'thinking: false' in expander and 'maxTokens: 260' in expander
assert 'explicit_memory_query_expansion' in expander
agent = read('lib/core/agent/agent_tool_runner.dart')
assert 'context.isEmpty && allowExpansion' in agent
assert '_memoryExpansionScopes.add(scope)' in agent
assert 'scope: toolChainScopeId.isNotEmpty ? toolChainScopeId : userMessageId' in agent
face = read('lib/core/ai/caicai_motion_planner.dart')
assert '明显害羞、浪漫表达或难为情时可以使用；轻微害羞不必使用。' in face
assert '以下语义仅供参考，不要求一定使用表情。' not in face
assert '情绪不明显时选无。' in face
assert '被夸奖' not in face
assert (r / 'test/memory_continuity_v04266_test.dart').is_file()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ['0.42.66+310', '0.42.67+311'])
print('v04266 bounded recall, explicit-only expansion and optional expression hints wired')
