from pathlib import Path
app = Path(__file__).resolve().parents[1]
b = (app/'android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekAvatarModel.java').read_text()
assert 'v[i]+=dx' not in b and 'v[i+1]+=dy' not in b
assert 'morphShiftX=morphShiftY=0' in b
assert b.index('DeepseekLegPivot.translateModel') < b.index('DeepseekLegPivot.map')
assert 'rawLegPivot=' in b and 'morphShift=' in b
cache = (app/'lib/core/mcp/cedar_toy_activity.dart').read_text()
p = cache[cache.index('  String promptContext('):]
assert p.index('【完整真实指南') < p.index('【CEDAR_ACTIVITY_SESSION') < p.index('last_outcome=')
assert 'CedarSaveSlotPolicy.promptGuidance(session.guide, session.lastOutcome)' in p
assert 'background_cost_cache_v042163_test.dart' in (app.parent/'.github/workflows/system-logic-validation.yml').read_text()
assert 'CI PENDING' in (app/'docs/CACHE_OFFPEAK_MORPH_v042163.md').read_text() or 'CI PASSED' in (app/'docs/CACHE_OFFPEAK_MORPH_v042163.md').read_text()
print('v042163 cache/morph wiring passed; behavior remains covered by Dart/JVM/Android tests')
