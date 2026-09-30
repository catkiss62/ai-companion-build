"""Check the offline module/font dependency closure and read-only page wiring.

Database, lifecycle and native path behavior are exercised by real runtime tests.
"""
from pathlib import Path
import json
import re
import subprocess

app = Path(__file__).resolve().parents[1]
root = app / 'assets/memory_galaxy'
tracked = set(subprocess.check_output(
    ['git', 'ls-files', '-z', '--', 'app/assets/memory_galaxy'], cwd=app.parent,
).decode().split('\0'))
for asset in root.rglob('*'):
    if asset.is_file():
        assert asset.relative_to(app.parent).as_posix() in tracked, f'Untracked offline asset: {asset}'
html = (root / 'index.html').read_text()
imports = json.loads(re.search(r'<script type="importmap">(.*?)</script>', html, re.S)[1])['imports']
assert imports['three'] == './vendor/three/build/three.module.js'
assert imports['three/addons/'] == './vendor/three/examples/jsm/'
assert 'cdn.jsdelivr.net' not in html
assert 'demo01' not in html and 'memory-data' not in html
assert 'if (!stars.length) return;' in html
assert "Array.isArray(d.stars)" in html
assert 'window.galaxyPause' in html and 'cancelAnimationFrame(frameId)' in html
assert 'document.getElementById(\'cBody\').textContent=s.content' in html
assert 'N=14000' in html and 'N=6400' in html

visited = set()
def module_closure(file):
    file = file.resolve()
    assert file.is_relative_to(root.resolve()), file
    if file in visited:
        return
    assert file.is_file(), f'Missing offline module: {file}'
    visited.add(file)
    source = file.read_text()
    for spec in re.findall(r"(?:from\s*|import\s*)['\"]([^'\"]+)['\"]", source):
        if spec == 'three':
            target = root / imports[spec]
        elif spec.startswith('three/addons/'):
            target = root / imports['three/addons/'] / spec[len('three/addons/'):]
        else:
            assert spec.startswith('.'), f'External import: {spec}'
            target = file.parent / spec
        module_closure(target)
for spec in re.findall(r"from\s*['\"]([^'\"]+)['\"]", html):
    module_closure(root / (imports[spec] if spec == 'three' else
        imports['three/addons/'] + spec[len('three/addons/'):]))
font_css = list((root / 'vendor/fonts').glob('*.css'))
assert font_css
assert len(re.findall(r'@font-face', ''.join(p.read_text() for p in font_css))) >= 3
for css in font_css:
    for font in re.findall(r'url\([\'\"]?([^\)\'\"]+)', css.read_text()):
        target = (css.parent / font).resolve()
        assert target.is_relative_to(root.resolve()), font
        assert target.is_file(), font

native = (app / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeMemoryGalaxyActivity.kt').read_text()
assert 'addJavascriptInterface' not in native
assert 'settings.allowFileAccess = false' in native
assert 'galaxy.destroy()' in native
launcher = (app / 'lib/core/platform/memory_galaxy.dart').read_text()
assert '.allActive()' in launcher and 'relevantMemories' not in launcher
assert 'finally' in launcher and 'snapshot.delete()' in launcher
assert 'TickerMode(' in (app / 'lib/app.dart').read_text()
print(f'v0.42.57 offline galaxy closure: {len(visited)} modules; read-only entry/lifecycle wired')
