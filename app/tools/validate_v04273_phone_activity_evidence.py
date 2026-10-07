from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
evidence = read('lib/core/presence/phone_activity_evidence.dart')
presence = read('lib/core/presence/presence_intelligence.dart')
perception = read('lib/core/perception/perception_engine.dart')
assert any(f'version: {v}' in read('pubspec.yaml') for v in ['0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327'])
assert 'PhoneActivityEvidence.collect(' in perception
assert 'screenInteractive && !deviceLocked' in perception
assert 'evidence: phoneEvidence' in perception
assert 'presence_observed_minutes_v317' in perception
assert 'observedMinutes >= 35' in perception
assert 'now: now' in perception
assert 'screen_session_changed' in evidence and 'capture_baseline' in evidence
assert 'event.timestamp.isAfter(previousAt)' in evidence
assert "event['source'] == 'accessibility'" in evidence
assert 'fresh.activeMinutes' in presence and 'fresh.switches' in presence
assert 'impulse > 0' in presence and '!fresh.reset' in presence
assert 'retirePhoneActivityThoughts' in presence
assert "t.source == 'presence/phone_activity'" in presence
assert "t.topicKey.startsWith('usage:')" in presence
assert 'residualStrength: 0' in presence
assert 'presence_last_evidence' in read('lib/core/diagnostics/preflight_diagnostics.dart')
assert 'test/phone_activity_evidence_v04273_test.dart' in (r.parent / '.github/workflows/stability-checks.yml').read_text()
print('v04273: new evidence intervals, baseline/reset scope, lock boundary and diagnostics OK')
