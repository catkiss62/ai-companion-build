#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

STUBS={
'android/content/Context.kt': r'''package android.content
import java.io.File
import android.net.Uri
open class Context {
 open val applicationContext: Context get()=this
 open val cacheDir: File = File(".")
 open val contentResolver: ContentResolver = ContentResolver()
 open fun getDatabasePath(name:String): File = File(name)
 open fun stopService(intent: Intent): Boolean = true
}
class Intent(val context: Context?=null, val cls: Class<*>?=null)
class ContentValues { fun put(k:String,v:String?){}; fun put(k:String,v:Long){} }
class ContentResolver {
 fun openInputStream(uri: Uri): java.io.InputStream? = java.io.ByteArrayInputStream(byteArrayOf())
 fun delete(uri: Uri, where:String?, args:Array<String>?): Int=0
}
''',
'android/net/Uri.kt': 'package android.net\nclass Uri\n',
'android/os/Core.kt': r'''package android.os
class Looper { companion object { fun getMainLooper(): Looper=Looper() } }
class Handler(l:Looper) { fun post(r:()->Unit):Boolean { r(); return true } }
object Build { var MANUFACTURER="x"; var MODEL="y"; var VERSION=V(); object VERSION_CODES { const val Q=29 }; class V { var SDK_INT=35 } }
''',
'android/database/sqlite/SQLiteDatabase.kt': r'''package android.database.sqlite
import android.content.ContentValues
class Cursor: AutoCloseable { fun moveToFirst()=false; fun getString(i:Int):String=""; override fun close(){} }
open class SQLiteDatabase {
 companion object { const val OPEN_READWRITE=1; const val OPEN_READONLY=2; const val CONFLICT_REPLACE=5; fun openDatabase(p:String,c:Any?,f:Int)=SQLiteDatabase() }
 fun execSQL(sql:String){}
 fun insertOrThrow(t:String,n:String?,v:ContentValues):Long=1
 fun insertWithOnConflict(t:String,n:String?,v:ContentValues,a:Int):Long=1
 fun query(t:String,c:Array<String>,s:String,a:Array<String>,g:String?,h:String?,o:String?,l:String):Cursor=Cursor()
 fun beginTransaction(){}; fun setTransactionSuccessful(){}; fun endTransaction(){}; fun close(){}
}
''',
'com/google/android/gms/common/api/CommonStatusCodes.kt': 'package com.google.android.gms.common.api\nobject CommonStatusCodes { const val SUCCESS=0 }\n',
'com/google/android/gms/nearby/Nearby.kt': r'''package com.google.android.gms.nearby
import android.content.Context
import com.google.android.gms.nearby.connection.ConnectionsClient
object Nearby { fun getConnectionsClient(c:Context)=ConnectionsClient() }
''',
'com/google/android/gms/nearby/connection/Stubs.kt': r'''package com.google.android.gms.nearby.connection
import java.io.File
import android.net.Uri
class Task { fun addOnSuccessListener(l:()->Unit):Task=this; fun addOnFailureListener(l:(Throwable)->Unit):Task=this }
class ConnectionsClient {
 fun startAdvertising(n:String,s:String,c:ConnectionLifecycleCallback,o:AdvertisingOptions)=Task()
 fun startDiscovery(s:String,c:EndpointDiscoveryCallback,o:DiscoveryOptions)=Task()
 fun requestConnection(n:String,e:String,c:ConnectionLifecycleCallback)=Task()
 fun acceptConnection(e:String,p:PayloadCallback)=Task(); fun rejectConnection(e:String)=Task()
 fun sendPayload(e:String,p:Payload)=Task(); fun stopAdvertising(){}; fun stopDiscovery(){}; fun stopAllEndpoints(){}; fun cancelPayload(id:Long)=Task()
}
class AdvertisingOptions { class Builder { fun setStrategy(s:Strategy)=this; fun build()=AdvertisingOptions() } }
class DiscoveryOptions { class Builder { fun setStrategy(s:Strategy)=this; fun build()=DiscoveryOptions() } }
class Strategy { companion object { val P2P_POINT_TO_POINT=Strategy() } }
class DiscoveredEndpointInfo(val endpointName:String="")
abstract class EndpointDiscoveryCallback { abstract fun onEndpointFound(endpointId:String, info:DiscoveredEndpointInfo); abstract fun onEndpointLost(endpointId:String) }
class ConnectionInfo(val endpointName:String="", val authenticationDigits:String="")
class Status(val statusCode:Int=0)
class ConnectionResolution(val status:Status=Status())
abstract class ConnectionLifecycleCallback { abstract fun onConnectionInitiated(endpointId:String, info:ConnectionInfo); abstract fun onConnectionResult(endpointId:String,resolution:ConnectionResolution); abstract fun onDisconnected(endpointId:String) }
class Payload private constructor(val type:Int, val id:Long=1L) {
 class FilePayload { fun asUri(): Uri?=Uri(); fun asJavaFile(): File?=File("x") }
 fun asBytes():ByteArray?=byteArrayOf(); fun asFile():FilePayload?=FilePayload(); fun setFileName(n:String){}; fun setSensitive(v:Boolean){}
 object Type { const val FILE=1; const val BYTES=2 }; companion object { fun fromBytes(b:ByteArray)=Payload(Type.BYTES); fun fromFile(f:File)=Payload(Type.FILE) }
}
class PayloadTransferUpdate(val payloadId:Long=1,val totalBytes:Long=0,val status:Int=0) { object Status { const val SUCCESS=1; const val FAILURE=2; const val CANCELED=3 } }
abstract class PayloadCallback { abstract fun onPayloadReceived(endpointId:String,payload:Payload); abstract fun onPayloadTransferUpdate(endpointId:String,update:PayloadTransferUpdate) }
''',
'org/json/JSONObject.kt': r'''package org.json
class JSONObject { constructor(); constructor(s:String); fun put(k:String,v:Any?):JSONObject=this; fun optString(k:String):String=""; fun optString(k:String,d:String):String=d; fun optLong(k:String,d:Long):Long=d; override fun toString():String="{}"; constructor(m:Map<String,Any?>) }
''',
'com/aicompanion/localfirst/AppStubs.kt': r'''package com.aicompanion.localfirst
import android.content.Context
object CompanionRuntimeState { fun setOverlayUserEnabled(c:Context,v:Boolean){} }
class OverlayBubbleService { companion object { fun stopForStandby(c:Context){} } }
object RuntimeDiagnosticStore {
 fun recordNearby(c:Context,type:String,extra:Map<String,Any?>){}
 fun record(c:Context,category:String,phase:String,severity:String="info",code:String="",detail:String="",metadata:Map<String,Any?> = emptyMap()){}
}
''',
}

