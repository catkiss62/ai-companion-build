import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'creative_workspace.dart';

/// Portable, self-contained works. No network credentials or host file paths.
class CreativeContract {
  static const metaPrefix = 'creative_work_v1:';
  static const sourcePrefix = 'creative_source_v1:';
  static const playPrefix = 'creative_play_v1:';
  static const maxHtmlBytes = 800000;
  static const active = {'queued', 'building', 'checking'};
  static Map<String, dynamic> decode(String? raw) =>
      raw == null || raw.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  static String hash(String value) => sha256.convert(utf8.encode(value)).toString();
  static String clip(Object? value, int limit) {
    final text = value?.toString() ?? '';
    return text.length <= limit ? text : text.substring(0, limit);
  }

  static void validateHtml(String html) {
    if (html.trim().isEmpty || utf8.encode(html).length > maxHtmlBytes) {
      throw const FormatException('作品为空或超过 800 KB');
    }
  }

  /// Runs before import mutates the database. Restoring never commissions work.
  static void normalizeImport(Map<String, dynamic> tables) {
    final rawRows = tables['settings'];
    if (rawRows is! List) return;
    final rows = <Object?>[...rawRows];
    tables['settings'] = rows;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map || row['key'] is! String) continue;
      final key = row['key'] as String;
      if (!key.startsWith('creative_')) continue;
      final value = row['value'];
      if (value is! String) throw const FormatException('作品存档损坏');
      if (key == 'creative_focus_v1') { rows[i] = {...row, 'value': ''}; continue; }
      if (key.startsWith(CreativeWorkspace.prefix)) {
        if (value.isEmpty) continue;
        if (utf8.encode(value).length > CreativeWorkspace.maxStateBytes) throw const FormatException('工作检查点过大');
        final state = decode(value);
        CreativeWorkspace.validate(state, key.substring(CreativeWorkspace.prefix.length));
        // A preview from another installation is not permission to publish.
        state['verification'] = <String, Object?>{};
        state['request_inflight'] = false;
        state['next_at'] = 0;
        state['recovery'] = '从存档恢复。保留文件与已完成工具；提交前重新试玩当前版本。';
        rows[i] = {...row, 'value': jsonEncode(state)};
        continue;
      }
      if (value.isEmpty && key.startsWith(playPrefix)) continue;
      if (key.startsWith(sourcePrefix)) {
        validateHtml(value);
        if (key != '$sourcePrefix${hash(value)}') throw const FormatException('作品校验失败');
      } else if (key.startsWith(metaPrefix) || key.startsWith(playPrefix)) {
        // Metadata now includes the original commission and bounded execution
        // trace in addition to the existing thumbnail; play-state stays small.
        final maxBytes = key.startsWith(metaPrefix) ? 400000 : 300000;
        if (utf8.encode(value).length > maxBytes) throw const FormatException('作品状态过大');
        final data = decode(value);
        if (data['schema'] != 1) throw const FormatException('不支持的作品版本');
        if (key.startsWith(metaPrefix)) {
          if (data['id'] != key.substring(metaPrefix.length) || data['updated'] is! int ||
              !{...active, 'paused', 'failed', 'ready', 'deleted'}.contains(data['status'])) {
            throw const FormatException('作品目录损坏');
          }
          for (final field in ['current', 'draft']) {
            final hash = data[field];
            if (hash != null && (hash is! String || (hash.isNotEmpty && !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)))) {
              throw const FormatException('作品版本引用无效');
            }
          }
          if (data['cover'] != null) base64Decode(data['cover'] as String);
        } else if (data['version'] is! String || data['turns'] is! Map || data['reports'] is! List) {
          throw const FormatException('作品游玩状态损坏');
        }
        if (key.startsWith(metaPrefix) && active.contains(data['status'])) {
          data['status'] = 'paused';
          data['note'] = '从存档恢复；等待你继续';
          data['retry_at'] = 0;
          data['preempt'] = 'import';
          rows[i] = {...row, 'value': jsonEncode(data)};
        }
      } else if (key == 'creative_worker_lease_until') {
        rows[i] = {...row, 'value': ''};
      }
    }
  }

}
