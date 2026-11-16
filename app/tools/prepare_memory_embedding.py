"""Fetch pinned offline model assets for packaging; never runs on the user's phone."""
import hashlib
from pathlib import Path
import urllib.request

REV = '75c43b069aac4d136ba6bc1122f995fedcfd2781'
FILES = {
    'model.onnx': ('onnx/model_quantized.onnx', '15b717c382bcb518ba457b93ea6850ede7f4f1cd8937454aa06972366cd19bcc'),
    'tokenizer.json': ('tokenizer.json', '48cea5d44424912a6fd1ea647bf4fe50b55ab8b1e5879c3275f80e339e8fae26'),
}
ROOT = Path(__file__).resolve().parents[1] / 'android/app/src/main/assets/memory_embedding'
ROOT.mkdir(parents=True, exist_ok=True)
license_file = Path(__file__).resolve().parents[1] / 'docs/reference/bge_LICENSE.txt'
(ROOT / 'LICENSE.txt').write_bytes(license_file.read_bytes())
for name, (remote, expected) in FILES.items():
    target = ROOT / name
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
        continue
    url = f'https://huggingface.co/Xenova/bge-small-zh-v1.5/resolve/{REV}/{remote}'
    with urllib.request.urlopen(url, timeout=120) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise RuntimeError(f'Unexpected model asset hash: {name}')
    tmp = target.with_suffix('.tmp')
    tmp.write_bytes(data)
    tmp.replace(target)
    print(f'Verified offline asset: {name} ({len(data)} bytes)')

if __name__ == '__main__':
    import sys
    import zipfile
    if len(sys.argv) == 3 and sys.argv[1] == '--verify-apk':
        with zipfile.ZipFile(sys.argv[2]) as apk:
            for name, (_, expected) in FILES.items():
                data = apk.read(f'assets/memory_embedding/{name}')
                if hashlib.sha256(data).hexdigest() != expected:
                    raise RuntimeError(f'APK model asset mismatch: {name}')
            if apk.read('assets/memory_embedding/LICENSE.txt') != license_file.read_bytes():
                raise RuntimeError('APK model license missing or changed')
        print('Packaged offline embedding assets verified')
