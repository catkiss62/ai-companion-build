package com.aicompanion.localfirst

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.util.UUID

/** Writes only to an already-created Flutter/sqflite database. */
object NativeEventStore {
    private const val DB_NAME = "ai_companion.db"

    fun addDeviceEvent(
        context: Context,
        source: String,
        eventType: String,
        appPackage: String?,
        summary: String?,
        metadata: Map<String, Any?> = emptyMap(),
    ) {
        withWritableDb(context) { db ->
            // Device/system callbacks are outside the Dart lease system. When a
            // phone/tablet snapshot is frozen or a receiver is replacing its
            // database, do not let a late screen/notification/accessibility
            // callback become an untracked writer against that frozen state.
            if (readSetting(db, "transfer_lock") == "1") return@withWritableDb
            if (readSetting(db, "active_brain") == "0") return@withWritableDb
            val values = ContentValues().apply {
                put("id", UUID.randomUUID().toString())
                put("device_id", readDeviceId(db))
                put("source", source)
                put("event_type", eventType)
                put("app_package", appPackage)
                put("summary", summary)
                put("occurred_at", System.currentTimeMillis())
                put("metadata_json", JSONObject(metadata).toString())
            }
            db.insertOrThrow("device_events", null, values)
        }
    }

    /** Read-only ownership probe used by Android services that must never
     * resurrect the floating companion while this device is standby. Fail
     * closed on database/lock errors so ambiguity cannot create two brains. */
    fun isActiveBrain(context: Context): Boolean {
        return runCatching {
            val path = context.getDatabasePath(DB_NAME)
            if (!path.exists()) return@runCatching false
            val db = SQLiteDatabase.openDatabase(
                path.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY,
            )
            try {
                runCatching { db.execSQL("PRAGMA busy_timeout = 1200") }
                readSetting(db, "active_brain") != "0"
            } finally {
                db.close()
            }
        }.getOrDefault(false)
    }

    fun setSetting(context: Context, key: String, value: String) {
        withWritableDb(context) { db ->
            val values = ContentValues().apply {
                put("key", key)
                put("value", value)
            }
            db.insertWithOnConflict(
                "settings",
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE,
            )
        }
    }

    /**
     * Source-side ownership fence for a bound takeover request. The old device
     * is allowed to step down only when the request names the exact snapshot
     * generation it has frozen and sent. This is intentionally one SQLite
     * transaction so no stale/replayed Nearby control message can knock an
     * unrelated Active Brain offline.
     */
    fun fenceForTakeover(
        context: Context,
        snapshotId: String,
        lineageId: String,
        generation: Long,
        targetDeviceId: String,
    ): Boolean {
        if (snapshotId.isBlank() || lineageId.isBlank() || generation <= 0L || targetDeviceId.isBlank()) {
            return false
        }
        return runCatching {
            val path = context.getDatabasePath(DB_NAME)
            if (!path.exists()) return@runCatching false
            val db = SQLiteDatabase.openDatabase(
                path.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            )
            try {
                runCatching { db.execSQL("PRAGMA busy_timeout = 2500") }
                db.beginTransaction()
                try {
                    val active = readSetting(db, "active_brain")
                    val locked = readSetting(db, "transfer_lock")
                    val currentLineage = readSetting(db, "state_lineage_id")
                    val currentGeneration = readSetting(db, "state_generation")?.toLongOrNull() ?: -1L
                    val pendingSnapshot = readSetting(db, "pending_outbound_snapshot_id")
                    val pendingGeneration = readSetting(db, "pending_outbound_generation")?.toLongOrNull() ?: -1L
                    if (active == "0" || locked != "1" || currentLineage != lineageId ||
                        currentGeneration != generation || pendingSnapshot != snapshotId ||
                        pendingGeneration != generation
                    ) {
                        return@runCatching false
                    }
                    replaceSetting(db, "active_brain", "0")
                    replaceSetting(db, "transfer_lock", "0")
                    replaceSetting(db, "last_takeover_snapshot_id", snapshotId)
                    replaceSetting(db, "last_takeover_source_device_id", targetDeviceId)
                    replaceSetting(db, "last_takeover_at", System.currentTimeMillis().toString())
                    db.setTransactionSuccessful()
                    true
                } finally {
                    db.endTransaction()
                }
            } finally {
                db.close()
            }
        }.getOrDefault(false)
    }

    private inline fun withWritableDb(
        context: Context,
        crossinline action: (SQLiteDatabase) -> Unit,
    ) {
        runCatching {
            val path = context.getDatabasePath(DB_NAME)
            if (!path.exists()) return
            val db = SQLiteDatabase.openDatabase(
                path.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            )
            try {
                // Native system callbacks can arrive while sqflite is writing.
                // A short busy timeout prevents harmless lifecycle events from
                // being dropped immediately on a transient WAL writer lock.
                runCatching { db.execSQL("PRAGMA busy_timeout = 1500") }
                action(db)
            } finally {
                db.close()
            }
        }
    }

    private fun replaceSetting(db: SQLiteDatabase, key: String, value: String) {
        val values = ContentValues().apply {
            put("key", key)
            put("value", value)
        }
        db.insertWithOnConflict("settings", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    private fun readDeviceId(db: SQLiteDatabase): String? = readSetting(db, "device_id")

    private fun readSetting(db: SQLiteDatabase, key: String): String? {
        db.query(
            "settings",
            arrayOf("value"),
            "key = ?",
            arrayOf(key),
            null,
            null,
            null,
            "1",
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }
}
