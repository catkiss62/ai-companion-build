"""Negative identity fixtures and execution of the workflow's actual scope shell."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from validate_current_ledger_handoff import CURRENT, ROOT, validate_current
from test_release_identity_workflow import step


class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.put(CURRENT, '# Ledger\n## 当前接班快照\n<!-- CURRENT_SOURCE_IDENTITY -->\n```json\n{"app_version":"0.42.195+439","schema":67}\n```\n<!-- END_CURRENT_SOURCE_IDENTITY -->\n')
        self.put('app/pubspec.yaml', 'version: 0.42.195+439\n')
        self.db = 'app/lib/core/database/app_database.dart'
        self.self_reader = 'app/lib/core/agent/agent_self_reader.dart'
        self.put(self.db, '// static const int schemaVersion = 62;\nstatic const int schemaVersion = 67;\n')
        self.put(self.self_reader, "// buildLabel = 'v0.1.0+1'\nstatic const buildLabel = 'v0.42.195+439';\n")
        for name in ['README.md','app/README.md','AI_START_HERE.md','app/docs/BUILDING.md','app/docs/DOCUMENTATION_MAP.md','app/docs/maintenance/INDEX.md']:
            target = os.path.relpath(self.root/CURRENT, (self.root/name).parent)
            self.put(name, f'[当前总账]({target})\n')

    def put(self, path, text):
        p = self.root/path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def check(self):
        with contextlib.redirect_stdout(io.StringIO()):
            validate_current(self.root)

    def test_valid_with_historical_comment(self):
        self.check()

    def test_wrong_actual_schema_despite_matching_comment(self):
        self.put(self.db, '// static const int schemaVersion = 67;\nstatic const int schemaVersion = 68;\n')
        with self.assertRaisesRegex(AssertionError, 'current schema'):
            self.check()

    def test_block_comment_is_not_declaration(self):
        self.put(self.db, '/*\nstatic const int schemaVersion = 67;\n*/\n')
        with self.assertRaisesRegex(AssertionError, 'schemaVersion'):
            self.check()

    def test_multiline_string_is_not_declaration(self):
        self.put(self.db, '"""\nstatic const int schemaVersion = 67;\n"""')
        with self.assertRaisesRegex(AssertionError, 'schemaVersion'):
            self.check()

    def test_duplicate_real_declaration(self):
        self.put(self.db, 'static const int schemaVersion = 67;\nstatic const int schemaVersion = 67;\n')
        with self.assertRaisesRegex(AssertionError, 'exactly one'):
            self.check()

    def test_wrong_pubspec(self):
        self.put('app/pubspec.yaml', 'version: 0.42.196+440\n')
        with self.assertRaisesRegex(AssertionError, 'current version'):
            self.check()

    def test_wrong_self_reader(self):
        self.put(self.self_reader, "static const buildLabel = 'v0.42.194+438';\n")
        with self.assertRaisesRegex(AssertionError, 'current version'):
            self.check()

    def test_identity_only_in_history_rejected(self):
        text = (self.root/CURRENT).read_text().replace('<!-- CURRENT_SOURCE_IDENTITY -->', '## 历史\n<!-- CURRENT_SOURCE_IDENTITY -->')
        self.put(CURRENT, text)
        with self.assertRaisesRegex(AssertionError, 'markers'):
            self.check()

    def test_old_entry_before_current_rejected(self):
        self.put('README.md', '[旧总账](app/docs/ledger/AI_Companion_总账_v3.md)\n' + (self.root/'README.md').read_text())
        with self.assertRaisesRegex(AssertionError, 'first ledger link'):
            self.check()

    def test_broken_card_link(self):
        self.put('app/docs/maintenance/CARD.md', '[source](../../lib/missing.dart)')
        with self.assertRaisesRegex(AssertionError, 'missing/outside'):
            self.check()

    def test_repository_current(self):
        with contextlib.redirect_stdout(io.StringIO()):
            validate_current(ROOT)


class WorkflowScopeTests(unittest.TestCase):
    def scope(self, files, api_fail=False):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            gh = p/'gh'
            gh.write_text('#!/bin/sh\n' + ('exit 1\n' if api_fail else 'cat "$SCOPE_FILES"\n'))
            gh.chmod(0o755)
            (p/'files').write_text('\n'.join(files)+'\n' if files else '')
            (p/'event').write_text(json.dumps({'head_commit': {'message': 'maintenance'}}))
            env = dict(os.environ, PATH=str(p)+os.pathsep+os.environ['PATH'], SCOPE_FILES=str(p/'files'), GITHUB_EVENT_PATH=str(p/'event'), GITHUB_OUTPUT=str(p/'output'), GITHUB_STEP_SUMMARY=str(p/'summary'), EVENT_NAME='push', EVENT_ACTION='', BEFORE_SHA='a'*40, AFTER_SHA='b'*40, GITHUB_REPOSITORY='test/repo')
            result = subprocess.run(['bash','-c',step('Decide whether this event needs')], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return (p/'output').read_text()

    def test_current_root_docs_are_lightweight(self):
        self.assertIn('reason=documentation_only', self.scope(['AI_START_HERE.md','AGENTS.md','app/docs/maintenance/CHAT.md']))

    def test_mixed_source_requires_build(self):
        self.assertIn('run-full-build=true', self.scope(['AI_START_HERE.md','app/lib/app.dart']))

    def test_tool_or_workflow_change_requires_build(self):
        for path in ['app/tools/validate_current_ledger_handoff.py','.github/workflows/documentation-validation.yml']:
            with self.subTest(path=path):
                self.assertIn('run-full-build=true', self.scope([path]))

    def test_api_failure_requires_build(self):
        self.assertIn('reason=compare_api_failed', self.scope([], api_fail=True))

    def test_empty_range_requires_build(self):
        self.assertIn('reason=empty_compare_result', self.scope([]))


if __name__ == '__main__':
    unittest.main()
