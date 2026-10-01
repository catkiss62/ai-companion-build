"""Guard the limited wiring changes and execute the production pointer module."""
from pathlib import Path
import subprocess

app = Path(__file__).resolve().parents[1]
storage = (app / 'lib/core/storage/portable_companion_storage.dart').read_text()
assert '_reloadAfterFinish.add(snapshot.token)' in storage
assert 'if (_reloadAfterFinish.remove(snapshot.token))' in storage
assert storage.index('_reloadAfterFinish.add(snapshot.token)') < storage.index("'portableApply'")
chat = (app / 'lib/features/chat/chat_page.dart').read_text()
panel = chat.split('Future<void> _openQuickPanel() async {', 1)[1]
assert panel.index('inputFocus.unfocus(disposition: UnfocusDisposition.scope)') < panel.index('await')
html = (app / 'assets/memory_galaxy/index.html').read_text()
assert "from './memory_interaction.js'" in html
assert 'memorySelection.cancel();' in html
assert 'ray.intersectObject(memPoints)' in html
assert 'nearestProjectedMemory(' in html
assert 'projectedMemories()' in html
assert (app / 'test/portable_live2d_refresh_v04258_test.dart').is_file()
result = subprocess.run(['node', str(app / 'tools/test_memory_interaction_v04258.mjs')],
                        capture_output=True, text=True)
assert result.returncode == 0, result.stdout + result.stderr
print('v0.42.58 read-only export refresh, editor unfocus, five colors and 13 pointer tests: OK')
