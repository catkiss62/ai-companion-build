import copy
import hashlib
import hmac
import io
import json
import tempfile
import unittest
from unittest.mock import patch
import apply_jiuhu_lively_overlay as overlay
import wave
import zipfile
from pathlib import Path
from apply_jiuhu_lively_overlay import ALLOWED, MAGIC, NAMES, apply, crypt, digest, unpack

class LivelyOverlayTest(unittest.TestCase):
    def test_key_derivation_matches_preparation_domain(self):
        payload=b'private APK fixture'
        with tempfile.TemporaryDirectory() as directory:
            apk=Path(directory)/'base.apk';apk.write_bytes(payload)
            with patch.object(overlay,'BASE_APK_SHA256',hashlib.sha256(payload).hexdigest()):
                expected=hashlib.sha256(payload+bytes.fromhex('5c30')+b'jiuhu-lively-overlay-v1').digest()
                self.assertEqual(overlay.key_from_apk(apk),expected)
                apk.write_bytes(payload+b'changed')
                with self.assertRaises(ValueError):overlay.key_from_apk(apk)
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        (self.root/'references').mkdir();(self.root/'tensors').mkdir()
        self.files={}
        specs=[]
        for name in sorted(NAMES):
            file=f'tensors/jiuhu_idle50_{name}.tensor'
            dtype='int64' if name=='ref_seq' else 'float32'
            data=b'\0'*(8 if dtype=='int64' else 4)
            specs.append({'name':name,'file':file,'dtype':dtype,'shape':[1]})
            self.files[file]=data;(self.root/file).write_bytes(b'old')
        audio=io.BytesIO()
        with wave.open(audio,'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(b'\0'*(44100*3*2))
        self.files['references/jiuhu_idle50.wav']=audio.getvalue()
        (self.root/'references/jiuhu_idle50.wav').write_bytes(b'old')
        self.old={'id':'jiuhu_idle50','title':'lively','reference_audio':'references/jiuhu_idle50.wav','reference_text':'old','tensors':specs}
        self.original={'version':'unchanged','models':{'vocoder':'models/vits.onnx'},'cases':[self.old,{'id':'daily','reference_text':'keep'}],'asset_integrity':{}}
        (self.root/'manifest.json').write_text(json.dumps(self.original))
        self.patch={'base_manifest_sha256':digest((self.root/'manifest.json').read_bytes()),'case':copy.deepcopy(self.old),'sha256':{n:digest(v) for n,v in self.files.items()}}
        self.patch['case']['reference_text']='new'
        self.refresh()
    def refresh(self):self.files['patch.json']=json.dumps(self.patch).encode()
    def seal(self):
        b=io.BytesIO()
        with zipfile.ZipFile(b,'w') as z:
            for n,v in self.files.items():z.writestr(n,v)
        key=b'fixture-key';nonce=b'0'*16;c=crypt(b.getvalue(),key,nonce)
        mac=hmac.new(hashlib.sha256(key+b'authentication').digest(),MAGIC+nonce+c,hashlib.sha256).digest()
        return MAGIC+nonce+mac+c,key
    def test_authenticated_roundtrip_changes_only_lively(self):
        envelope,key=self.seal();apply(self.root,unpack(envelope,key))
        m=json.loads((self.root/'manifest.json').read_text())
        self.assertEqual(m['cases'][1],self.original['cases'][1])
        self.assertEqual(m['models'],self.original['models'])
        self.assertEqual(m['version'],self.original['version'])
        self.assertEqual(m['cases'][0]['reference_text'],'new')
        self.assertEqual(set(m['asset_integrity']),ALLOWED-{'patch.json'})
    def test_wrong_key_and_corrupted_envelope_rejected(self):
        e,k=self.seal()
        for data,key in [(e,b'wrong'),(e[:-1]+bytes([e[-1]^1]),k)]:
            with self.assertRaises(ValueError):unpack(data,key)
    def test_path_injection_rejected(self):
        self.files['../other-voice']=b'bad';e,k=self.seal()
        with self.assertRaises(ValueError):unpack(e,k)
    def test_wrong_base_and_other_voice_rejected_before_write(self):
        for field,value in [('base_manifest_sha256','wrong'),('case',dict(self.patch['case'],id='daily'))]:
            old=copy.deepcopy(self.patch);self.patch[field]=value;self.refresh()
            with self.assertRaises(ValueError):apply(self.root,self.files)
            self.assertEqual((self.root/'references/jiuhu_idle50.wav').read_bytes(),b'old')
            self.patch=old
    def test_bad_feature_size_rejected_before_write(self):
        self.patch['case']['tensors'][0]['shape']=[99];self.refresh()
        with self.assertRaises(ValueError):apply(self.root,self.files)
        self.assertEqual((self.root/'references/jiuhu_idle50.wav').read_bytes(),b'old')
    def test_missing_feature_rejected(self):
        self.patch['case']['tensors'].pop();self.refresh()
        with self.assertRaises(ValueError):apply(self.root,self.files)

if __name__=='__main__':unittest.main()
