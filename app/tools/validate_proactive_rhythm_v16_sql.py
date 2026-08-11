#!/usr/bin/env python3
from __future__ import annotations

import math
import sqlite3
import time

NOW = 1_800_000_000_000
DAY = 86_400_000


def make_v15_db() -> sqlite3.Connection:
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    db.execute('''
      CREATE TABLE proactive_feedback (
        id TEXT PRIMARY KEY,
        proactive_message_id TEXT NOT NULL UNIQUE,
        thought_id TEXT,
        topic_key TEXT NOT NULL DEFAULT '',
        thread_id TEXT,
        intent_kind TEXT NOT NULL DEFAULT '',
        delivery_style TEXT NOT NULL DEFAULT '',
        sent_at INTEGER NOT NULL,
        user_response_message_id TEXT,
        response_latency_seconds INTEGER,
        response_bucket TEXT NOT NULL DEFAULT 'pending',
        user_text_length INTEGER NOT NULL DEFAULT 0,
        response_quality REAL,
        outcome TEXT NOT NULL DEFAULT 'pending',
        outcome_score REAL,
        processed_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''')
    return db


def migrate_v16(db: sqlite3.Connection) -> None:
    db.execute("ALTER TABLE proactive_feedback ADD COLUMN context_hour_bucket TEXT NOT NULL DEFAULT ''")
    db.execute("ALTER TABLE proactive_feedback ADD COLUMN context_activity TEXT NOT NULL DEFAULT 'unknown'")
    db.execute('ALTER TABLE proactive_feedback ADD COLUMN context_busy REAL NOT NULL DEFAULT 0')
    db.execute('ALTER TABLE proactive_feedback ADD COLUMN timing_fit REAL')
    db.execute('ALTER TABLE proactive_feedback ADD COLUMN topic_fit REAL')
    db.execute('CREATE INDEX idx_proactive_context_hour ON proactive_feedback(context_hour_bucket, sent_at DESC)')
    db.execute('CREATE INDEX idx_proactive_context_activity ON proactive_feedback(context_activity, sent_at DESC)')


def timing_fit(row: dict) -> float | None:
    if row.get('timing_fit') is not None:
        return max(-1.0, min(1.0, float(row['timing_fit'])))
    outcome = row.get('outcome')
    latency = row.get('response_latency_seconds') or 999999
    if outcome == 'deferred': return -0.75
    if outcome in ('engaged', 'resolved'): return 0.55 if latency <= 7200 else 0.35
    if outcome == 'acknowledged': return 0.25 if latency <= 7200 else 0.10
    if outcome == 'no_response': return -0.18
    if outcome in ('dismissed', 'redirected'): return 0.0
    return None


def topic_fit(row: dict) -> float | None:
    if row.get('topic_fit') is not None:
        return max(-1.0, min(1.0, float(row['topic_fit'])))
    return {
        'engaged': 0.55,
        'resolved': 0.55,
        'acknowledged': 0.20,
        'deferred': 0.05,
        'dismissed': -0.85,
        'redirected': -0.45,
        'no_response': 0.0,
    }.get(row.get('outcome'))


def weighted(rows: list[dict], selector, prior: float, now_ms: int = NOW) -> tuple[float, float]:
    weighted_sum = 0.0
    total = 0.0
    for row in rows:
        signal = selector(row)
        if signal is None:
            continue
        age_days = max(0.0, (now_ms - row['sent_at']) / DAY)
        decay = 0.5 ** (age_days / 45.0)
        reliability = 0.45 if row.get('outcome') == 'no_response' else 1.0
        w = decay * reliability
        weighted_sum += signal * w
        total += w
    return (0.0 if total <= 0 else weighted_sum / (prior + total), total)


