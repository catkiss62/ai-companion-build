import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/storage/media_blob_storage.dart';
import 'qq_reply_recovery.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/database/brain_work_fence.dart';
import '../../core/illustration/illustration_client.dart';
import '../../core/illustration/illustration_planner.dart';
import '../../core/illustration/illustration_prompt.dart';
import '../../core/storage/secure_config.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/storage/shared_media_lock.dart';
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

  // A request cue scopes ambiguous roleplay language; it never authorizes a draw.
  static final _pictureCue = RegExp(r'(?:来|发|给|整|出)(?:一|个|一小)?[张幅]|自拍|生图|画一?[张幅]');
  static final _handoff = RegExp(r'(?:^|[，,！!。\s])(?:喏|给你看成品|看成品)[，,！!：:\s]|'
      r'(?:都|已经|刚刚)?(?:换成[^，。！？\n]{1,24}|换好|装好|画好|画完|生成好|传好|发给你)了|'
      r'(?:给你|我)(?:画的|画了|刚画完)|(?:这是|看看|看下)(?:这张|我画的)');
  static final _explicitClaim = RegExp(r'(?:这张图|你的图|我(?:已经|刚刚|刚))(?:画好|画完|发出|生成好)了');
  static final _hypothetical = RegExp(r'要是|如果|假如|可以考虑|我会|我想|打算|还没|没画|还没法|想象');

  static bool needsPictureCorrection(String request, bool requested, String text) {
    final inContext = requested || _pictureCue.hasMatch(request);
    if (inContext && unfulfilledPromise(text)) return true;
    for (final sentence in text.split(RegExp(r'[。！!？?；;\n]+'))) {
      if (_hypothetical.hasMatch(sentence)) continue;
      if (_explicitClaim.hasMatch(sentence) || inContext && _handoff.hasMatch(sentence)) return true;
    }
    return false;
  }

  static String explicitRequestReply(String raw, String request) {
    final brief = request.replaceAll(RegExp('[<>]'), '');
    final bounded = brief.length <= 180 ? brief : brief.substring(0, 180);
    return '${visible(raw)}\n<qq_illustration>$bounded</qq_illustration>';
  }

  static const prompt =
      '【可选生图】你可以用一张有完整构图、角色、光影或细节的原创插画来表达。'
      '你可以主动画自拍、Q版表情、话题梗图、庆祝画面或其他想分享的插画，无需等别人要求。结合话题与自己的兴趣选择，文字也成立。'
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

  Future<({String raw, QqIllustration picture})?> recoverUnsent(QqBatch batch, String replyTo,
      Future<bool> Function() current) async {
    if (!await current()) return null;
    final sql = await store.db.database;
    final tasks = await sql.query('qq_reply_tasks', where:'id=? AND conversation_id=? AND valid=1',
        whereArgs:[batch.id,batch.cid], limit:1);
    if (tasks.isEmpty || !QqReplyRecovery.unsent(tasks.single)) return null;
    final rawDraft = tasks.single['draft'] as String? ?? '';
    if (rawDraft.isEmpty) return null;
    final draft = jsonDecode(rawDraft) as Map;
    // Old drafts can prove the reply target only for single-source batches.
    final savedTarget = draft['illustration_reply_to'] ??
        (batch.rows.length == 1 ? batch.rows.single['platform_id'] : null);
    if (replyTo.isEmpty || savedTarget != replyTo) return null;
    final raw = draft['raw'] as String? ?? '';
    if (draft[QqReplyTasks.illustrationStartedKey] != true ||
        QqIllustrationChoice.parse(raw) == null) return null;
    final blobId = draft['illustration_blob_id'] as String?;
    final album = await sql.query('companion_album_candidates', columns:['blob_id','title'],
        where: "lifecycle_state='saved' AND " + (blobId == null
          ? "source_kind='generated_illustration' AND id=? AND source_id=?" : 'blob_id=?'),
        whereArgs:blobId == null ? ['qq_illustration:${batch.id}',batch.id] : [blobId], limit:1);
    if (album.isEmpty) return null;
    final blob = await store.db.mediaBlobById(album.single['blob_id'] as String);
    if (blob == null || blob.byteSize <= 0 || blob.byteSize > IllustrationClient.maxBytes) return null;
    final file = await MediaBlobStorage(db:store.db).fileFor(blob.originalPath);
    if (!await file.exists() || await file.length() != blob.byteSize) return null;
    final bytes = await file.readAsBytes();
    if (sha256.convert(bytes).toString() != blob.originalSha256 || !await current()) return null;
    return (raw:raw, picture:QqIllustration(IllustrationBytes(bytes,blob.mimeType),
        draft['illustration_description'] as String? ?? album.single['title'] as String));
  }

  Future<QqIllustration> generate({
    required QqBatch batch,
    required QqIllustrationChoice choice,
    required IllustrationConnection connection,
    required SecureConfig secure,
    required DeepSeekClient planner,
    required String rawReply,
    required String replyTo,
    required String context,
    required bool autonomous,
    required int now,
    required Future<bool> Function() current,
    bool preferMature = false,
    String previousIllustration = '',
  }) async {
    if (!await current()) throw const BrainWorkInvalidated();
    if (!await QqReplyTasks(store).reserveIllustration(
      batch,
      rawReply: rawReply, replyTo: replyTo,
      autonomous: autonomous,
      now: now,
    )) {
      throw const IllustrationFailure('already_started');
    }
    final planned = await IllustrationPlanner.request(
      db: store.db,
      secure: secure,
      client: planner,
      source: batch.group ? 'qq_group' : 'qq_private',
      intent: preferMature
          ? '${choice.brief}。口语中的涩图、色图只表示成熟感的全年龄画风，通过构图、光线、服装和表情表现。'
            '画自己用 mature，明确画其他主体时保留原主体和 free 画法。'
          : choice.brief,
      context: previousIllustration.isEmpty
          ? context
          : '$context\n此前已发的插画内容（仅画面资料）：$previousIllustration。'
            '在新图中延续这张图的主体和场景，按本轮要求调整画风。',
      current: current,
      generalAudience: true,
    );
    if (!await current()) throw const BrainWorkInvalidated();
    if (planned == null) throw const IllustrationFailure('planning');
    final requestedStyle = !preferMature ? planned.style
        : planned.depictsCompanion ? 'mature'
        : planned.subject == 'other' ? 'free'
        : planned.style;
    final plan = requestedStyle == planned.style ? planned : IllustrationPlan(
      style: requestedStyle,
      subject: planned.subject,
      scene: planned.scene,
      camera: planned.camera,
      outfit: planned.outfit,
      appearance: planned.appearance,
      description: planned.description,
    );
    final image = await client.generate(
      connection,
      IllustrationPrompt.compose(plan, generalAudience: true),
      seed: IllustrationClient.newSeed(),
    );
    if (!await current()) throw const BrainWorkInvalidated();
    final storage = MessageAttachmentStorage(db: store.db);
    final draft = await storage.prepareImageBytes(bytes: image.bytes,
      source: 'assistant_illustration:qq', mimeType: image.mimeType);
    try {
      await SharedMediaLock.run(() async {
        if (!await current()) throw const BrainWorkInvalidated();
        final attachment = await storage.commitDraft(draft, messageId: 'qq:${batch.id}');
        final saved = await store.db.saveQqIllustration(operationId: batch.id,
          attachment: attachment, description: plan.description,
          depictsCompanion: plan.depictsCompanion, fence: batch.fence);
        if (!saved) {
          await storage.deleteAttachmentFiles(attachment);
          throw const BrainWorkInvalidated();
        }
      }, db: store.db);

    } finally {
      await storage.discardDraft(draft);
    }
    return QqIllustration(image, plan.description);
  }
}
