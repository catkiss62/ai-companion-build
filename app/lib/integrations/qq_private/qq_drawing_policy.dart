import 'package:sqflite/sqflite.dart';

import '../../core/database/brain_work_fence.dart';
import '../../core/illustration/illustration_cue.dart';
import 'qq_store.dart';

enum QqDrawingFormat { sketch, illustration }

abstract final class QqDrawingPolicy {
  static const _globalLast = 'qq_sketch_auto_global_v1';
  static String _conversationLast(String cid) => 'qq_sketch_auto_last_v1:$cid';
  static final _format = RegExp(
    r'^\s*(?:(?:请你|请|你|麻烦|帮我|给我)\s*)*(?:用|使用)\s*'
    r'(svg|小涂鸦|涂鸦|生图(?:接口|功能)?|nai)\s*(?:帮我|给我)?\s*'
    r'(?:画|绘制|生成|出图|做一|[。！!]|$)',
    caseSensitive: false,
    multiLine: true,
  );

  static QqDrawingFormat? requestedFormat(String text) {
    final format = _format.allMatches(text).lastOrNull?.group(1)?.toLowerCase();
    if (format == null) return null;
    return const {'svg', '涂鸦', '小涂鸦'}.contains(format)
        ? QqDrawingFormat.sketch
        : QqDrawingFormat.illustration;
  }

  static bool requested(String text) =>
      requestedFormat(text) != null ||
      IllustrationCue.explicitRequest(text) ||
      explicitSketch(text);

  static bool explicitSketch(String text) =>
      !RegExp(
        r'(不要|不用|别|不必).{0,6}(画|涂鸦|svg)',
        caseSensitive: false,
      ).hasMatch(text) &&
      RegExp(
        r'(画[一两个张幅]|画画|画点|画下|绘制|涂鸦|svg)',
        caseSensitive: false,
      ).hasMatch(text);

  static Future<bool> autonomousOpportunity(
    QqStore store,
    QqBatch batch,
    int now,
  ) async {
    if (!batch.group ||
        int.parse(batch.id.substring(0, 8), radix: 16) % 40 != 0) {
      return false;
    }
    return _cooldownReady(await store.db.database, batch.cid, now);
  }

  static Future<bool> _cooldownReady(
    DatabaseExecutor db,
    String cid,
    int now,
  ) async {
    final last =
        int.tryParse(await BrainWorkFence.value(db, _conversationLast(cid))) ??
        0;
    final global =
        int.tryParse(await BrainWorkFence.value(db, _globalLast)) ?? 0;
    return now - last >= const Duration(days: 1).inMilliseconds &&
        now - global >= const Duration(hours: 12).inMilliseconds;
  }

  static Future<bool> reserveAutonomous(
    DatabaseExecutor db,
    QqBatch batch,
    int now,
  ) async {
    if (!await _cooldownReady(db, batch.cid, now)) return false;
    for (final key in [_conversationLast(batch.cid), _globalLast]) {
      await db.rawInsert(
        'INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',
        [key, '$now'],
      );
    }
    return true;
  }
}
