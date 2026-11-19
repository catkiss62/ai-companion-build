"""Copy the pinned public 1.0 corpus byte-for-byte. Exclude other editions."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys
import zipfile

REVISION = "0d8cde311a0d095f1e2122241294e6ac90b763e9"
FORMAL = "datasets/natural-timegrid-20261101-v2"
ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("checkout", type=Path)
    args = parser.parse_args()
    base = args.checkout.resolve()
    revision = subprocess.check_output(["git","-C",str(base),"rev-parse","HEAD"],text=True).strip()
    if revision != REVISION or subprocess.check_output(["git","-C",str(base),"status","--porcelain","--untracked-files=no"]):
        raise SystemExit("Expected clean pinned upstream checkout")
    names = ["LICENSE","grading/grade.py","grading/judge-prompt.md","grading/evidence.jsonl",
             "demo/review-only/cases-PUB01.jsonl"]
    for group,count in [("demo",108),(FORMAL,714)]:
        subprocess.run([sys.executable,str(base/group/"read_exam.py"),"--verify-all"],cwd=base,check=True)
        for name in ["exam-inputs.jsonl","review-only/answer-key.jsonl","manifest.json"]:
            names.append(group+"/"+name)
        names.extend(p.relative_to(base).as_posix() for p in sorted((base/group/"histories").glob("*.jsonl")))
        assert len((base/group/"exam-inputs.jsonl").read_text().splitlines())==count
    output = ROOT/"android/app/src/main/assets/chat-memory-v1.zip"
    with zipfile.ZipFile(output,"w") as z:
        def put(name,data):
            info=zipfile.ZipInfo(name)
            info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,data)
        hashes={}
        for name in sorted(names):
            data=(base/name).read_bytes()
            hashes[name]=sha256(data).hexdigest()
            put(name,data)
        put("provenance.json",json.dumps({"repository":"Ornn8/chat-memory-benchmark",
            "revision":REVISION,"edition":"1.0","sha256":hashes},sort_keys=True).encode())

if __name__=="__main__":
    main()
