import '../models/daily_continuity.dart';

class DailyContinuityPresentation {
  const DailyContinuityPresentation._();

  static String compactSummary(DailyContinuityRecord record) {
    if (record.sharedMoments.isNotEmpty) {
      final moment = record.sharedMoments.first;
      return '${moment.label}：${moment.summary}';
    }
    if (record.carriedThreads.isNotEmpty) {
      final thread = record.carriedThreads.first;
      return '还没说完：${thread.title}${thread.detail.trim().isEmpty ? '' : ' · ${thread.detail.trim()}'}';
    }
    if (record.cares.isNotEmpty) {
      final care = record.cares.first;
      return '${care.label}：${care.text}';
    }
    if (record.messageCount > 0) {
      return '这一天有一些普通相处，没有硬凑成新的关系节点。';
    }
    return '这一天比较安静；安静本身不代表你们的关系退步。';
  }

  static String dayLabel(DailyContinuityRecord record, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toLocal();
    final day = record.windowStart.toLocal();
    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(day.year, day.month, day.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    return '${day.month}月${day.day}日';
  }

  static String formatForPrompt(List<DailyContinuityRecord> records) {
    if (records.isEmpty) {
      return '【近日连续性】\n暂无已形成的近日连续性记录。';
    }
    final buffer = StringBuffer('【近日连续性】\n');
    buffer.writeln(
      '这是本机从真实关系记录、未完成话题、当前有效念头和粗粒度日常感知压缩出的短期桥梁。它不是新的事实来源，也不是 AI 日记。不要因为看见本段就再次创建相同长期记忆或关系事件。',
    );
    for (final record in records.take(2)) {
      buffer.writeln('- ${dayLabel(record)}：');
      if (record.sharedMoments.isNotEmpty) {
        for (final moment in record.sharedMoments.take(2)) {
          buffer.writeln('  · 共同片段：${moment.summary}');
        }
      }
      if (record.carriedThreads.isNotEmpty) {
        final thread = record.carriedThreads.first;
        buffer.writeln('  · 还没说完：${thread.title}${thread.detail.trim().isEmpty ? '' : ' — ${thread.detail.trim()}'}');
      }
      if (record.cares.isNotEmpty) {
        final care = record.cares.first;
        buffer.writeln('  · 她仍在意：${care.text}');
      }
      if (record.awarenessSummaries.isNotEmpty) {
        buffer.writeln('  · 当时的日常背景：${record.awarenessSummaries.take(2).join('；')}');
      }
      if (record.quietDay && record.messageCount <= 0) {
        buffer.writeln('  · 这天较安静；不要把安静自动解释成疏远、降温或关系退步。');
      } else if (record.quietDay) {
        buffer.writeln('  · 有普通相处，但没有新的长期关系节点；不要为了“每天有进展”而夸大。');
      }
    }
    buffer.writeln(
      '使用方式：只在自然相关时延续，不要逐条复述；当前用户新说的话始终比这份短期压缩更优先。',
    );
    return buffer.toString().trim();
  }
}
