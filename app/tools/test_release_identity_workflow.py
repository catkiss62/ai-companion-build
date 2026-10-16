"""Exercise the actual release shell steps with isolated command fakes.

No GitHub access or real signing material is used. Real key/APK cryptographic
verification remains the build workflow's job.
"""
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/build-apk.yml'
CERT = '30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48'
OTHER = ':'.join(['AA'] * 32)


def step(prefix):
    lines = WORKFLOW.read_text().splitlines()
    start = next(i for i, line in enumerate(lines)
                 if line.strip().startswith('- name: ' + prefix))
    body = next(i for i in range(start + 1, len(lines))
                if lines[i].strip() == 'run: |') + 1
    out = []
    for line in lines[body:]:
        if line and not line.startswith('          '):
            break
        out.append(line[10:])
    assert out
    return '\n'.join(out)


FAKE = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
name = Path(sys.argv[0]).name
scenario = os.environ['CASE']
cert = os.environ['CERT']
other = os.environ['OTHER']
with open(os.environ['CALL_LOG'], 'a') as log:
    log.write(json.dumps([name, *args]) + '\n')
if name == 'keytool':
    assert '-genkeypair' not in args, 'must never create a replacement identity'
    if scenario == 'bad_password': sys.exit(1)
    print('  SHA256: ' + (other if scenario == 'wrong_pair' else cert))
elif name == 'apksigner':
    if scenario == 'invalid_apk': sys.exit(1)
    actual = other if scenario == 'wrong_apk' else cert
    print('Signer #1 certificate SHA-256 digest: ' + actual.replace(':', '').lower())
elif name == 'aapt':
    package = 'wrong.package' if scenario == 'wrong_package' else 'com.aicompanion.localfirst'
    version = '0.42.103' if scenario == 'wrong_version' else '0.42.109'
    code = '347' if scenario == 'wrong_code' else '353'
    print(f"package: name='{package}' versionCode='{code}' versionName='{version}'")
elif name == 'gh':
    if args[:2] == ['release', 'view']:
        created = Path(os.environ['CREATED'])
        if scenario == 'new_draft' and not created.exists(): sys.exit(1)
        if '--json' in args:
            field = args[args.index('--json') + 1]
            if field == 'isDraft':
                print('false' if scenario == 'published' else 'true')
            elif field == 'url': print('https://example.invalid/test-draft')
            else: raise AssertionError(field)
    elif args[:2] == ['release', 'create']:
        assert '--draft' in args
        Path(os.environ['CREATED']).touch()
    elif args[:2] in (['release', 'edit'], ['release', 'upload']):
        assert scenario != 'published', 'published release mutated'
    elif args and args[0] == 'api':
        endpoint = next(arg for arg in args if arg.startswith('/repos/'))
        if endpoint.endswith('/releases?per_page=100'):
            if scenario == 'lookup_error': sys.exit(1)
            if scenario != 'missing_release':
                print('11\n12' if scenario == 'duplicate_release' else '11')
        elif '/releases/11/assets?' in endpoint:
            query = args[args.index('--jq') + 1]
            if scenario != 'missing_asset': print('21' if '.p12' in query else '22')
        elif '/releases/assets/' in endpoint:
            if scenario == 'download_error': sys.exit(1)
            if endpoint.endswith('/21'): print('synthetic signing fixture')
            else:
                digest = other if scenario in {'wrong_pair', 'wrong_info'} else cert
                print('sha256=' + digest)
        elif '/actions/runs/' in endpoint:
            print('{"jobs": []}')
        elif '/contents/' in endpoint:
            print('monitor-sha')
        else: raise AssertionError(endpoint)
    else: raise AssertionError(args)
