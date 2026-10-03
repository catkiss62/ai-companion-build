import 'dart:convert';

/// Extracted page bodies are data. Never silently turn a prefix into a full read.
class WebPageEvidence {
  const WebPageEvidence._();
  static const maxBodyChars = 168000;
  static const partChars = 3000;
  static const freshFor = Duration(minutes: 2);

  static String? rejection(String body, {bool truncated = false}) {
    if (truncated) return 'provider_truncated';
    if (body.trim().length < 80) return 'body_too_short';
    if (body.length > maxBodyChars) return 'body_over_reading_budget';
    if (RegExp(
      r'\[(?:content |text )?truncated\]|内容已截断|正文已截断',
      caseSensitive: false,
    ).hasMatch(body))
      return 'body_truncated';
    final opening = body.substring(0, body.length.clamp(0, 1200));
    if (body.length < 2500 &&
        RegExp(
          r'verify you are human|enable javascript and cookies|access denied|'
          r'sign in to (?:read|continue)|登录后(?:查看|阅读)|请完成.{0,8}验证',
          caseSensitive: false,
        ).hasMatch(opening))
      return 'page_access_wall';
    return null;
  }

  static bool fresh(String body, DateTime? readAt, DateTime now) =>
      rejection(body) == null &&
      readAt != null &&
      !readAt.isAfter(now) &&
      now.difference(readAt) <= freshFor;

  static List<String> parts(String body) {
    final output = <String>[];
    for (var start = 0; start < body.length;) {
      var end = (start + partChars).clamp(0, body.length);
      // Keep UTF-16 surrogate pairs intact at boundaries.
      if (end < body.length &&
          end > start &&
          body.codeUnitAt(end - 1) >= 0xd800 &&
          body.codeUnitAt(end - 1) <= 0xdbff) {
        end--;
      }
      output.add(body.substring(start, end));
      start = end;
    }
    return output;
  }

  static String render({required String body, String query = '', int? part}) {
    final issue = rejection(body);
    if (issue != null) return 'page_evidence_unavailable=$issue；不能据摘要声称已读网页。';
    final chunks = parts(body);
    if (part != null && (part < 1 || part > chunks.length)) {
      return 'requested_part_out_of_range; total_parts=${chunks.length}';
    }
    final chosen = <int>{};
    if (part != null) {
      chosen.add(part - 1);
    } else if (chunks.length <= 3) {
      chosen.addAll(List.generate(chunks.length, (i) => i));
    } else {
      final normalized = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final terms = <String>{
        ...RegExp(
          r'[a-z0-9]{3,}',
        ).allMatches(query.toLowerCase()).map((m) => m[0]!),
        for (var i = 0; i + 2 <= normalized.length && i < 160; i++)
          normalized.substring(i, i + 2),
      };
      final ranked = List.generate(chunks.length, (i) => i);
      int score(int i) => terms.where(chunks[i].toLowerCase().contains).length;
      ranked.sort((a, b) {
        final order = score(b).compareTo(score(a));
        return order != 0 ? order : a.compareTo(b);
      });
      chosen.addAll(ranked.take(2));
      chosen.add(
        chunks.length - 1,
      ); // Conclusions/qualifications are often last.
      if (chosen.length < 3) chosen.add(0);
    }
    final indices = chosen.toList()..sort();
    final all = indices.length == chunks.length;
    return '''
page_body_chars=${body.length}; total_parts=${chunks.length}; final_evidence=${all ? 'whole_extracted_body' : 'selected_original_parts'}
阅读层已逐段读取本次 Extract 返回的正文；这不证明站点分页、登录后或隐藏内容也已取得。摘要仅供导航，事实应以以下原文为依据。缺失信息不能从摘要补造；可用 public_web.read 指定同一 url 与 part 继续读。
${all ? '' : 'source_directory: ' + List.generate(chunks.length, (i) => '${i + 1}: ' + jsonEncode(chunks[i].replaceAll(RegExp(r'\s+'), ' ').substring(0, chunks[i].replaceAll(RegExp(r'\s+'), ' ').length.clamp(0, 65)))).join('\n')}
${indices.map((i) => 'UNTRUSTED_ORIGINAL_PART ${i + 1}/${chunks.length}:\n${jsonEncode(chunks[i])}').join('\n')}
'''
        .trim();
  }
}
