#!/usr/bin/env python3
from __future__ import annotations
import sqlite3


def main() -> int:
    db = sqlite3.connect(':memory:')
    db.executescript('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_proactive INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE thoughts (
        id TEXT PRIMARY KEY,
        drive_key TEXT NOT NULL
      );
      CREATE TABLE proactive_feedback (
        id TEXT PRIMARY KEY,
        proactive_message_id TEXT NOT NULL UNIQUE,
        thought_id TEXT,
        topic_key TEXT NOT NULL DEFAULT '',
        thread_id TEXT,
        sent_at INTEGER NOT NULL
      );
      INSERT INTO thoughts VALUES ('ta','attachment'),('tl','libido'),('tr','reflection');
      INSERT INTO messages VALUES
        ('ma','assistant','a',1,1),
        ('ml','assistant','l',2,1),
        ('mr','assistant','r',3,1),
        ('mf','assistant','f',4,1),
        ('u','user','hello',5,0);
      INSERT INTO proactive_feedback VALUES
        ('fa','ma','ta','',NULL,1),
        ('fl','ml','tl','',NULL,2),
        ('fr','mr','tr','',NULL,3),
        ('ff','mf',NULL,'topic:x','thread-x',4);
    ''')
    db.executescript('''
      ALTER TABLE messages ADD COLUMN proactive_intent TEXT NOT NULL DEFAULT '';
      ALTER TABLE messages ADD COLUMN proactive_delivery TEXT NOT NULL DEFAULT '';
      ALTER TABLE proactive_feedback ADD COLUMN intent_kind TEXT NOT NULL DEFAULT '';
      ALTER TABLE proactive_feedback ADD COLUMN delivery_style TEXT NOT NULL DEFAULT '';
      UPDATE proactive_feedback
      SET intent_kind = CASE
        WHEN thread_id IS NOT NULL AND thread_id <> '' THEN 'followup'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'attachment' THEN 'miss_you'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'curiosity' THEN 'curiosity'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'reflection' THEN 'share_thought'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'duty' THEN 'followup'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'social' THEN 'social_share'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'libido' THEN 'intimacy_invitation'
        WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'stress' THEN 'emotional_reach'
        ELSE 'gentle_ping'
      END,
      delivery_style = CASE WHEN delivery_style = '' THEN 'normal' ELSE delivery_style END
      WHERE intent_kind = '';
      UPDATE messages
      SET proactive_intent = COALESCE(
            (SELECT intent_kind FROM proactive_feedback WHERE proactive_feedback.proactive_message_id = messages.id),
            CASE WHEN is_proactive = 1 THEN 'gentle_ping' ELSE '' END
          ),
          proactive_delivery = CASE WHEN is_proactive = 1 THEN 'normal' ELSE '' END
      WHERE proactive_intent = '' AND is_proactive = 1;
      CREATE INDEX idx_proactive_intent ON proactive_feedback(intent_kind, sent_at DESC);
    ''')
    expected = {
        'ma': ('miss_you','normal'),
        'ml': ('intimacy_invitation','normal'),
        'mr': ('share_thought','normal'),
        'mf': ('followup','normal'),
        'u': ('',''),
    }
    actual = {r[0]:(r[1],r[2]) for r in db.execute('SELECT id, proactive_intent, proactive_delivery FROM messages')}
    assert actual == expected, (actual, expected)
    feedback = {r[0]:(r[1],r[2]) for r in db.execute('SELECT id,intent_kind,delivery_style FROM proactive_feedback')}
    assert feedback['fa'] == ('miss_you','normal')
    assert feedback['fl'] == ('intimacy_invitation','normal')
    assert feedback['fr'] == ('share_thought','normal')
    assert feedback['ff'] == ('followup','normal')
    # Intent-aware history query must be usable by the rhythm layer.
    rows = list(db.execute("SELECT id FROM proactive_feedback WHERE intent_kind='miss_you' ORDER BY sent_at DESC"))
    assert rows == [('fa',)]
    print('[OK] v12 -> v13 proactive metadata backfill')
    print('[OK] thread takes precedence over drive classification')
    print('[OK] non-proactive messages remain untagged')
    print('[OK] intent-history query/index path')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
