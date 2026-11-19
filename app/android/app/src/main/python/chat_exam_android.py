"""Bundle access and upstream semantic score computation. Never calls a model."""
from functools import lru_cache
import hashlib
import importlib.util
import json
from pathlib import Path
import zipfile

REVISION = "0d8cde311a0d095f1e2122241294e6ac90b763e9"
FORMAL = "datasets/natural-timegrid-20261101-v2"

@lru_cache(maxsize=2)
def load(archive, cache, suite):
    if suite not in ("demo","formal"):
        raise ValueError("unknown suite")
    root=Path(cache)/("chat-exam-"+REVISION)
    with zipfile.ZipFile(archive) as z:
        source=json.loads(z.read("provenance.json"))
        if source["revision"]!=REVISION:
            raise ValueError("invalid revision")
        for name,digest in source["sha256"].items():
            data=z.read(name)
            if hashlib.sha256(data).hexdigest()!=digest:
                raise ValueError("invalid data hash")
            path=root/name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    # Each suite owns its module so the official grader's DATA never switches
    # while another run is using it.
    spec=importlib.util.spec_from_file_location("chat_grade_"+suite,root/"grading/grade.py")
    grade=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(grade)
    folder=root/("demo" if suite=="demo" else FORMAL)
    grade.DATA=folder
    questions=grade.read_rows(folder/"exam-inputs.jsonl")
    histories={p.stem:grade.read_rows(p) for p in sorted((folder/"histories").glob("*.jsonl"))}
    keys=grade.indexed(grade.read_rows(folder/"review-only/answer-key.jsonl"))
    cases={c["case_id"]:c for c in grade.read_rows(folder/"review-only/cases-PUB01.jsonl")} if suite=="demo" else {}
    return grade,questions,histories,keys,cases,source

def dispatch(archive,cache,command,payload):
    data=json.loads(payload)
    suite=data["suite"]
    grade,questions,histories,keys,cases,source=load(archive,cache,suite)
    if command=="inputs":
        result={"questions":questions,"histories":histories,"provenance":source}
    elif command=="packet":
        record={"id":data["id"],"answer":data["answer"]}
        if suite=="formal":
            packet=next(grade.prepare([record]))
        else:
            # Upstream prepare is hard-coded to the formal evidence file.
            # Use the demo author's exact quotes, speaker and turn references.
            ident=record["id"]
            q=next(q for q in questions if q["id"]==ident)
            key=keys[ident]
            facts=cases[key["case_id"]]["facts"]
            packet={**record,"question":q["question"],"now":q["now"],"rubric":key["rubric"],
                    "facts":facts,"sources":[e for f in facts for e in f["evidence"]],
                    "answer_sha256":grade.digest(record["answer"]),"rubric_sha256":grade.rubric_digest(key["rubric"])}
        result={"packet":packet,"instruction":(grade.ROOT/"grading/judge-prompt.md").read_text()}
    elif command=="score":
        packet=data["packet"]
        review=data["review"]
        result=next(grade.score({packet["id"]:packet},{review["id"]:review}))
    elif command=="summary":
        result=grade.summarize(data["judgments"])
    else:
        raise ValueError("unknown operation")
    return json.dumps(result,ensure_ascii=False)
