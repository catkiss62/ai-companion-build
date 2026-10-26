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
# +368 shares the original semantic catalog with real-audio planning.
face = read('lib/core/ai/caicai_motion_planner.dart') + read('lib/core/ai/caicai_preset_catalog.dart')
assert '轻微脸热也可自然表达，不必等到强烈害羞。' in face
assert '以下语义仅供参考，不要求一定使用表情。' not in face
assert "questions['face_use']" in face and "questions['wink_use']" in face
assert "answers['face_use'] == 'yes'" in face and "answers['wink_use'] == 'yes'" in face
assert '被夸奖' not in face
assert (r / 'test/memory_continuity_v04266_test.dart').is_file()
assert any(f'\nversion: {v}\n' in read('pubspec.yaml') for v in ['0.42.66+310', '0.42.67+311', '0.42.68+312', '0.42.69+313', '0.42.70+314', '0.42.71+315', '0.42.72+316', '0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338', '0.42.95+339', '0.42.96+340', '0.42.97+341', '0.42.98+342', '0.42.99+343', '0.42.100+344', '0.42.101+345', '0.42.102+346', '0.42.103+347', '0.42.104+348', '0.42.105+349', '0.42.106+350', '0.42.107+351', '0.42.108+352', '0.42.109+353', '0.42.110+354', '0.42.111+355', '0.42.112+356', '0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362', '0.42.119+363', '0.42.120+364', '0.42.121+365', '0.42.122+366', '0.42.123+367', '0.42.124+368', '0.42.125+369', '0.42.126+370', '0.42.127+371', '0.42.128+372', '0.42.129+373', '0.42.130+374', '0.42.131+375', '0.42.132+376', '0.42.133+377', '0.42.134+378', '0.42.135+379', '0.42.136+380', '0.42.137+381'])
print('v04266 bounded recall, explicit-only expansion and optional expression hints wired')
