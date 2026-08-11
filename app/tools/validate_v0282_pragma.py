from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
db = (root / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')

assert 'version: 0.28.2+30' in pubspec
assert "db.execute('PRAGMA journal_mode = WAL')" not in db
assert "db.rawQuery('PRAGMA journal_mode = WAL')" in db
assert "db.rawQuery('PRAGMA synchronous = NORMAL')" in db
assert "journalMode != 'wal'" in db

# Any journal_mode PRAGMA in Dart app code must not be sent through execute().
for path in (root / 'lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    if re.search(r"\.execute\(\s*['\"]PRAGMA\s+journal_mode", text, flags=re.I):
        raise AssertionError(f'query-returning journal_mode PRAGMA uses execute(): {path}')

print('v0.28.2 Android PRAGMA validation passed.')
