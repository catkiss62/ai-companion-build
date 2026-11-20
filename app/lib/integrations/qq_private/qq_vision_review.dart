import 'dart:collection';
import '../../core/qq/qq_mention_targets.dart';
import '../../core/qq/qq_message_material.dart';

typedef QqReviewSource = ({Map<String, Object?> row, List<String?> urls});

/// Temporary attachment locators for questions about recently received images.
/// No image bytes or locators enter archives, diagnostics or model prompts.
class QqVisionReview {
  static const _groupImageLimit = 10;
  static const _privateLifetime = Duration(minutes: 4);
  static const _recentMs = 90 * 1000;
  final _privateSources = <int, QqReviewSource>{};
  final _groupSources = <String, SplayTreeMap<int, QqReviewSource>>{};
  final _observations = <String, String>{};

  static final _picture = RegExp(r'图|截图|动图|画面|照片|表情包|附件');
  static final _detail = RegExp(
    r'写|读|文字|字样|字幕|水印|数字|号码|标题|小字|那行|角落|[上下左右]角|'
    r'[上下左右]边|第[一二三四五六七八\d]+行|颜色|背景|标志|'
    r'按钮|选项|对话框|报错|时间|日期|清[楚晰]|辨认|动作|变化|最后|'
    r'意思|是谁|是什么|是啥|在干[什啥]|[几多]个|多少',
  );
  static final _question = RegExp(
    r'[？?]|什么|啥|几|多少|哪|是谁|是不是|有没有|看得|能否|能不能|帮.*看|念一下|读一下|辨认',
  );
  static final _lookAgain = RegExp(r'重新[看读]|再[看读]一[遍次下眼]|仔细[看读]|放大[看读]|看清[楚晰]');
  static final _number = RegExp(r'第\s*([一二三四五六七八1-8])\s*[张幅]');

  static String questionFor(Map<String, Object?> row, {required bool linked}) {
    final comment = QqMentionTargets.withoutLeadingMentions(
      row['content'] as String,
    ).trim();
    if (!linked && !_picture.hasMatch(comment)) return '';
    if (!_lookAgain.hasMatch(comment) &&
        !(_detail.hasMatch(comment) && _question.hasMatch(comment)))
      return '';
    return QqMessageMaterial.bound(
      comment.replaceAll(
        RegExp(r'https?://[^\s<>]+', caseSensitive: false),
        '[链接已省略]',
      ),
      360,
    );
  }

  static String followupQuestion(Map<String, Object?> row) => questionFor(
    row,
    linked:
        QqMessageMaterial.fromRow(row).kind == 'quote' ||
        (row['reply_to'] as String? ?? '').isNotEmpty,
  );

  static int? ordinalFor(String question, int count) {
    final match = _number.firstMatch(question);
    if (match == null) return count == 1 ? 0 : null;
    final digit = match.group(1)!;
    final ordinal =
        (int.tryParse(digit) ?? ('一二三四五六七八'.indexOf(digit) + 1)) - 1;
    return ordinal >= 0 && ordinal < count ? ordinal : null;
  }

  void remember(Map<String, Object?> row, List<String> urls, int now, {required bool group}) {
    if (urls.isEmpty) return;
    final seq = row['seq'] as int;
    final QqReviewSource source = (row: row, urls: List<String?>.of(urls));
    if (!group) {
      prune(now);
      if (now - (row['received_at'] as int) >= _privateLifetime.inMilliseconds) return;
      if (!_privateSources.containsKey(seq) && _privateSources.length >= 32) {
        _privateSources.remove(_privateSources.keys.first);
      }
      _privateSources[seq] = source;
      return;
    }

    final cid = row['conversation_id'] as String;
    final sources = _groupSources.putIfAbsent(cid, () => SplayTreeMap<int, QqReviewSource>());
    if (sources.containsKey(seq)) return;
    sources[seq] = source;
    var remaining = _groupImageLimit;
    // Archive sequence and original attachment order determine recency, even
    // if two incoming messages finish processing in a different order.
    for (final key in sources.keys.toList().reversed) {
      if (remaining == 0) {
        sources.remove(key);
        continue;
      }
      final slots = sources[key]!.urls;
      for (var i=slots.length-1; i>=0; i--) {
        if (slots[i] == null) continue;
        if (remaining > 0) {
          remaining--;
        } else {
          slots[i] = null; // Preserve the original ordinal for a quoted album.
        }
      }
    }
  }

  void prune(int now) => _privateSources.removeWhere(
    (_, source) => now - (source.row['received_at'] as int) >= _privateLifetime.inMilliseconds,
  );

  QqReviewSource? resolve(Map<String, Object?> focus, int now, int resetAt) {
    prune(now);
    final material = QqMessageMaterial.fromRow(focus);
    final reply = focus['reply_to'] as String? ?? '';
    final reference = material.reference;
    final quoted =
        material.kind == 'quote' || reply.isNotEmpty || reference.isNotEmpty;
    final sources = _groupSources[focus['conversation_id']] ?? _privateSources;
    final candidates = sources.values
        .where((source) {
          final row = source.row;
          if (row['conversation_id'] != focus['conversation_id'] ||
              row['accepted_identity'] != focus['accepted_identity'] ||
              row['accepted_policy'] != focus['accepted_policy'] ||
              (row['seq'] as int) >= (focus['seq'] as int) ||
              (row['observed_at'] as int) < resetAt)
            return false;
          if (quoted) {
            if (reply.isEmpty && reference.isEmpty) return false;
            return (reply.isEmpty || row['platform_id'] == reply) &&
                (reference.isEmpty ||
                    QqMessageMaterial.fromRow(row).index == reference);
          }
          return now - (row['received_at'] as int) <= _recentMs;
        })
        .take(2)
        .toList();
    return candidates.length == 1 ? candidates.single : null;
  }

  String? cached(String key) => _observations[key];

  void record(String key, String text) {
    if (!_observations.containsKey(key) && _observations.length >= 16) {
      _observations.remove(_observations.keys.first);
    }
    _observations[key] = QqMessageMaterial.bound(text, 1600);
  }

  void clear() {
    _privateSources.clear();
    _groupSources.clear();
    _observations.clear();
  }
}
