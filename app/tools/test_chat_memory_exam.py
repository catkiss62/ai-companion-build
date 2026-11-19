"""Verify the on-device bundle, original timeline and scoring of both papers."""
from hashlib import sha256
import json
from pathlib import Path
import sys
import tempfile
import zipfile

app=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(app/"android/app/src/main/python"))
from chat_exam_android import dispatch,load,FORMAL,REVISION

archive=app/"android/app/src/main/assets/chat-memory-v1.zip"
with tempfile.TemporaryDirectory() as cache, zipfile.ZipFile(archive) as z:
    for suite,total,turns in [("demo",108,299),("formal",714,2240)]:
        def call(operation,**params):
            return json.loads(dispatch(archive,cache,operation,json.dumps({"suite":suite,**params})))
        public=call("inputs")
        questions=public["questions"]
        assert len(questions)==len({q["id"] for q in questions})==total
        folder="demo" if suite=="demo" else FORMAL
        assert questions==[json.loads(line) for line in z.read(folder+"/exam-inputs.jsonl").splitlines()]
        assert sum(max(q["cutoff_turn"] for q in questions if q["persona"]==p) for p in public["histories"])==turns
        assert all(set(q)=={"id","persona","history_file","history_sha256","now","cutoff_turn","question"} for q in questions)
        grade,_,_,keys,_,source=load(archive,cache,suite)
        for q in questions:
            history=public["histories"][q["persona"]]
            n=q["cutoff_turn"]
            assert 0<=n<=len(history) and (not n or history[n-1]["逻辑时间"]<=q["now"])
            assert n==len(history) or history[n]["逻辑时间"]>q["now"]
            assert sha256(z.read(folder+"/"+q["history_file"])).hexdigest()==q["history_sha256"]
            assert q["id"] in keys
        for q in (questions[0],questions[-1]):
            ident=q["id"]
            packet=call("packet",id=ident,answer="接口验收示例")["packet"]
            review={k:packet[k] for k in ("id","answer_sha256","rubric_sha256")}
            review.update({k:False for k in grade.FLAGS})
            review.update({k:[] for k in grade.LISTS})
            review.update(required=[True]*len(packet["rubric"]["required"]),reason="测试判分器")
            judgment=call("score",packet=packet,review=review)
            assert judgment["pass"]
            review["错认"]=True
            assert not call("score",packet=packet,review=review)["pass"]
            try:
                call("score",packet=packet,review={**review,"answer_sha256":"bad"})
                raise AssertionError("accepted changed answer")
            except ValueError:
                pass
            assert call("summary",judgments=[judgment])["dataset_questions"]==total
        print(f"{suite}: {total} original questions verified; official grader pass/fail and hash validation passed")
