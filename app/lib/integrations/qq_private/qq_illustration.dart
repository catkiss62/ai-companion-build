import '../../core/ai/deepseek_client.dart';
import '../../core/database/brain_work_fence.dart';
import '../../core/illustration/illustration_client.dart';
import '../../core/illustration/illustration_planner.dart';
import '../../core/illustration/illustration_prompt.dart';
import '../../core/storage/secure_config.dart';
import 'qq_reply_tasks.dart';
import 'qq_store.dart';

class QqIllustrationChoice {
  const QqIllustrationChoice(this.brief, this.only);

  final String brief;
  final bool only;
  static final _tag = RegExp(
    r'<qq_illustration(?:\s+mode="(with_text|only)")?\s*>([\s\S]*?)</qq_illustration>',
    caseSensitive: false,
  );
  static final _incomplete = RegExp(
    r'<qq_illustration\b[\s\S]*$',
    caseSensitive: false,
  );

  static QqIllustrationChoice? parse(String raw) {
    final match = _tag.firstMatch(raw);
    final brief = match?.group(2)?.trim();
    return brief == null || brief.isEmpty || brief.length > 180
        ? null
        : QqIllustrationChoice(brief, match?.group(1)?.toLowerCase() == 'only');
  }

  static String visible(String raw) =>
      raw.replaceAll(_tag, '').replaceAll(_incomplete, '').trim();

  static const prompt =
      '【可选生图】你可以用一张有完整构图、角色、光影或细节的原创插画来表达。'
      '想用时，在回复末尾加<qq_illustration mode="with_text">180字内的画面意图</qq_illustration>。'
      '可用 mode="only" 仅发图。图完成前只能说打算画，画面应适合全年龄。'
      '用户指定画法时优先照做。一轮只选一种媒体，简单图标和随手涂鸦适合 SVG；正常聊天也可以只回文字。';
}

class QqIllustration {
  const QqIllustration(this.image, this.description);

  final IllustrationBytes image;
  final String description;

  String get filename => switch (image.mimeType) {
    'image/jpeg' => 'illustration.jpg',
    'image/webp' => 'illustration.webp',
    _ => 'illustration.png',
  };
}

class QqIllustrationService {
  const QqIllustrationService(this.store, this.client);

  final QqStore store;
  final IllustrationClient client;

  Future<QqIllustration> generate({
    required QqBatch batch,
    required QqIllustrationChoice choice,
    required IllustrationConnection connection,
    required SecureConfig secure,
    required DeepSeekClient planner,
    required String rawReply,
    required String context,
    required bool autonomous,
    required int now,
    required Future<bool> Function() current,
  }) async {
    if (!await current()) throw const BrainWorkInvalidated();
    if (!await QqReplyTasks(store).reserveIllustration(
      batch,
      rawReply: rawReply,
      autonomous: autonomous,
      now: now,
    )) {
      throw const IllustrationFailure('already_started');
    }
    final plan = await IllustrationPlanner.request(
      db: store.db,
      secure: secure,
      client: planner,
      source: batch.group ? 'qq_group' : 'qq_private',
      intent: choice.brief,
      context: context,
      current: current,
      generalAudience: true,
    );
    if (!await current()) throw const BrainWorkInvalidated();
    if (plan == null) throw const IllustrationFailure('planning');
    final image = await client.generate(
      connection,
      IllustrationPrompt.compose(plan, generalAudience: true),
      seed: IllustrationClient.newSeed(),
    );
    if (!await current()) throw const BrainWorkInvalidated();
    return QqIllustration(image, plan.description);
  }
}
