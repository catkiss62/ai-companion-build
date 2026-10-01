"""Protect settings-only export, old resource import, and all share exits."""
from pathlib import Path
import re

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
storage = read('lib/core/storage/portable_companion_storage.dart')
export = storage.split('Future<PortableExport> exportTo(', 1)[1].split('static Map<String, dynamic> validateState', 1)[0]
assert "'resource_files': 'external'" in export
assert "'version': 2" in export
assert '.list(' not in export and '.copy(' not in export
assert 'restoreModels: includesResourceFiles(state)' in storage
assert 'if (includesResourceFiles(state))' in storage
assert 'if (_reloadAfterFinish.remove(snapshot.token))' in storage
native = read('android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt')
assert 'if (restoreModels)' in native and 'if (modelsTouched && commit)' in native
engine = read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
tail = engine.split('if (sustained) {\n          final after =', 1)[1].split('return step;', 1)[0]
assert 'deferContinuation' not in tail
proactive = read('lib/core/desire/proactive_engine.dart')
assert proactive.count('if (isCedarGameShare && !await CedarLiveSharePolicy(db)') == 2
assert 'messageId: message.id' in proactive
assert "version: 0.42.59+303" in read('pubspec.yaml')
assert (app / 'test/cedar_cadence_regression_v04259_test.dart').is_file()
print('v0.42.59 settings-only export, legacy resource import and unified game sharing wired')
