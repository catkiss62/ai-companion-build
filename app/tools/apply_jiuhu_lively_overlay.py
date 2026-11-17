#!/usr/bin/env python3
"""Apply the private lively-only reference overlay before normal APK curation.

The encrypted archive is reproducible from the pinned, private runtime APK.
No key, recording or model checkpoint is published in the source repository.
Keep the base manifest version: existing per-file integrity checks replace only
changed prompt assets, without copying another full acoustic model on upgrade.
"""
import argparse
import hashlib
import hmac
import io
import json
import math
import struct
import subprocess
import wave
import zipfile
from pathlib import Path

BASE_APK_SHA256 = 'af90aeaf84afdb383bd71584a5512609666c9af38110ea192ebde6f2c84ceb43'
# Match the preparation workflow's literal backslash + zero prefix, not NUL.
DOMAIN = bytes([0x5c, 0x30]) + b'jiuhu-lively-overlay-v1'
MAGIC = b'JHLIVELY1'
NAMES = {'ref_seq', 'ref_bert', 'ssl_content', 'ref_audio', 'ge', 'ge_advanced'}
ALLOWED = {'patch.json', 'references/jiuhu_idle50.wav'} | {
    f'tensors/jiuhu_idle50_{name}.tensor' for name in NAMES}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def key_from_apk(apk):
    source = hashlib.sha256()
    with Path(apk).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            source.update(block)
    if source.hexdigest() != BASE_APK_SHA256:
        raise ValueError('Unexpected base voice APK; keep the verified private baseline')
    source.update(DOMAIN)
    return source.digest()


def crypt(data, key, nonce):
    aes = hashlib.sha256(key + b'encryption').hexdigest()
    return subprocess.run(['openssl', 'enc', '-aes-256-ctr', '-K', aes,
        '-iv', nonce.hex()], input=data, capture_output=True, check=True).stdout


def unpack(envelope, key):
    if not envelope.startswith(MAGIC) or len(envelope) < 57:
        raise ValueError('Invalid lively overlay header')
    nonce, mac, ciphertext = envelope[9:25], envelope[25:57], envelope[57:]
    expected = hmac.new(hashlib.sha256(key+b'authentication').digest(),
        MAGIC+nonce+ciphertext, hashlib.sha256).digest()
    if not hmac.compare_digest(mac, expected):
        raise ValueError('Lively overlay authentication failed')
    with zipfile.ZipFile(io.BytesIO(crypt(ciphertext, key, nonce))) as archive:
        entries = archive.infolist()
        if len(entries) != len(ALLOWED) or {e.filename for e in entries} != ALLOWED:
            raise ValueError('Overlay must contain only the lively reference and its six tensors')
        if any(e.file_size > 2_000_000 for e in entries):
            raise ValueError('Oversize reference payload')
        return {e.filename: archive.read(e) for e in entries}


def apply(root, files):
    root = Path(root)
    path = root/'manifest.json'
    original = path.read_bytes()
    patch = json.loads(files['patch.json'])
    if digest(original) != patch['base_manifest_sha256']:
        raise ValueError('Base voice manifest has changed')
    manifest = json.loads(original)
    cases = manifest['cases']
    matches = [i for i,c in enumerate(cases) if c['id'] == 'jiuhu_idle50']
    if len(matches) != 1:
        raise ValueError('Expected exactly one original lively candidate')
    old = cases[matches[0]]
    case = patch['case']
    if case['id'] != old['id'] or case['reference_audio'] != old['reference_audio']:
        raise ValueError('Cannot reroute another voice')
    if set(case) != set(old) or any(case[k] != old[k] for k in old
            if k not in {'reference_text','tensors'}):
        raise ValueError('Only lively reference text and tensors may change')
    specs = case['tensors']
    if len(specs) != 6 or {s['name'] for s in specs} != NAMES:
        raise ValueError('Incomplete prompt tensors')
    expected_files = ALLOWED - {'patch.json'}
    if set(patch['sha256']) != expected_files:
        raise ValueError('Incomplete overlay checksums')
    for name in expected_files:
        if digest(files[name]) != patch['sha256'][name]:
            raise ValueError('Overlay checksum mismatch')
    for s in specs:
        filename = f"tensors/jiuhu_idle50_{s['name']}.tensor"
        if s['file'] != filename or s['dtype'] not in {'int64','float32'}:
            raise ValueError('Invalid prompt specification')
        shape = s['shape']
        if not shape or any(type(n) is not int or n <= 0 for n in shape):
            raise ValueError('Invalid prompt shape')
        width = 8 if s['dtype'] == 'int64' else 4
        if math.prod(shape)*width != len(files[filename]):
            raise ValueError('Prompt byte length does not match shape')
        if s['dtype'] == 'float32' and not all(math.isfinite(v[0])
                for v in struct.iter_unpack('<f', files[filename])):
            raise ValueError('Non-finite reference feature')
    with wave.open(io.BytesIO(files[case['reference_audio']])) as audio:
        if (audio.getnchannels(),audio.getsampwidth(),audio.getframerate()) != (1,2,44100):
            raise ValueError('Reference must be mono 44.1kHz PCM16')
        if not 3 <= audio.getnframes()/44100 <= 10:
            raise ValueError('Unexpected reference duration')
    # Validate the entire patch before writing anything; all other candidates,
    # presets and paired acoustic weights remain byte-for-byte untouched.
    for name in expected_files:
        (root/name).write_bytes(files[name])
        manifest['asset_integrity'][name] = {'bytes':len(files[name]), 'sha256':digest(files[name])}
    cases[matches[0]] = case
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Lively reference and six tensors updated; three other voices and model paths unchanged.')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--base-apk',type=Path,required=True)
    parser.add_argument('--root',type=Path,required=True)
    parser.add_argument('--overlay',type=Path,required=True)
    args=parser.parse_args()
    apply(args.root,unpack(args.overlay.read_bytes(),key_from_apk(args.base_apk)))


if __name__ == '__main__':
    main()
