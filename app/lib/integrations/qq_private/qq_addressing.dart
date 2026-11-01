import 'dart:convert';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'qq_store.dart';
import '../../core/database/brain_work_fence.dart';
import '../../core/qq/qq_mention_targets.dart';

/// Platform self-mention metadata is independent of the bot's own-message
/// echo. The learned ID is scoped to this bot binding and this group only.
/// Addressing never grants owner identity or access to private context.
class QqAddressing {
  QqAddressing(this.store, this.api);
  final QqStore store;
  final QqApi api;
  static const diagnosticKey = 'qq_addressing_diagnostics_v1';
  static const _sources = {'event_at', 'self_echo', 'platform_self',
    'known_group_id', 'other_target', 'unresolved', 'inner_only', 'untrusted_event'};

  static List<Map<String, Object?>> auditRows(String raw) {
    final rows = <Map<String, Object?>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return rows;
      for (final item in decoded.whereType<Map>().toList().reversed.take(32)) {
        if (item['at'] is! int || !_sources.contains(item['source']) ||
            !const {'GROUP_MESSAGE_CREATE', 'GROUP_AT_MESSAGE_CREATE', 'unknown'}.contains(item['event']) ||
            item['mentioned'] is! bool || item['cache_known'] is! bool ||
            item['individual_count'] is! int || item['everyone_count'] is! int ||
            (item['individual_count'] as int) < 0 || (item['individual_count'] as int) > 64 ||
            (item['everyone_count'] as int) < 0 || (item['everyone_count'] as int) > 64 ||
            item['group_fp'] is! String || !RegExp(r'^[a-f0-9]{12}$').hasMatch(item['group_fp'] as String)) continue;
        rows.add({for (final key in ['at', 'source', 'event', 'mentioned',
          'cache_known', 'individual_count', 'everyone_count', 'group_fp']) key: item[key]});
      }
    } catch (_) { /* Corrupt diagnostics cannot become message content. */ }
    return rows.reversed.toList();
  }

  Future<({bool mentioned, bool selfEcho})> inspect(Map<String, dynamic> event,
      BrainWorkFence fence, {required String scope, required String group,
      String? outerText}) => store.write(fence, (sql) async {
    final cid = QqStore.conversationId(scope, 'group', group);
    final fingerprint = QqStore.hash([scope, group]);
    final key = 'qq_self_group_openid_v1:$fingerprint';
    final type = event['_trusted_event_type'];
    final trusted = const {'GROUP_MESSAGE_CREATE', 'GROUP_AT_MESSAGE_CREATE'}.contains(type);
    final original = event['content'] is String ? event['content'] as String : '';
    final text = outerText ?? original;
    final targets = QqMentionTargets.inText(text);
    final rawMentions = event['mentions'];
    final mentions = rawMentions is List ? rawMentions.whereType<Map>().take(64).toList() : <Map>[];
    final individuals = mentions.where(QqMentionTargets.individual).toList();
    final everyone = mentions.where((m) => m['scope'] == 'all').length;
    String self = '';
    try {
      final value = jsonDecode(await BrainWorkFence.value(sql, key) ?? '""');
      if (QqMentionTargets.valid(value)) self = value as String;
    } catch (_) { /* A missing/invalid legacy cache is not an addressing fact. */ }

    Future<({bool mentioned, bool selfEcho})> finish(bool mentioned, String source,
        {bool selfEcho = false, String? learn, bool clear = false}) async {
      if (learn != null && QqMentionTargets.valid(learn)) {
        await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)', [key, jsonEncode(learn)]);
      } else if (clear) {
        await sql.delete('settings', where: 'key=?', whereArgs: [key]);
      }
      if (type == 'GROUP_AT_MESSAGE_CREATE' || mentions.isNotEmpty || targets.isNotEmpty || selfEcho) {
        final rows = auditRows(await BrainWorkFence.value(sql, diagnosticKey) ?? '[]');
        rows.add({'at': DateTime.now().millisecondsSinceEpoch, 'source': source,
          'event': trusted ? type : 'unknown', 'mentioned': mentioned,
          'cache_known': learn != null || self.isNotEmpty && !clear,
          'individual_count': individuals.length, 'everyone_count': everyone,
          'group_fp': fingerprint.substring(0, 12)});
        await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',
          [diagnosticKey, jsonEncode(rows.length <= 32 ? rows : rows.sublist(rows.length - 32))]);
      }
      return (mentioned: mentioned, selfEcho: selfEcho);
    }

    if (!trusted) return finish(false, 'untrusted_event');
    final id = event['id'], author = event['author'];
    final sender = author is Map ? author['member_openid'] : null;
    if (id is String && id.isNotEmpty && sender is String && sender.isNotEmpty) {
      final own = (await sql.query('qq_archive', columns: ['id'],
        where: "conversation_id=? AND role='assistant' AND platform_id=?", whereArgs: [cid, id], limit: 1)).isNotEmpty;
      if (own || api.confirmedMessage(group: true, target: group, platformId: id)) {
        return finish(false, 'self_echo', selfEcho: true,
          learn: QqMentionTargets.valid(sender) ? sender : null);
      }
    }

    // Only top-level platform metadata is read. A flattened forwarded card
    // whose entire body was removed by QqIncoming is not an outer mention.
    final innerOnly = text.trim().isEmpty && original.trim().isNotEmpty;
    final selfEntries = individuals.where((m) => m['is_you'] == true &&
      QqMentionTargets.ids(m).isNotEmpty).toList();
    final learned = <String>{};
    for (final entry in selfEntries) {
      final ids = QqMentionTargets.ids(entry);
      final present = ids.intersection(targets);
      if (present.length == 1) learned.add(present.single);
      else if (QqMentionTargets.valid(entry['member_openid'])) learned.add(entry['member_openid'] as String);
      else if (QqMentionTargets.valid(entry['id'])) learned.add(entry['id'] as String);
      else if (ids.length == 1) learned.add(ids.single);
    }
    final learn = !innerOnly && learned.length == 1 ? learned.single : null;
    if (type == 'GROUP_AT_MESSAGE_CREATE') return finish(true, 'event_at', learn: learn);
    if (innerOnly) return finish(false, 'inner_only');
    if (selfEntries.isNotEmpty) return finish(true, 'platform_self', learn: learn);

    final contradicted = self.isNotEmpty && individuals.any((m) =>
      m['is_you'] == false && QqMentionTargets.ids(m).contains(self));
    if (!contradicted && self.isNotEmpty && targets.contains(self)) {
      return finish(true, 'known_group_id');
    }
    return finish(false, individuals.any((m) => m['is_you'] == false) ? 'other_target' : 'unresolved',
      clear: contradicted);
  });
}
