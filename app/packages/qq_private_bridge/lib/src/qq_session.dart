import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'qq_api.dart';

typedef QqGenerate = Future<String> Function(String text, List<Map<String, String>> history);
typedef QqGenerateWithContext = Future<String> Function(String text,
    List<Map<String, String>> history, String? acceptedIdentity);

/// A bounded, separate journal. Main-app memory/database is not a dependency.
class QqJournal {
  QqJournal(this.file);
  final File file;
  final List<Map<String, dynamic>> rows = [];
  Future<void> _writes = Future.value();

  Future<void> open() async {
    if (!await file.exists()) return;
    if (await file.length() > 8 * 1024 * 1024) throw const FormatException('QQ journal too large');
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map || raw['version'] != 1 || raw['rows'] is! List || (raw['rows'] as List).length > 160) {
      throw const FormatException('QQ journal invalid');
    }
    for (final item in raw['rows'] as List) {
      final row = Map<String, dynamic>.from(item as Map);
      if (row['id'] is! String || row['user'] is! String || row['state'] is! String || row['at'] is! int) {
        throw const FormatException('QQ journal row invalid');
      }
      // A crash can leave a billable generation or an outbound send unknown.
      // Do not pay again or duplicate a QQ message automatically.
      if (row['state'] == 'working') row['state'] = 'generation_interrupted';
      if (row['state'] == 'sending') row['state'] = 'send_uncertain';
      rows.add(row);
    }
    await save();
  }

  Future<void> save() {
    final finished = rows.where((r) => !const {'queued','working','generated','sending'}.contains(r['state'])).toList();
    if (finished.length > 128) {
      final drop = finished.take(finished.length - 128).toSet();
      rows.removeWhere(drop.contains);
    }
    final data = jsonEncode({'version': 1, 'rows': rows});
    final result = _writes.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.next');
      await temporary.writeAsString(data, flush: true);
      await temporary.rename(file.path);
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> flush() => _writes;
}

class QqPrivateSession {
  QqPrivateSession({required this.journal, required this.owner,
    required this.pairCode, required this.pairExpires, required this.bindOwner,
    required this.allowed, required this.yieldToChat, this.generate, this.generateWithContext,
    required this.send, required this.onStatus, this.contextIdentity,
    this.captureReplyStamp, this.replyCurrent})
      : assert((generate != null) != (generateWithContext != null));
  final QqJournal journal;
  String owner;
  String pairCode;
  final DateTime pairExpires;
  final Future<void> Function(String) bindOwner;
  final Future<bool> Function() allowed;
  final Future<bool> Function() yieldToChat;
  final QqGenerate? generate;
  final QqGenerateWithContext? generateWithContext;
  final Future<void> Function(String owner, String messageId, String text, int sequence) send;
  final void Function(String) onStatus;
  final Future<String?> Function()? contextIdentity;
  final Object? Function()? captureReplyStamp;
  final Future<bool> Function(Object?)? replyCurrent;
  bool _stopped = false;
  bool _draining = false;
  Timer? _poll;
  Future<void> _acceptTail = Future.value();

