#!/usr/bin/env python3
"""Guard bounded, lossless settings reads and the approved daytime asset."""
from pathlib import Path
import hashlib
import json
import re
import sqlite3
import subprocess
import tempfile

app = Path(__file__).resolve().parents[1]
reader = (app / 'lib/core/database/sqlite_settings_reader.dart').read_text()
database = (app / 'lib/core/database/app_database.dart').read_text()
get_setting = database.split('Future<String?> getSetting(String key)', 1)[1].split(
    'Future<void> setSetting', 1)[0]
export = database.split('Future<Map<String, Object?>> exportAll()', 1)[1].split(
    'Future<void> importAll', 1)[0]
assert 'SqliteSettingsReader.read(db, key)' in get_setting
assert "table == 'settings'" in export
assert 'SqliteSettingsReader.readAll(txn)' in export
assert 'db.transaction<Map<String, Object?>>' in export
for token in ('executor.transaction', 'BytesBuilder', 'utf8.decode(bytes.takeBytes())',
              'part.length != count', 'offset + 1'):
    assert token in reader, token

# Execute the exact production projection and chunk SQL. In particular, neither
# length(TEXT) nor decoding each chunk is safe for NUL/multibyte boundaries.
projection_section = reader.split('static const _projection =', 1)[1].split(';', 1)[0]
projection = ''.join(re.findall(r"'([^']*)'", projection_section))
chunk_section = reader.split('final parts = await executor.rawQuery(', 1)[1].split(
    '<Object?>', 1)[0]
chunk_sql = ''.join(re.findall(r"'([^']*)'", chunk_section))
chunk_bytes = 64 * 1024
value = '汉🙂\0尾' * 350_000 + '🧭结束'
original = {'large': value, 'small': '保留', 'empty': ''}
db = sqlite3.connect(':memory:')
db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
db.executemany('INSERT INTO settings VALUES(?,?)', original.items())
restored = {}
for key, length, first in db.execute(projection + ' ORDER BY key', (chunk_bytes,)):
    if length == 0:
        restored[key] = ''
        continue
    assert len(first) <= chunk_bytes
    output = bytearray(first)
    while len(output) < length:
        count = min(chunk_bytes, length - len(output))
        part = db.execute(chunk_sql, (len(output) + 1, count, key)).fetchone()[0]
        assert len(part) == count
        output.extend(part)
    restored[key] = output.decode('utf-8')
assert restored == original
assert json.loads(json.dumps(restored, ensure_ascii=False)) == original
assert len(value.encode()) > 3 * 1024 * 1024

asset = app / 'assets/lingchat/background/day.webp'
day_sha = '6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7'
assert hashlib.sha256(asset.read_bytes()).hexdigest() == day_sha
assert asset.read_bytes()[:4] == b'RIFF' and asset.read_bytes()[8:12] == b'WEBP'
# Exercise the actual fetch function with network commands blocked. The valid
# derivative must survive restoration; damaged/missing copies must fail closed.
fetch = (app / 'tools/fetch_lingchat_visual_assets.sh').read_text()
function = fetch[fetch.index('download_lfs() {'):fetch.index('\nwhile IFS=')]
shell = ('set -euo pipefail\n' + function + '\nASSET_ROOT="$1"\n'
         'curl() { return 77; }\njq() { return 78; }\n'
         'download_lfs "data/game_data/backgrounds/白天.webp" '
         '"$ASSET_ROOT/background/day.webp"\n')
with tempfile.TemporaryDirectory() as directory:
    copy = Path(directory) / 'background/day.webp'
    copy.parent.mkdir()
    copy.write_bytes(asset.read_bytes())
    result = subprocess.run(['bash', '-c', shell, 'restore-test', directory],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert hashlib.sha256(copy.read_bytes()).hexdigest() == day_sha
    copy.write_bytes(b'wrong day image')
    result = subprocess.run(['bash', '-c', shell, 'restore-test', directory],
                            capture_output=True, text=True)
    assert result.returncode == 1 and 'hash mismatch' in result.stderr
    copy.unlink()
    result = subprocess.run(['bash', '-c', shell, 'restore-test', directory],
                            capture_output=True, text=True)
    assert result.returncode == 1 and 'missing' in result.stderr
workflow = (app.parent / '.github/workflows/build-apk.yml').read_text()
assert "hashlib.sha256(z.read(reviewed_day)).hexdigest()" in workflow
assert day_sha in workflow
assert (app / 'test/sqlite_settings_backup_v04255_test.dart').is_file()
assert (app / 'tools/caicai_smoke/src/androidTest/java/com/catkiss/'
        'senlive2dcompanion/smoke/SettingsCursorWindowSmokeTest.kt').is_file()
assert 'version: 0.42.55+299' in (app / 'pubspec.yaml').read_text()
print('v0.42.55 bounded settings: 3.85 MiB Unicode/NUL SQL roundtrip and day asset OK')
