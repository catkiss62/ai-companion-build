#!/usr/bin/env python3
"""Frozen +386 source/SQLite audit; not a Dart or live-QQ regression test."""
import hashlib
import json
import re
import sqlite3
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
EXPECTED = {
  "lib/integrations/qq_private/qq_runtime.dart": "645e5779827f548e036da0719803b7c76842109a",
  "lib/integrations/qq_private/qq_archive_reader.dart": "62333c7b452b1af944c607181b6e53a2a03151ff",
  "lib/integrations/qq_private/qq_group_learning.dart": "344da89ea6138b36d8935075d17ff43147b9233f",
  "lib/integrations/qq_private/qq_vision.dart": "5266bcfed2884db337695bc8c7f15503f295b382",
  "lib/core/database/qq_archive_schema.dart": "d79878d98bbccdf151fe8b5a159bf321e69dd2bd"
}

def read(path):
    return (APP / path).read_text(encoding="utf-8")

def main():
    for path, expected in EXPECTED.items():
        data = read(path).encode()
        actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert actual == expected, f"Frozen source changed: {path}"
    runtime = read("lib/integrations/qq_private/qq_runtime.dart")
    reader = read("lib/integrations/qq_private/qq_archive_reader.dart")
    learning = read("lib/integrations/qq_private/qq_group_learning.dart")
    schema = read("lib/core/database/qq_archive_schema.dart")
    assert "event['message_reference']" in runtime
    for field in ["message_type", "message_scene", "msg_elements", "ref_msg_idx"]:
        assert f"event['{field}']" not in runtime

    # Synthetic current event with reference-only image/text, matching the
    # documented official quote structure. These are NOT merge-forward fields.
    quote = {"content": "你怎么看", "message_type": 103,
             "message_scene": {"ext": ["ref_msg_idx=synthetic-reference"]},
             "msg_elements": [{"content": "被引用的旧内容",
                               "attachments": [{"content_type": "image/png",
                                                "url": "https://fixture.invalid/quote.png"}]}]}
    kept = {"text": quote["content"].strip(),
            "reply_to": quote.get("message_reference", {}).get("message_id", ""),
            "images": len(quote.get("attachments", []))}
    assert kept == {"text": "你怎么看", "reply_to": "", "images": 0}

    sql = sqlite3.connect(":memory:")
    for statement in re.findall(r"await sql.execute\('''(CREATE TABLE IF NOT EXISTS .*?)'''\)", schema, re.S):
        sql.execute(statement)
    fields = {r[1] for r in sql.execute("PRAGMA table_info(qq_archive)")}
    assert not fields.intersection({"message_type", "origin_kind", "quoted_payload", "origin_conversation"})
    sql.execute("INSERT INTO qq_conversations(id,scope,kind,target) VALUES('current','fixture','group','current')")
    for i in range(12):
        sql.execute("INSERT INTO qq_archive(id,conversation_id,platform_id,sender,role,content,observed_at,received_at) "
                    "VALUES(?, 'current', ?, 'real-poster', 'user', ?, 1000, 1000)",
                    (f"fixture-{i}",f"platform-{i}","转发截图" if i == 11 else "本群当前发言"))
    image_seq = sql.execute("SELECT seq FROM qq_archive WHERE id='fixture-11'").fetchone()[0]
    sql.execute("INSERT INTO qq_images(id,archive_seq,ordinal,state,description) VALUES('image',?,0,'viewed',?)",
                (image_seq, "聊天截图中另一位发言者说了一句话；来源未核实"))
    # Run the actual eligibility WHERE literal used by the production learner.
    where = re.search(r'where:"(conversation_id=\? AND role=\'user\' AND seq>\?)"', learning).group(1)
    eligible = sql.execute("SELECT seq FROM qq_archive WHERE " + where + " ORDER BY seq LIMIT 40", ("current",0)).fetchall()
    assert (image_seq,) in eligible
    assert "QqArchiveReader(txn).render(row,stamp:proof,maxChars:1600)" in learning
    assert "'provenance_role':row['role']=='assistant'?'ASSISTANT_HISTORY':row['owner']==1?'REAL_USER_HISTORY':'GROUP_MEMBER_HISTORY'" in reader
    assert "'observation':image['state']=='viewed'?bound(image['description']" in reader

    output = {
        "source": "1330046de74a790ae671443a4108a2ec1ede6f0f",
        "level": "frozen source assertions + actual SQLite schema/query with synthetic data",
        "quote_fixture": {"nested_text_present_upstream": True, "nested_image_count": 1,
                          "current_kept_projection": kept},
        "forward_screenshot_fixture": {"archive_origin_fields": [],
                          "learning_eligible_rows": len(eligible),
                          "forward_image_row_enters_learning_query": True,
                          "observation_rendered_under_outer_group_member": True},
        "limitations": ["No actual user event inspected", "No Dart/Flutter or paid-model calls",
                        "Does not claim the model actually learned or misremembered",
                        "Quote=103 is not asserted to be the merge-forward message type"]
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    (Path(__file__).with_name("qq_v042142_provenance_results.json")).write_text(
        json.dumps(output, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")

if __name__ == "__main__":
    main()
