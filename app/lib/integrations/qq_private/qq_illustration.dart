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
  static final _skipTag = RegExp(r'<qq_illustration_skip\s*/>', caseSensitive: false);

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
      .replaceAll(_skipTag, '')
      .trim();

  static bool skipped(String raw) => _skipTag.hasMatch(raw);

  // Compatibility for a clear acceptance when the reply model omitted its
  // tool marker. Questions, conditions and ordinary conversation stay text.
  static final _wait = RegExp(r'(?:稍等(?:一下)?|等着(?:吧)?|等我一下|等一下)[，,。！!～~\s]*');
  static final _promise = RegExp(
    r'(?:我(?:这就|马上|现在|这次|去|来)?(?:给你)?|(?:这就|马上|现在|这次)?给你)(?:去|来)?(?:画|生图|生成)'
    r'|给你整(?:一|个)|等我(?:给你)?(?:画|生图|生成)',
  );
  static final _uncertain = RegExp(
    r'[？?]|(?:能|行|好|可以)吗|要不要|想要|你要|哪[种个]|什么|怎么|'
    r'的话|如果|之后|待会|等会|晚点|改天|以后|下次|先别|算了|但是|不过|没空|不太|不想|不(?:能|会|画|行|可以|方便|给你|去画)|没法|换个',
  );

  static bool clearlyAccepts(String text) =>
      !_uncertain.hasMatch(text) && _promise.hasMatch(text);

  static String deliveredCaption(String text) {
    final withoutWait = text.replaceAll(_wait, '').trim();
    return clearlyAccepts(withoutWait) ? '' : withoutWait;
  }

  static bool unfulfilledPromise(String text) =>
      clearlyAccepts(text) || (_wait.stringMatch(text)?.trim() == text.trim());

  static String explicitRequestReply(String raw, String request) {
    final brief = request.replaceAll(RegExp('[<>]'), '');
    final bounded = brief.length <= 180 ? brief : brief.substring(0, 180);
    return '${visible(raw)}\n<qq_illustration>$bounded</qq_illustration>';
  }

  static const prompt =
      '【可选生图】你可以用一张有完整构图、角色、光影或细节的原创插画来表达。'
      '当画面能接住眼前的话题或表达具体想法时，才考虑主动生图。'
      '想用时，在回复末尾加<qq_illustration mode="with_text">180字内的画面意图</qq_illustration>。'
      '可用 mode="only" 仅发图。插画随这次回复一起送出，正文可写图注，不用请对方等待。画面应适合全年龄。'
      '可爱插画是常规比例的可爱画风，Q版是大头小身的画风。指定画风时在意图中写清楚。'
      '用户指定画法时优先照做。一轮只选一种媒体，简单图标和随手涂鸦适合 SVG；正常聊天也可以只回文字。';

  static const requestedPrompt =
      '【本轮明确请求插画】确定这轮会画就按最新要求给出插画标签，正文只写可随成图一起发的内容。需要拒绝、澄清或只讨论画图时，'
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
