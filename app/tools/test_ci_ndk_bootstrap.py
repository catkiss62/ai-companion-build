"""Exercise fresh retries and rejection of incomplete NDK installations offline."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('bootstrap_ci_ndk.sh')
VERSIONS = ('27.2.12479018', '28.2.13676358')
FAKE = '''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(next(x.split('=', 1)[1] for x in sys.argv if x.startswith('--sdk_root=')))
revision = sys.argv[-1].split(';')[1]
log = pathlib.Path(os.environ['CI_NDK_TEST_LOG'])
events = json.loads(log.read_text()) if log.exists() else []
count = sum(x['revision'] == revision for x in events)
events.append({'root': str(root), 'revision': revision})
log.write_text(json.dumps(events))
target = root / 'ndk' / revision
target.mkdir(parents=True)
if os.environ['CI_NDK_TEST_CASE'] == 'fail' or (os.environ['CI_NDK_TEST_CASE'] == 'retry' and count == 0):
    (target / 'incomplete.zip').write_text('not a zip')
    sys.exit(1)
value = 'wrong' if os.environ['CI_NDK_TEST_CASE'] == 'wrong_revision' else revision
(target / 'source.properties').write_text('Pkg.Revision = ' + value + '\\n')
clang = target / 'toolchains/llvm/prebuilt/linux-x86_64/bin/clang'
clang.parent.mkdir(parents=True)
clang.write_text('#!/bin/sh\\nexit 0\\n')
clang.chmod(0o755)
'''


class BootstrapTest(unittest.TestCase):
    def run_case(self, case, existing=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sdk = root / 'sdk'
            (sdk / 'licenses').mkdir(parents=True)
            (sdk / 'licenses/android-sdk-license').write_text('fixture')
            other = sdk / 'ndk/keep/me'
            other.parent.mkdir(parents=True)
            other.write_text('preserve')
            fake = root / 'sdkmanager'
            fake.write_text(FAKE)
            fake.chmod(0o755)
            log = root / 'calls.json'
            env = dict(os.environ, ANDROID_SDK_ROOT=str(sdk), RUNNER_TEMP=str(root),
                       CI_NDK_SDKMANAGER=str(fake), CI_NDK_RETRY_DELAY_SECONDS='0',
                       CI_NDK_TEST_LOG=str(log), CI_NDK_TEST_CASE=case)
            if existing:
                for revision in VERSIONS:
                    subprocess.run([str(fake), '--sdk_root=' + str(sdk), '--install',
                                    'ndk;' + revision], env=env, check=True)
                log.unlink()
            result = subprocess.run(['bash', str(SCRIPT)], env=env,
                                    capture_output=True, text=True)
            calls = json.loads(log.read_text()) if log.exists() else []
            self.assertEqual(other.read_text(), 'preserve')
            self.assertFalse(list(root.glob('ai-companion-ndk-*')))
            return result, calls, [
                (sdk / 'ndk' / revision / 'source.properties').exists()
                for revision in VERSIONS]

    def test_retry_uses_fresh_directories_and_installs_both(self):
        result, calls, installed = self.run_case('retry')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([x['revision'] for x in calls], [v for v in VERSIONS for _ in range(2)])
        self.assertEqual(len({x['root'] for x in calls}), 4)
        self.assertEqual(installed, [True, True])

    def test_persistent_failure_is_bounded_and_not_installed(self):
        result, calls, installed = self.run_case('fail')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 3)
        self.assertEqual(installed, [False, False])

    def test_wrong_revision_is_rejected(self):
        result, calls, installed = self.run_case('wrong_revision')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 3)
        self.assertEqual(installed, [False, False])

    def test_verified_installed_packages_are_reused(self):
        result, calls, installed = self.run_case('success', existing=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])
        self.assertEqual(installed, [True, True])


if __name__ == '__main__':
    unittest.main()
