package com.catkiss.senlive2dcompanion.smoke

import android.database.CursorWindow
import android.database.sqlite.SQLiteBlobTooBigException
import android.database.sqlite.SQLiteCursor
import android.database.sqlite.SQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream

/** Real Android CursorWindow reproduction; FFI tests cover the Dart reader. */
@RunWith(AndroidJUnit4::class)
class SettingsCursorWindowSmokeTest {
    @Test fun oversizedSettingsAreReadCompletelyThroughBoundedBlobChunks() {
        SQLiteDatabase.create(null).use { db ->
            db.execSQL("CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            val value = "汉🙂\u0000尾".repeat(350000) + "🧭结束"
            val expected = value.toByteArray(Charsets.UTF_8)
            assertTrue(expected.size > 3 * 1024 * 1024)
            db.execSQL("INSERT INTO settings VALUES (?, ?)", arrayOf("large", value))
            db.execSQL("INSERT INTO settings VALUES (?, ?)", arrayOf("small", "保留"))
            db.execSQL("INSERT INTO settings VALUES (?, ?)", arrayOf("empty", ""))
            var legacyFailed = false
            try {
                (db.rawQuery("SELECT * FROM settings", null) as SQLiteCursor).use { cursor ->
                    cursor.setWindow(CursorWindow("legacy-settings", 512L * 1024L))
                    while (cursor.moveToNext()) cursor.getString(1)
                }
            } catch (_: SQLiteBlobTooBigException) { legacyFailed = true }
            assertTrue("Legacy SELECT * must reproduce the Android failure", legacyFailed)

            db.beginTransaction()
            try {
                val restored = linkedMapOf<String, String>()
                val chunkBytes = 64 * 1024
                val sql = "SELECT key, length(CAST(value AS BLOB)) AS value_bytes, " +
                    "substr(CAST(value AS BLOB), 1, ?) AS value_chunk FROM settings ORDER BY key"
                (db.rawQuery(sql, arrayOf(chunkBytes.toString())) as SQLiteCursor).use { cursor ->
                    cursor.setWindow(CursorWindow("bounded-settings", 512L * 1024L))
                    while (cursor.moveToNext()) {
                        val key = cursor.getString(0)
                        val length = cursor.getInt(1)
                        val first = cursor.getBlob(2) ?: byteArrayOf()
                        assertTrue(first.size <= chunkBytes)
                        val bytes = ByteArrayOutputStream(length)
                        bytes.write(first)
                        var offset = first.size
                        while (offset < length) {
                            val count = minOf(chunkBytes, length - offset)
                            val partSql = "SELECT substr(CAST(value AS BLOB), ?, ?) AS value_chunk " +
                                "FROM settings WHERE key = ?"
                            (db.rawQuery(partSql, arrayOf((offset + 1).toString(), count.toString(), key)) as SQLiteCursor).use { part ->
                                part.setWindow(CursorWindow("settings-chunk", 512L * 1024L))
                                assertTrue(part.moveToFirst())
                                val data = part.getBlob(0)
                                assertEquals(count, data.size)
                                bytes.write(data)
                                offset += data.size
                            }
                        }
                        if (key == "large") assertArrayEquals(expected, bytes.toByteArray())
                        restored[key] = bytes.toString("UTF-8")
                    }
                }
                assertEquals(value, restored["large"])
                assertEquals("保留", restored["small"])
                assertEquals("", restored["empty"])
                assertEquals(3, restored.size)
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
    }
}