def compile_group(compiler:str, actual:list[str], extra_stubs:dict[str,str], out:Path):
    src=out/'src'; src.mkdir(parents=True,exist_ok=True)
    merged=dict(STUBS); merged.update(extra_stubs)
    for rel,text in merged.items():
        p=src/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text)
    actual_root=ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst'
    cmd=[compiler,str(src)]+[str(actual_root/x) for x in actual]+['-d',str(out/'out.jar')]
    cp=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    if cp.returncode:
        print(cp.stderr); raise SystemExit(cp.returncode)


def main():
    compiler=shutil.which('kotlinc')
    if not compiler:
        print('[SKIP] kotlinc unavailable'); return 0
    with tempfile.TemporaryDirectory(prefix='transfer-kotlin-v26-') as td:
        base=Path(td)
        # Nearby uses a tiny NativeEventStore stub so its protocol source is type-checked independently.
        compile_group(compiler,['NearbyTransferManager.kt'],{
            'com/aicompanion/localfirst/NativeEventStore.kt': r'''package com.aicompanion.localfirst
import android.content.Context
object NativeEventStore { fun fenceForTakeover(c:Context,snapshotId:String,lineageId:String,generation:Long,targetDeviceId:String)=true }
'''
        },base/'nearby')
        # Compile the real NativeEventStore + pure JVM crypto against DB/context stubs.
        compile_group(compiler,['NativeEventStore.kt','ManualSnapshotCrypto.kt'],{},base/'native')
    print('[OK] Nearby v3 protocol + NativeEventStore fence + manual crypto Kotlin compile against API stubs')
    return 0
if __name__=='__main__': raise SystemExit(main())
