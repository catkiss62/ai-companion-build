"""Reproduce the original fixed benchmark with its own evaluator and frozen inputs."""
import argparse
from dataclasses import asdict
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from io import BytesIO

REVISION = '4ae154ba5b763a86fdc8a546152be1bd45f65416'
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('checkout', type=Path)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
checkout = args.checkout.resolve()
def git(*cmd):
    return subprocess.check_output(['git', '-C', str(checkout), *cmd], text=True).strip()
if git('rev-parse', 'HEAD') != REVISION or git('status', '--porcelain', '--untracked-files=no'):
    raise SystemExit('Expected a clean pinned SeekMemory checkout')
run = subprocess.run([sys.executable, 'benchmarks/run.py'], cwd=checkout,
                     capture_output=True, text=True, check=True)
result = json.loads(run.stdout.strip().splitlines()[-1])
report = json.loads((Path(result['output']) / 'memory.json').read_text())
assert result['acceptance']['passed']
sys.path.insert(0, str(checkout))
from benchmarks.dataset import build
from benchmarks.memory_corpus import ANCHOR, CONFIG
events, queries = build()
fixture = {'repository': 'NeverENG/SeekMemory', 'revision': REVISION, 'entry': 'benchmarks/run.py',
           'clock': ANCHOR.isoformat(), 'config': CONFIG, 'events': list(map(asdict, events)),
           'queries': list(map(asdict, queries)), 'acceptance':result['acceptance'],
           'reference':json.loads((checkout/'benchmarks/data/memory_baseline.json').read_text())}
for path, content in [('seekmemory.json', json.dumps(fixture, ensure_ascii=False, indent=2)+'\n'),
                      ('LICENSE-MIT.txt', (checkout/'LICENSE-MIT').read_text())]:
    target = ROOT/'assets/memory_benchmark'/path
    if args.check:
        assert target.read_text() == content, path
    else:
        target.write_text(content)

# Include every file which participates in either upstream digest.
names = [f for root in ("core","app","services","store","perceive","recall","maintain")
         for f in (checkout/root).rglob("*.py")]
names += [checkout/"benchmarks"/f for f in ("__init__.py","run.py","dataset.py","memory_corpus.py",
          "memory_execution.py","memory_metrics.py","memory_reporting.py","memory_target.py",
          "retrieval_compare.py","data/memory_baseline.json")]
names += [checkout/"store/schema.sql", checkout/"LICENSE-MIT", checkout/"LICENSE-APACHE"]
archive = BytesIO()
with zipfile.ZipFile(archive,"w") as z:
    for f in sorted(names):
        info = zipfile.ZipInfo(f.relative_to(checkout).as_posix())
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, f.read_bytes())
target = ROOT/"android/app/src/main/assets/seekmemory-original.zip"
if args.check:
    assert target.read_bytes() == archive.getvalue()
else:
    target.write_bytes(archive.getvalue())
