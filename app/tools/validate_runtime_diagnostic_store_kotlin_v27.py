#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
STUBS={
'android/content/Context.kt': r'''package android.content
open class Context { companion object { const val MODE_PRIVATE=0 }; open fun getSharedPreferences(n:String,m:Int)=SharedPreferences() }
class SharedPreferences { fun getString(k:String,d:String?):String?=d; fun edit()=Editor() }
class Editor { fun putString(k:String,v:String)=this; fun remove(k:String)=this; fun apply(){} }
''',
'org/json/Json.kt': r'''package org.json
class JSONArray { constructor(); constructor(s:String); private val items=mutableListOf<Any?>(); fun length()=items.size; fun optJSONObject(i:Int):JSONObject?=null; fun put(v:Any?):JSONArray { items.add(v); return this }; fun remove(i:Int):Any?=if(i in items.indices) items.removeAt(i) else null; override fun toString()="[]" }
class JSONObject { constructor(); companion object { val NULL:Any=Any() }; fun put(k:String,v:Any?):JSONObject=this; fun optLong(k:String,d:Long):Long=d; fun optString(k:String):String=""; fun optJSONObject(k:String):JSONObject?=null; fun opt(k:String):Any?=null; fun keys():MutableIterator<String> = mutableListOf<String>().iterator(); override fun toString()="{}" }
''',
}
def main()->int:
    compiler=shutil.which('kotlinc')
    if not compiler:
        print('[SKIP] kotlinc unavailable'); return 0
    with tempfile.TemporaryDirectory(prefix='runtime-diagnostic-v27-') as td:
        td=Path(td); src=td/'src'
        for rel,text in STUBS.items():
            p=src/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text)
        actual=ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst'
        cp=subprocess.run([compiler,str(src),str(actual/'DiagnosticRedaction.kt'),str(actual/'RuntimeDiagnosticStore.kt'),'-d',str(td/'out.jar')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        if cp.returncode:
            print(cp.stderr); return cp.returncode
    print('[OK] RuntimeDiagnosticStore Kotlin compiles against SharedPreferences/JSON stubs')
    return 0
if __name__=='__main__': raise SystemExit(main())
