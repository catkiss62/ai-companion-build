#!/usr/bin/env python3
"""SQLite mirror for the additive v18 -> v19 Companion Voice migration."""

import sqlite3


def v18_database() -> sqlite3.Connection:
    db = sqlite3.connect(':memory:')
    db.executescript('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        reasoning_content TEXT NOT NULL DEFAULT '',
        model TEXT,
        created_at INTEGER NOT NULL,
        is_proactive INTEGER NOT NULL DEFAULT 0,
        proactive_intent TEXT NOT NULL DEFAULT '',
        proactive_delivery TEXT NOT NULL DEFAULT '',
        device_id TEXT
      );
      CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ''')
    db.execute(
        '''INSERT INTO messages(
             id,role,content,reasoning_content,model,created_at,device_id
           ) VALUES(?,?,?,?,?,?,?)''',
        ('legacy', 'assistant', '旧正文', '旧 provider 思考', 'deepseek-v4-pro', 1, 'phone'),
    )
    db.commit()
    return db


def migrate_to_v19(db: sqlite3.Connection) -> None:
    with db:
        db.execute("ALTER TABLE messages ADD COLUMN provider_reasoning TEXT NOT NULL DEFAULT ''")
        db.execute('ALTER TABLE messages ADD COLUMN companion_voice INTEGER NOT NULL DEFAULT 0')
        db.execute('''
          UPDATE messages
          SET provider_reasoning = reasoning_content
          WHERE provider_reasoning = '' AND reasoning_content <> ''
        ''')
        for key, value in (
            ('companion_voice_enabled', '0'),
            ('companion_voice_retry_count', '0'),
            ('companion_voice_block_count', '0'),
        ):
            db.execute(
                'INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)',
                (key, value),
            )


def main() -> None:
    db = v18_database()
    migrate_to_v19(db)
    columns = {row[1] for row in db.execute('PRAGMA table_info(messages)')}
    assert {'reasoning_content', 'provider_reasoning', 'companion_voice'} <= columns

    legacy = db.execute(
        'SELECT content,reasoning_content,provider_reasoning,companion_voice FROM messages WHERE id=?',
        ('legacy',),
    ).fetchone()
    assert legacy == ('旧正文', '旧 provider 思考', '旧 provider 思考', 0)
    settings = dict(db.execute('SELECT key,value FROM settings'))
    assert settings['companion_voice_enabled'] == '0'

    with db:
        db.execute(
            '''INSERT INTO messages(
                 id,role,content,reasoning_content,provider_reasoning,
                 companion_voice,model,created_at,device_id
               ) VALUES(?,?,?,?,?,?,?,?,?)''',
            (
                'voice', 'assistant', '我在。', '我其实有点高兴他来找我。',
                'We need to answer the user naturally.', 1,
                'deepseek-v4-pro', 2, 'phone',
            ),
        )
    voice = db.execute(
        'SELECT content,reasoning_content,provider_reasoning,companion_voice FROM messages WHERE id=?',
        ('voice',),
    ).fetchone()
    assert voice == (
        '我在。',
        '我其实有点高兴他来找我。',
        'We need to answer the user naturally.',
        1,
    )
    assert '<companion_' not in voice[0]
    assert '<companion_' not in voice[1]

    # Re-running the setting seed is idempotent and cannot switch an enabled
    # user back off during a later startup/import normalization pass.
    db.execute(
        "UPDATE settings SET value='1' WHERE key='companion_voice_enabled'",
    )
    with db:
        db.execute(
            "INSERT OR IGNORE INTO settings(key,value) VALUES('companion_voice_enabled','0')",
        )
    assert db.execute(
        "SELECT value FROM settings WHERE key='companion_voice_enabled'",
    ).fetchone()[0] == '1'

    print('[OK] v18 -> v19 preserves legacy reasoning and separates provider/inner/reply')
    print('[OK] Companion Voice defaults OFF without overwriting an explicit user choice')


if __name__ == '__main__':
    main()