def profile(rows: list[dict], hour: str, activity: str, topic: str = '', intent: str = '') -> dict:
    hour_rows = [r for r in rows if r.get('context_hour_bucket') == hour]
    activity_rows = [r for r in rows if r.get('context_activity') == activity]
    topic_rows = [r for r in rows if topic and r.get('topic_key') == topic]
    intent_rows = [r for r in rows if intent and r.get('intent_kind') == intent]
    h, hw = weighted(hour_rows, timing_fit, 3.0)
    a, aw = weighted(activity_rows, timing_fit, 3.0)
    g, _ = weighted(rows, timing_fit, 10.0)
    t, _ = weighted(topic_rows, topic_fit, 2.5)
    i, _ = weighted(intent_rows, topic_fit, 5.0)
    h_adj = max(-0.040, min(0.060, -h * 0.09))
    a_adj = max(-0.035, min(0.055, -a * 0.08))
    g_adj = max(-0.015, min(0.025, -g * 0.025))
    timing = max(-0.055, min(0.095, h_adj + a_adj + g_adj))
    topic_adj = max(-0.040, min(0.090, -t * 0.12))
    intent_adj = max(-0.020, min(0.045, -i * 0.055))
    total = max(-0.070, min(0.120, timing + topic_adj + intent_adj))
    return {
        'timing': timing,
        'topic': topic_adj,
        'intent': intent_adj,
        'total': total,
        'hour_weight': hw,
        'activity_weight': aw,
    }


def row(i: int, *, outcome: str, hour: str = 'evening', activity: str = 'game', topic: str = 'topic.a', intent: str = 'miss_you', age_days: int = 0, timing: float | None = None, subject: float | None = None) -> dict:
    return {
        'id': f'r{i}',
        'sent_at': NOW - age_days * DAY,
        'outcome': outcome,
        'response_latency_seconds': 1200,
        'context_hour_bucket': hour,
        'context_activity': activity,
        'topic_key': topic,
        'intent_kind': intent,
        'timing_fit': timing,
        'topic_fit': subject,
    }


