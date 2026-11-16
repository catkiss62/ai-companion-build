import 'package:sqflite/sqflite.dart';

import '../../core/database/brain_work_fence.dart';
import '../../core/illustration/illustration_cue.dart';
import 'qq_store.dart';

enum QqDrawingFormat { sketch, illustration }

abstract final class QqDrawingPolicy {
  static const _globalLast = 'qq_sketch_auto_global_v1';
  static String _conversationLast(String cid) => 'qq_sketch_auto_last_v1:$cid';
  static const _illustrationCooldown = Duration(minutes: 5);
  static String _illustrationLast(String cid) =>
      'qq_illustration_auto_last_v1:$cid';
  static final _format = RegExp(
    r'^\s*(?:(?:请你|请|你|麻烦|帮我|给我)\s*)*(?:用|使用)\s*'
    r'(svg|小涂鸦|涂鸦|生图(?:接口|功能)?|nai)\s*(?:帮我|给我)?\s*'
    r'(?:画|绘制|生成|出图|做一|的\s*(?:q\s*版|chibi|(?:可爱|成熟)(?:画风|版))|[。！!]|$)',
    caseSensitive: false,
    multiLine: true,
  );
  static final _matureImageRequest = RegExp(
    r'(?:^|[。！？!?；;])\s*(?:(?:那就|那|再|你|请|帮我|给我|麻烦|能不能|可以|试试|试着)\s*)*'
    r'(?:用(?:生图(?:接口|功能)?|nai)\s*)?'
    r'(?:(?:画|生成|来|发|整|出|做|给我|给)(?:一)?(?:张|幅|个|点)|求(?:一?张)?)\s*'
    r'[^\n。！？!?；;]{0,24}(?:涩图|(?<![彩颜调上填着配纯单双色红黄蓝绿黑白紫橙粉灰棕金银底原无])色图)',
    caseSensitive: false,
  );
  static final _matureVariation = RegExp(
    r'(?:更|不够|再|太不)[涩色](?:一点|一些|一点点|点|的|[啊呀些吧呗嘛吗]|(?=[\s，。！？!?]|$))',
  );
  static final _matureFollowup = RegExp(
    r'^\s*(?:(?:那就|那|能不能|可以|这张|那张|刚才的|这图|有点|感觉|还|还是|有点儿|想要)\s*)*'
    r'(?:更|不够|再|太不)[涩色](?:一点点|一点|一些|点|的)?\s*(?:[了啊呀吧呗嘛吗~～，。！？!?\s]+)?$',
  );
  static final _explicitStyle = RegExp(
    r'q\s*版|chibi|大头小身|画风|风格|(?:写实|像素|水彩|油画|漫画|黑白|国风|赛博|可爱|成熟)风',
    caseSensitive: false,
  );
  static final _notCreating = RegExp(
    r'(?:不来|别来|不用来|不要来|别画|不要画|不用画)|相册|图库|现成|提示词|找一?张|搜一?张',
  );
  static final _directMatureShorthand = RegExp(r'^\s*(?:涩图|色图)\s*[。！!？?～~]*$');
  static final _redraw = RegExp(r'再画|再来|重画|重新画|刚才|上一张|这张|那张');

  static bool requestsMatureArtwork(
    String text, {
    bool directlyMentioned = false,
  }) =>
      !IllustrationCue.vetoed(text) &&
      !_notCreating.hasMatch(text) &&
      (_matureImageRequest.hasMatch(text) ||
          directlyMentioned && _directMatureShorthand.hasMatch(text) ||
          _matureVariation.hasMatch(text) &&
              IllustrationCue.explicitRequest(text));

  static bool continuesMatureArtwork(String text) =>
      _matureFollowup.hasMatch(text) ||
      _redraw.hasMatch(text) &&
          _matureVariation.hasMatch(text) &&
          requestsMatureArtwork(text);

  static bool hasExplicitStyle(String text) => _explicitStyle.hasMatch(text);

  static QqDrawingFormat? requestedFormat(String text) {
    final format = _format.allMatches(text).lastOrNull?.group(1)?.toLowerCase();
    if (format == null) {
      return IllustrationCue.requestsStyledArtwork(text) ||
              IllustrationCue.requestsNewSelfie(text)
          ? QqDrawingFormat.illustration
          : null;
    }
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

  static Future<bool> autonomousIllustrationOpportunity(
    QqStore store,
    QqBatch batch,
    int now,
  ) async {
    return batch.group &&
        await _illustrationCooldownReady(
          await store.db.database,
          batch.cid,
          now,
        );
  }

  static Future<bool> reserveAutonomousIllustration(
    DatabaseExecutor db,
    QqBatch batch,
    int now,
  ) async {
    if (!batch.group || !await _illustrationCooldownReady(db, batch.cid, now)) {
      return false;
    }
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',
      [_illustrationLast(batch.cid), '$now'],
    );
    return true;
  }

  static Future<bool> _illustrationCooldownReady(
    DatabaseExecutor db,
    String cid,
    int now,
  ) async {
    final last = int.tryParse(
      await BrainWorkFence.value(db, _illustrationLast(cid)),
    );
    return last == null || now - last >= _illustrationCooldown.inMilliseconds;
  }
}