  void start() {
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(drain()));
    unawaited(drain());
  }

  Future<void> accept(Map<String, dynamic> event) {
    final result = _acceptTail.then((_) => _accept(event));
    _acceptTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _accept(Map<String, dynamic> event) async {
    if (_stopped) return;
    // Defense in depth: even a caller bypassing the gateway cannot submit a
    // group event to the host's private memory callback.
    if (event.containsKey('group_openid') || event.containsKey('guild_id')) return;
    final author = event['author'];
    if (author is! Map || author['bot'] == true) return;
    final sender = (author['user_openid'] ?? author['id'])?.toString() ?? '';
    final id = event['id'];
    if (sender.isEmpty || sender.length > 256 || id is! String || id.isEmpty || id.length > 1024) return;
    final raw = event['content'];
    final text = raw is String ? raw.trim() : '';
    if (owner.isEmpty) {
      if (pairCode.isEmpty || DateTime.now().isAfter(pairExpires) || text != '/绑定 $pairCode') return;
      // Persist identity before allowing any memory lookup, no first-arrival
      // auto-binding. The one-time code is shown only in the local App.
      await bindOwner(sender);
      if (_stopped) return;
      owner = sender; pairCode = '';
      onStatus('bound');
      await _queue(id, '已绑定。这是私聊测试版，可以直接发文字聊天。', fixed: true);
      return;
    }
    if (sender != owner) return;
    if (text.startsWith('/绑定 ')) return;
    if (journal.rows.any((r) => r['id'] == id)) return;
    if (journal.rows.where((r) => const {'queued','working','generated','sending'}.contains(r['state'])).length >= 20) {
      onStatus('queue_full'); return;
    }
    final sentAt = DateTime.tryParse('${event['timestamp']}');
    // Old replayed events must not silently start a new paid model run.
    if (sentAt == null || DateTime.now().difference(sentAt) > const Duration(minutes: 4) ||
        sentAt.difference(DateTime.now()) > const Duration(minutes: 2)) {
      onStatus('message_expired'); return;
    }
    if (text.runes.length > 6000) {
      await _queue(id, '这条文字比较长，测试版请分成几条发给我。', fixed: true); return;
    }
    final attachments = event['attachments'];
    if (attachments is List && attachments.isNotEmpty || text.isEmpty ||
        (event['message_type'] != null && event['message_type'] != 0)) {
      await _queue(id, '首版暂时只接纯文字，图片、语音和引用消息还没有接好。', fixed: true); return;
    }
    await _queue(id, text);
  }

  Future<void> _queue(String id, String text, {bool fixed = false}) async {
    if (journal.rows.any((r) => r['id'] == id)) return;
    final identity = await contextIdentity?.call();
    if (_stopped) return;
    journal.rows.add({'id': id, 'user': fixed ? '' : text, 'reply': fixed ? text : '',
      'fixed': fixed, 'state': fixed ? 'generated' : 'queued',
      if (contextIdentity != null) 'context_identity': identity,
      'at': DateTime.now().millisecondsSinceEpoch, 'sent': 0});
    await journal.save();
    unawaited(drain());
  }

  Future<bool> _current(Map<String, dynamic> row, {bool checkReply = false}) async {
    if (contextIdentity != null) {
      final captured = row['context_identity'];
      if (captured is! String || captured.isEmpty || await contextIdentity!() != captured) return false;
    }
    return !(checkReply && row['fixed'] != true && replyCurrent != null &&
      !await replyCurrent!(row['reply_stamp']));
  }
  Future<void> _invalidate(Map<String, dynamic> row) async {
    row['state'] = 'context_invalidated'; await journal.save(); onStatus('context_invalidated');
  }

  Future<void> drain() async {
    if (_draining || _stopped) return;
    _draining = true;
    try {
      while (!_stopped) {
        final pending = journal.rows.where((r) => const {'queued','generated'}.contains(r['state'])).toList();
        if (pending.isEmpty) return;
        final row = pending.first;
        if (_stopped) return;
        if (!const {'queued','generated'}.contains(row['state'])) continue;
        if (!await _current(row, checkReply: row['state'] == 'generated')) {
          await _invalidate(row); continue;
        }
        if (!await allowed()) { onStatus('brain_paused'); return; }
        if (DateTime.now().millisecondsSinceEpoch - (row['at'] as int) > const Duration(minutes: 4).inMilliseconds) {
          row['state'] = 'message_expired'; await journal.save(); onStatus('message_expired'); continue;
        }
        try {
          if (row['state'] == 'queued') {
            if (await yieldToChat()) { onStatus('waiting_app_chat'); return; }
            final history = <Map<String, String>>[];
            for (final old in journal.rows.where((r) => r['state'] == 'sent' && r['fixed'] != true &&
                (contextIdentity == null || r['context_identity'] == row['context_identity'])).toList().reversed.take(12).toList().reversed) {
              history.add({'role': 'user', 'content': old['user'] as String});
              history.add({'role': 'assistant', 'content': old['reply'] as String});
            }
            row['state'] = 'working'; await journal.save(); onStatus('generating');
            // The host must validate this original identity before starting a
            // model call. Reading a fresh identity inside the generator would
            // reauthorize old work after a snapshot switch at this boundary.
            final reply = (await (generateWithContext != null
                ? generateWithContext!(row['user'] as String, history, row['context_identity'] as String?)
                : generate!(row['user'] as String, history))).trim();
            if (_stopped) return;
            row['reply_stamp'] = captureReplyStamp?.call();
            if (!await _current(row, checkReply: true)) { await _invalidate(row); continue; }
            if (reply.isEmpty) throw QqApiException('model_empty');
            if (reply.runes.length > 7200) throw QqApiException('model_too_long');
            row['reply'] = reply; row['state'] = 'generated'; await journal.save();
          }
          if (_stopped || !await allowed()) return;
          if (!await _current(row, checkReply: true)) { await _invalidate(row); continue; }
          if (DateTime.now().millisecondsSinceEpoch - (row['at'] as int) > const Duration(minutes: 4).inMilliseconds) {
            row['state'] = 'message_expired'; await journal.save(); onStatus('message_expired'); continue;
          }
          final chunks = splitQqText(row['reply'] as String);
          var invalidated = false;
          for (var i = (row['sent'] as int); i < chunks.length; i++) {
            if (_stopped || !await allowed()) return;
            if (!await _current(row, checkReply: true)) {
              await _invalidate(row); invalidated = true; break;
            }
            row['state'] = 'sending'; await journal.save();
            await send(owner, row['id'] as String, chunks[i], i + 1);
            row['sent'] = i + 1;
            row['state'] = 'generated'; await journal.save();
          }
          if (invalidated) continue;
          row['state'] = 'sent'; await journal.save(); onStatus('reply_sent');
        } catch (error) {
          // An uncertain outbound send stays uncertain even if its context
          // changed meanwhile: invalidation must not hide delivery ambiguity.
          if (!(error is QqApiException && error.uncertain) && !await _current(row)) {
            await _invalidate(row); continue;
          }
          row['state'] = error is QqApiException && error.uncertain ? 'send_uncertain' : 'failed';
          await journal.save();
          onStatus(row['state'] == 'send_uncertain' ? 'send_uncertain' : 'reply_failed');
        }
      }
    } catch (_) { onStatus('journal_error');
    } finally { _draining = false; }
  }

  Future<void> stop() async {
    _stopped = true; _poll?.cancel();
    await _acceptTail;
    await journal.flush();
  }
}

List<String> splitQqText(String text) {
  final runes = text.runes.toList();
  return [for (var i = 0; i < runes.length; i += 1800)
    String.fromCharCodes(runes.sublist(i, (i + 1800).clamp(0, runes.length).toInt()))];
}