else: raise AssertionError(name)
'''


def run(script, scenario, expect_success, kind):
    with tempfile.TemporaryDirectory(prefix='release-gate-') as temporary:
        base = Path(temporary)
        binary = base / 'bin'
        binary.mkdir()
        android = base / 'android/build-tools/35.0.0'
        android.mkdir(parents=True)
        for name in ('gh', 'keytool', 'apksigner', 'aapt'):
            path = (android if name in {'apksigner', 'aapt'} else binary) / name
            path.write_text(FAKE)
            path.chmod(0o755)
        apk = base / 'app/build/app/outputs/flutter-apk/app-release.apk'
        apk.parent.mkdir(parents=True)
        apk.write_bytes(b'synthetic APK')
        (base / 'app/pubspec.yaml').write_text('version: 0.42.109+353\n')
        (base / 'app/app-release.apk.sha256').write_text('fixture  app/build/app/outputs/flutter-apk/app-release.apk\n')
        env = {**os.environ, 'PATH': str(binary) + os.pathsep + os.environ['PATH'],
               'CASE': scenario, 'CERT': CERT, 'OTHER': OTHER,
               'CALL_LOG': str(base / 'calls'), 'CREATED': str(base / 'created'),
               'RUNNER_TEMP': str(base), 'GITHUB_ENV': str(base / 'env'),
               'GITHUB_REPOSITORY': 'fixture/project', 'GITHUB_RUN_ID': '1',
               'GITHUB_SERVER_URL': 'https://example.invalid', 'GITHUB_SHA': 'fixture-head',
               'AI_COMPANION_SIGNING_PASSWORD': 'synthetic-password',
               'AI_COMPANION_SIGNER_SHA256': OTHER if scenario == 'wrong_apk_pair' else CERT,
               'ANDROID_HOME': str(base / 'android'), 'BUILD_RESULT': 'failure'}
        if scenario == 'wrong_apk_pair': env['CASE'] = 'wrong_apk'
        result = subprocess.run(['bash', '-c', script], cwd=base, env=env,
                                capture_output=True, text=True, timeout=15)
        assert (result.returncode == 0) == expect_success, (kind, scenario, result.stdout, result.stderr)
        calls = [json.loads(line) for line in (base / 'calls').read_text().splitlines()]
        if kind == 'signer':
            assert not any('-genkeypair' in call or call[1:3] in
                           (['release', 'create'], ['release', 'upload']) for call in calls)
            assert (base / 'env').exists() == expect_success
        if kind == 'release':
            mutations = [call for call in calls if call[1:3] in
                         (['release', 'edit'], ['release', 'upload'])]
            if scenario == 'published': assert not mutations
            else: assert any(call[1:3] == ['release', 'upload'] for call in mutations)


def main():
    restore = step('Restore the existing persistent private test signing identity')
    verify = step('Verify stable APK signing identity')
    package = step('Verify actual APK package and version')
    # Match the release step by its stable purpose, independent of version.
    name = next(line.strip()[8:] for line in WORKFLOW.read_text().splitlines()
                if line.strip().startswith('- name: Upload v') and 'to draft release' in line)
    publish = step(name)
    failure = step('Publish failed-job diagnostics to the private draft release')
    count = 0
    for scenario in ('good', 'missing_release', 'duplicate_release', 'lookup_error',
                     'missing_asset', 'download_error', 'bad_password', 'wrong_info', 'wrong_pair'):
        run(restore, scenario, scenario == 'good', 'signer'); count += 1
    for scenario in ('good', 'wrong_apk', 'wrong_apk_pair', 'invalid_apk'):
        run(verify, scenario, scenario == 'good', 'apk'); count += 1
    for scenario in ('good', 'wrong_package', 'wrong_version', 'wrong_code'):
        run(package, scenario, scenario == 'good', 'package'); count += 1
    for script in (publish, failure):
        for scenario in ('good', 'new_draft', 'published'):
            run(script, scenario, scenario != 'published', 'release'); count += 1
    print(f'{count} isolated release identity/workflow cases passed; no live keys or network used.')


if __name__ == '__main__':
    main()
