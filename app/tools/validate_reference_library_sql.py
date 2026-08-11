#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import time


def replace_chunks(db: sqlite3.Connection, document_id: str, source_name: str, contents: list[str]) -> None:
    row = db.execute(
        'SELECT enabled FROM reference_documents WHERE id = ? LIMIT 1',
        (document_id,),
    ).fetchone()
    if row is None:
        raise RuntimeError('document missing')
    enabled = 1 if row[0] == 1 else 0
    now = int(time.time() * 1000)
    with db:
        db.execute('DELETE FROM reference_items WHERE document_id = ?', (document_id,))
        for index, content in enumerate(contents, 1):
            db.execute(
                '''INSERT INTO reference_items(
                     id,document_id,source_name,section,title,content,tags,weight,enabled,created_at,updated_at
                   ) VALUES(?,?,?,?,?,?,?,?,?,?,?)''',
                (
                    f'chunk-{now}-{index}', document_id, source_name, 'character',
                    f'part {index}', content, 'Yuki|有希', 0.66 if index <= 2 else 0.58,
                    enabled, now, now,
                ),
            )


def main() -> int:
    db = sqlite3.connect(':memory:')
    db.executescript(
        '''
        CREATE TABLE reference_documents (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'character',
          aliases TEXT NOT NULL DEFAULT '',
          raw_content TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE reference_items (
          id TEXT PRIMARY KEY,
          document_id TEXT,
          source_name TEXT NOT NULL,
          section TEXT NOT NULL DEFAULT 'other',
          title TEXT NOT NULL DEFAULT '',
          content TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '',
          weight REAL NOT NULL DEFAULT 0.55,
          enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        '''
    )

    created = 1700000000000
    db.execute(
        '''INSERT INTO reference_documents(
             id,name,kind,aliases,raw_content,enabled,created_at,updated_at
           ) VALUES(?,?,?,?,?,?,?,?)''',
        ('doc-1', 'Yuki', 'character', '有希|Yuki', '完整原文 v1', 0, created, created),
    )
    replace_chunks(db, 'doc-1', 'Yuki', ['片段 A', '片段 B'])
    enabled_values = [r[0] for r in db.execute(
        'SELECT enabled FROM reference_items WHERE document_id = ? ORDER BY id',
        ('doc-1',),
    )]
    assert enabled_values == [0, 0], enabled_values
    print('[OK] disabled document stays excluded after rechunk')

    updated = created + 5000
    db.execute(
        '''UPDATE reference_documents
           SET name=?, kind=?, aliases=?, raw_content=?, enabled=?, updated_at=?
           WHERE id=?''',
        ('Yuki updated', 'character', '有希|Yuki', '完整原文 v2', 0, updated, 'doc-1'),
    )
    row = db.execute(
        'SELECT created_at, updated_at, raw_content FROM reference_documents WHERE id = ?',
        ('doc-1',),
    ).fetchone()
    assert row == (created, updated, '完整原文 v2'), row
    print('[OK] editing preserves document created_at and updates full raw text')

    replace_chunks(db, 'doc-1', 'Yuki updated', ['新片段'])
    row = db.execute(
        'SELECT raw_content, enabled FROM reference_documents WHERE id = ?',
        ('doc-1',),
    ).fetchone()
    assert row == ('完整原文 v2', 0), row
    count = db.execute(
        'SELECT COUNT(*) FROM reference_items WHERE document_id=? AND enabled=1',
        ('doc-1',),
    ).fetchone()[0]
    assert count == 0, count
    print('[OK] rechunk does not mutate full raw text or silently re-enable retrieval')

    # Simulate the UI save path as one transaction. A process/error between the
    # document update and chunk replacement must roll the whole save back.
    before_doc = db.execute(
        'SELECT raw_content, updated_at FROM reference_documents WHERE id=?',
        ('doc-1',),
    ).fetchone()
    before_chunks = list(db.execute(
        'SELECT content, enabled FROM reference_items WHERE document_id=? ORDER BY id',
        ('doc-1',),
    ))
    try:
        with db:
            db.execute(
                'UPDATE reference_documents SET raw_content=?, updated_at=? WHERE id=?',
                ('不应提交的原文', updated + 1000, 'doc-1'),
            )
            db.execute('DELETE FROM reference_items WHERE document_id=?', ('doc-1',))
            raise RuntimeError('simulated process failure before chunk commit')
    except RuntimeError:
        pass
    after_doc = db.execute(
        'SELECT raw_content, updated_at FROM reference_documents WHERE id=?',
        ('doc-1',),
    ).fetchone()
    after_chunks = list(db.execute(
        'SELECT content, enabled FROM reference_items WHERE document_id=? ORDER BY id',
        ('doc-1',),
    ))
    assert after_doc == before_doc, (before_doc, after_doc)
    assert after_chunks == before_chunks, (before_chunks, after_chunks)
    print('[OK] document edit + chunk replacement rolls back atomically on failure')

    with db:
        db.execute('UPDATE reference_documents SET enabled=1 WHERE id=?', ('doc-1',))
        db.execute('UPDATE reference_items SET enabled=1 WHERE document_id=?', ('doc-1',))
    count = db.execute(
        'SELECT COUNT(*) FROM reference_items WHERE document_id=? AND enabled=1',
        ('doc-1',),
    ).fetchone()[0]
    assert count == 1, count
    print('[OK] re-enable keeps document and retrieval chunks in sync')

    with db:
        db.execute('DELETE FROM reference_items WHERE document_id=?', ('doc-1',))
        db.execute('DELETE FROM reference_documents WHERE id=?', ('doc-1',))
    assert db.execute('SELECT COUNT(*) FROM reference_documents').fetchone()[0] == 0
    assert db.execute('SELECT COUNT(*) FROM reference_items').fetchone()[0] == 0
    print('[OK] delete removes full document and all derived chunks together')

    db.close()
    print('v0.19 Reference Library SQLite consistency checks passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
