"""Isolated model dialogue room wiring and exact user-supplied background."""
from pathlib import Path
from hashlib import sha256
root=Path(__file__).resolve().parents[1]
read=lambda p:(root/p).read_text()
core=[read('lib/core/model_dialogue/'+name+'.dart') for name in (
    'model_dialogue_models','model_dialogue_repository','model_dialogue_prompt',
    'model_dialogue_gateway','model_dialogue_controller')]
# +358 authorizes shared memory and explicit end-of-room archiving. Participant
# gateway isolation remains mandatory; ordinary extraction/worldbooks stay out.
for s in core:
    for forbidden in ("import '../relationship/", "import '../personality/",
                      "import '../immersive/", 'applyPostTurnThought', 'jsonCompletion('):
        assert forbidden not in s,forbidden
repo,prompt,gateway,controller=core[1:]
assert 'SqliteSettingsReader.read' in repo and 'ticket.fence.matches(txn)' in repo
assert 'room.requestId!=ticket.requestId' in repo
assert 'cancellation.isCancelled' in repo and 'beforeCommit' in repo
assert "'model_dialogue_room_v1:'" in repo and "'model_dialogue_message_v1:'" in repo
assert 'import' not in prompt.replace("import 'dart:convert';",'').replace("import 'model_dialogue_models.dart';",'')
assert 'attempt<=2' in gateway and gateway.count('client.streamChat(')==1
for name in ('endpoint.apiKey','endpoint.endpoint','endpoint.model','endpoint.provider'):
    assert name in gateway,name
assert 'FinalReplyRoute(' not in gateway and 'fallback' not in gateway.lower().split('class modeldialoguegateway')[1]
assert 'readDeepSeekApiKey()' in gateway and 'readAiWangYouApiKey()' in gateway
assert "'chat_turn_lease'" in controller and 'cancelTicket' in controller
page=read('lib/features/model_dialogue/model_dialogue_page.dart')
assert 'Live2D' not in page and 'ChatPortraitStage' not in page
assert 'setImmersiveChatPageVisible(true)' in page and 'setImmersiveChatPageVisible(false)' in page
assert "'assets/model_dialogue/background.jpg'" in page
assert sha256((root/'assets/model_dialogue/background.jpg').read_bytes()).hexdigest()=='2108cb1b63383f26dd5414a805c1bace8fd72d37790cbbb885d55f194da75e63'
chat=read('lib/features/chat/chat_page.dart')
assert chat.count("title: const Text('模型对谈')")==1
assert chat.count("title: '模型对谈'")==1
workflow=(root.parent/'.github/workflows/system-logic-validation.yml').read_text()
for test in ('model_dialogue_v042113_test.dart','model_dialogue_page_v042113_test.dart'):
    assert test in workflow
assert any(v in read('pubspec.yaml') for v in ('version: 0.42.114+358','version: 0.42.115+359', 'version: 0.42.116+360'))
assert '    - assets/model_dialogue/' in read('pubspec.yaml')
print('isolated model dialogue, fixed same-model retry, lifecycle fences and exact background wired')
