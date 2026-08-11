#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/DiagnosticRedaction.kt'

MAIN=r'''package com.aicompanion.localfirst
fun main() {
    val raw = "failed at /data/user/0/com.aicompanion/files/secret 123e4567-e89b-12d3-a456-426614174000 abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
    val safe = DiagnosticRedaction.sanitizeDetail(raw)
    check(!safe.contains("/data/user"))
    check(!safe.contains("123e4567"))
    check(!safe.contains("abcdef0123456789"))
    check(safe.contains("<path>") || safe.contains("<id>") || safe.contains("<fingerprint>"))
    val fp = DiagnosticRedaction.fingerprint("relationship-lineage-secret")
    check(fp.length == 12)
    check(fp != "relationship-lineage-secret")
    val token = DiagnosticRedaction.safeToken("hello 用户 secret", 20)
    check(!token.contains("用户"))
    println("[OK] native diagnostic redaction is deterministic and bounded")
}
'''

def main()->int:
    compiler=shutil.which('kotlinc')
    java=shutil.which('java')
    if not compiler or not java:
        print('[SKIP] kotlinc/java unavailable'); return 0
    with tempfile.TemporaryDirectory(prefix='preflight-redaction-v27-') as td:
        td=Path(td); main=td/'Main.kt'; main.write_text(MAIN,encoding='utf-8'); jar=td/'test.jar'
        subprocess.run([compiler,str(SRC),str(main),'-include-runtime','-d',str(jar)],check=True)
        subprocess.run([java,'-jar',str(jar)],check=True)
    return 0
if __name__=='__main__': raise SystemExit(main())