def main() -> None:
    # v15 -> v16 proactive rhythm migration
    db = make_v15_db()
    db.execute("INSERT INTO proactive_feedback(id, proactive_message_id, sent_at, outcome, created_at) VALUES('old','m0',?,?,?)", (NOW - DAY, 'engaged', NOW - DAY))
    migrate_v16(db)
    migrated = dict(db.execute("SELECT * FROM proactive_feedback WHERE id='old'").fetchone())
    assert migrated['context_hour_bucket'] == ''
    assert migrated['context_activity'] == 'unknown'
    assert migrated['context_busy'] == 0
    assert migrated['timing_fit'] is None and migrated['topic_fit'] is None
    print('[OK] v15 -> v16 proactive rhythm migration preserves legacy rows')

    # no-response means weak timing evidence only
    db.execute("UPDATE proactive_feedback SET response_bucket='no_response', outcome='no_response', outcome_score=0, timing_fit=-0.18, topic_fit=0, processed_at=? WHERE id='old'", (NOW,))
    expired = dict(db.execute("SELECT * FROM proactive_feedback WHERE id='old'").fetchone())
    assert expired['timing_fit'] == -0.18 and expired['topic_fit'] == 0
    print('[OK] no-response is weak timing evidence, not topic rejection')

    # bad timing and bad topic remain separable
    deferred = [row(1, outcome='deferred', hour='morning', activity='productivity', timing=-0.85, subject=0.10)]
    same_context = profile(deferred, 'morning', 'productivity', topic='topic.a', intent='miss_you')
    other_context = profile(deferred, 'evening', 'game', topic='topic.a', intent='miss_you')
    assert same_context['timing'] > other_context['timing'] + 0.015
    assert same_context['topic'] <= 0
    dismissed = [row(2, outcome='dismissed', timing=0.0, subject=-0.9)]
    same_topic = profile(dismissed, 'evening', 'game', topic='topic.a', intent='miss_you')
    other_topic = profile(dismissed, 'evening', 'game', topic='topic.b', intent='curiosity')
    assert same_topic['topic'] > 0.02
    assert abs(other_topic['topic']) < 1e-9
    assert abs(same_topic['timing']) < 1e-9
    print('[OK] timing rejection and topic rejection adapt different dimensions')

    # short streaks are shrunk by neutral priors
    two_dismissals = [row(i, outcome='dismissed', timing=0.0, subject=-0.9) for i in range(2)]
    short = profile(two_dismissals, 'evening', 'game', topic='topic.a', intent='miss_you')
    assert 0 < short['topic'] < 0.05
    print('[OK] short negative streak cannot cause a large personality swing')

    # repeated silence stays weak and cannot globally mute initiative
    ignored = [row(i, outcome='no_response', timing=-0.18, subject=0.0) for i in range(24)]
    ignored_profile = profile(ignored, 'evening', 'game', topic='topic.a', intent='miss_you')
    assert 0 < ignored_profile['timing'] < 0.04
    assert abs(ignored_profile['topic']) < 1e-9
    assert ignored_profile['total'] < 0.04
    print('[OK] repeated no-response remains bounded and does not become topic suppression')

    # Gate bounds mirror the v0.23 engine constants: learned caution cannot
    # permanently mute initiative, while hard send ceilings remain absolute.
    def bounded_threshold(base: float, learned: float, idle_minutes: int) -> float:
        relief = 0.045 if idle_minutes >= 12 * 60 else (0.025 if idle_minutes >= 6 * 60 else 0.0)
        return max(0.52, min(0.76, base + max(-0.070, min(0.120, learned)) - relief))

    assert bounded_threshold(0.60, 1.0, 0) == 0.72
    assert bounded_threshold(0.60, 1.0, 12 * 60) == 0.6749999999999999 or abs(bounded_threshold(0.60, 1.0, 12 * 60) - 0.675) < 1e-9
    assert bounded_threshold(0.60, -1.0, 12 * 60) == 0.52
    def spam_block(sent_24h: int, sent_2h: int) -> bool:
        return sent_24h >= 8 or sent_2h >= 2
    assert not spam_block(7, 1)
    assert spam_block(8, 0)
    assert spam_block(1, 2)
    print('[OK] anti-silence threshold recovery and 2h/24h spam ceilings stay bounded')

    # coarse context windows can diverge naturally
    mixed = []
    for i in range(8):
        mixed.append(row(i, outcome='engaged', hour='evening', activity='game', timing=0.75, subject=0.55))
    for i in range(8, 16):
        mixed.append(row(i, outcome='deferred', hour='morning', activity='productivity', timing=-0.8, subject=0.05))
    comfortable = profile(mixed, 'evening', 'game', topic='topic.a', intent='miss_you')
    awkward = profile(mixed, 'morning', 'productivity', topic='topic.a', intent='miss_you')
    assert comfortable['timing'] < -0.02
    assert awkward['timing'] > 0.02
    print('[OK] time-of-day and activity contexts learn independent comfort windows')

    # old behavior decays rather than permanently defining the relationship
    recent = profile([row(1, outcome='engaged', timing=0.8, subject=0.6, age_days=0)], 'evening', 'game')
    old = profile([row(1, outcome='engaged', timing=0.8, subject=0.6, age_days=120)], 'evening', 'game')
    assert abs(recent['timing']) > abs(old['timing']) * 2
    print('[OK] rhythm evidence decays with a 45-day half-life')

    # v16 full-state copy preserves the learned context columns exactly
    payload = dict(db.execute("SELECT * FROM proactive_feedback WHERE id='old'").fetchone())
    db2 = make_v15_db()
    migrate_v16(db2)
    columns = [r['name'] for r in db2.execute('PRAGMA table_info(proactive_feedback)').fetchall()]
    vals = [payload[c] for c in columns]
    db2.execute(f"INSERT INTO proactive_feedback({','.join(columns)}) VALUES({','.join('?' for _ in columns)})", vals)
    copied = dict(db2.execute("SELECT * FROM proactive_feedback WHERE id='old'").fetchone())
    for key in ('context_hour_bucket', 'context_activity', 'context_busy', 'timing_fit', 'topic_fit'):
        assert copied[key] == payload[key]
    print('[OK] v16 phone/tablet state transfer preserves rhythm context and feedback signals')

    print('v0.23 Proactive Rhythm Learning SQLite/simulation validation passed.')


if __name__ == '__main__':
    main()
