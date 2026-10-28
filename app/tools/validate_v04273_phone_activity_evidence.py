from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda p: (r / p).read_text()
evidence = read('lib/core/presence/phone_activity_evidence.dart')
presence = read('lib/core/presence/presence_intelligence.dart')
perception = read('lib/core/perception/perception_engine.dart')
assert any(f'version: {v}' in read('pubspec.yaml') for v in ['0.42.73+317', '0.42.74+318', '0.42.75+319', '0.42.76+320', '0.42.77+321', '0.42.78+322', '0.42.79+323', '0.42.80+324', '0.42.81+325', '0.42.82+326', '0.42.83+327', '0.42.84+328', '0.42.85+329', '0.42.86+330', '0.42.87+331', '0.42.88+332', '0.42.89+333', '0.42.90+334', '0.42.91+335', '0.42.92+336', '0.42.93+337', '0.42.94+338', '0.42.95+339', '0.42.96+340', '0.42.97+341', '0.42.98+342', '0.42.99+343', '0.42.100+344', '0.42.101+345', '0.42.102+346', '0.42.103+347', '0.42.104+348', '0.42.105+349', '0.42.106+350', '0.42.107+351', '0.42.108+352', '0.42.109+353', '0.42.110+354', '0.42.111+355', '0.42.112+356', '0.42.113+357', '0.42.114+358', '0.42.115+359', '0.42.116+360', '0.42.117+361', '0.42.118+362', '0.42.119+363', '0.42.120+364', '0.42.121+365', '0.42.122+366', '0.42.123+367', '0.42.124+368', '0.42.125+369', '0.42.126+370', '0.42.127+371', '0.42.128+372', '0.42.129+373', '0.42.130+374', '0.42.131+375', '0.42.132+376', '0.42.133+377', '0.42.134+378', '0.42.135+379', '0.42.136+380', '0.42.137+381', '0.42.138+382', '0.42.139+383', '0.42.140+384', '0.42.141+385', '0.42.142+386', '0.42.143+387', '0.42.144+388', '0.42.145+389', '0.42.146+390', '0.42.147+391', '0.42.148+392', '0.42.149+393', '0.42.150+394'])
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
