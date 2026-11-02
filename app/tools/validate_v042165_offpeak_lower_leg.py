"""Source ownership wiring; behavior is covered by focused Dart/JVM/Android tests."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text()
worker = read('lib/core/creative/creative_worker.dart')
assert worker.index('CreativeWorkspace.hasPendingTools') < worker.index('archive: false')
assert worker.count('BackgroundCostPolicy.deferredUntil') == 2
assert worker.index("if ((agent['pending'] as List).isEmpty)") < worker.rindex('BackgroundCostPolicy.deferredUntil')
summary = read('lib/core/database/conversation_summary_store.dart')
assert 'static Future<bool> settleEmptyScan' in summary
assert 'if (!await workFence.matches(txn)) return false' in summary
assert "'value': remaining.isNotEmpty ? '1' : ''" in summary
assert 'ConversationSummaryStore.settleEmptyScan(txn, workFence: fence)' in read('lib/core/ai/memory_extractor.dart')
java = 'android/app/src/main/java/com/catkiss/senlive2dcompanion/'
assert 'withSmallFormAnchor(mapped,liveLegs,pivot,form)' in read(java+'DeepseekAvatarModel.java')
assert 'weight=weight*weight*(3-2*weight)' in read(java+'DeepseekLegPivot.java')
assert 'offpeak_recovery_v042165_test.dart' in (root.parent/'.github/workflows/system-logic-validation.yml').read_text()
print('v042165 paid/local separation, atomic scan continuation and small-form axis wiring passed')
