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
  static const _skip = '<qq_illustration_skip/>';

  static QqIllustrationChoice? parse(String raw) {
    final match = _tag.firstMatch(raw);
    final brief = match?.group(2)?.trim();
    return brief == null || brief.isEmpty || brief.length > 180
        ? null
        : QqIllustrationChoice(brief, match?.group(1)?.toLowerCase() == 'only');
  }

  static String visible(String raw) => raw
      .replaceAll(_tag, '')
      .replaceAll(_incomplete, '')
      .replaceAll(_skip, '')
      .trim();

  static bool skipped(String raw) => raw.contains(_skip);

  static String explicitRequestReply(String raw, String request) {
    final brief = request.replaceAll(RegExp('[<>]'), '');
    final bounded = brief.length <= 180 ? brief : brief.substring(0, 180);
    return '${visible(raw)}\n<qq_illustration>$bounded</qq_illustration>';
  }

  static const prompt =
      '【可选生图】你可以用一张有完整构图、角色、光影或细节的原创插画来表达。'
      '想用时，在回复末尾加<qq_illustration mode="with_text">180字内的画面意图</qq_illustration>。'
      '可用 mode="only" 仅发图。插画随这次回复一起送出，正文可写图注，不用请对方等待。画面应适合全年龄。'
      '可爱插画是常规比例的可爱画风，Q版是大头小身的画风。指定画风时在意图中写清楚。'
      '用户指定画法时优先照做。一轮只选一种媒体，简单图标和随手涂鸦适合 SVG；正常聊天也可以只回文字。';

  static const requestedPrompt =
      '【本轮明确请求插画】按最新的画图要求给出插画标签。需要拒绝、澄清或只讨论画图时，'
      '正常回复并在末尾加 $_skip，宿主本轮只发文字。';
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
