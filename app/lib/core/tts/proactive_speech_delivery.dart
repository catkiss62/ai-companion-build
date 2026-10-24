import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/chat_message.dart';

/// A short, renewable claim shared by App and background Flutter engines.
/// Claiming is not evidence of playback. Only completion or an explicit Stop
/// consumes a message; preparation failure/preemption can retry on next open.
class ProactiveSpeechDelivery {
  ProactiveSpeechDelivery(this.db, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;
  static const claimKey = 'proactive_tts_claim_v1';
  static const spokenKey = 'last_proactive_spoken_message_id';
  static const lease = Duration(minutes: 2);
  String? _activeToken;

  Future<void> deliver(ChatMessage message, {
    required Future<bool> Function() play,
    bool Function()? canStart,
  }) async {
    try { await _deliver(message, play: play, canStart: canStart); }
    catch (_) { /* Optional speech cannot fail an already delivered message. */ }
  }

  Future<void> _deliver(ChatMessage message, {
    required Future<bool> Function() play,
    bool Function()? canStart,
  }) async {
    final token = const Uuid().v4();
    final sql = await db.database;
    final claimed = await sql.transaction((txn) async {
      if (canStart?.call() == false) return false;
      final spoken = await _value(txn, spokenKey);
      if (spoken == message.id) return false;
      // A stale surface must not replay an older proactive message.
      final latest = await txn.query('messages', columns: ['id'],
          where: "role = 'assistant' AND is_proactive = 1",
          orderBy: 'created_at DESC, rowid DESC', limit: 1);
      if (latest.isEmpty || latest.single['id'] != message.id) return false;
      final held = _decode(await _value(txn, claimKey));
      if (held['message_id'] == message.id &&
          ((held['until'] as num?)?.toInt() ?? 0) > clock().millisecondsSinceEpoch) return false;
      await _put(txn, claimKey, jsonEncode({
        'message_id': message.id, 'token': token,
        'until': clock().add(lease).millisecondsSinceEpoch,
      }));
      return true;
    });
    if (!claimed) return;
    _activeToken = token;
    var renewing = false;
    final heartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (renewing) return;
      renewing = true;
      try { await _update(token, renew: true); } catch (_) {}
      finally { renewing = false; }
    });
    try {
      if (canStart?.call() == false) return;
      if (await play()) await _update(token, consumed: true);
    } catch (_) {
      // Voice failure must never fail a delivered text message.
    } finally {
      heartbeat.cancel();
      try { await _update(token); } catch (_) {}
      if (_activeToken == token) _activeToken = null;
    }
  }

  /// Capture synchronously before stopping the queue. A late old Stop cannot
  /// consume a newer message, even if that message has claimed native audio.
  Future<void> stopRequested() {
    final token = _activeToken;
    return token == null ? Future<void>.value() : _update(token, consumed: true).catchError((Object _) {});
  }

  Future<void> _update(String token, {bool consumed = false, bool renew = false}) async {
    final sql = await db.database;
    await sql.transaction((txn) async {
      final held = _decode(await _value(txn, claimKey));
      if (held['token'] != token) return;
      if (consumed) await _put(txn, spokenKey, held['message_id'] as String);
      if (renew) {
        held['until'] = clock().add(lease).millisecondsSinceEpoch;
        await _put(txn, claimKey, jsonEncode(held));
      } else {
        await txn.delete('settings', where: 'key = ?', whereArgs: [claimKey]);
      }
    });
  }
  static Map<String, dynamic> _decode(String raw) {
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); }
    catch (_) { return {}; }
  }
  static Future<String> _value(Transaction txn, String key) async {
    final rows = await txn.query('settings', columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? '' : rows.single['value'] as String? ?? '';
  }
  static Future<void> _put(Transaction txn, String key, String value) async {
    await txn.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
