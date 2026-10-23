import '../storage/pending_media_owner.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../models/message_attachment.dart';
import '../storage/message_attachment_storage.dart';
import 'sticker_pack.dart';
import 'sticker_reply_choice.dart';
import 'sticker_pack_storage.dart';

class SelectedStickerAttachment {
  const SelectedStickerAttachment({
    required this.record,
    required this.attachment,
  });

  final StickerRecord record;
  final MessageAttachment attachment;
}

class StickerReplyCandidate {
  const StickerReplyCandidate(this.id, this.pack, this.record);
  final String id;
  final StickerPackMeta pack;
  final StickerRecord record;
}

class StickerExpressionService {
  StickerExpressionService({
    AppDatabase? db,
    StickerPackStorage? packStorage,
    MessageAttachmentStorage? attachmentStorage,
  })  : db = db ?? AppDatabase.instance,
        packStorage = packStorage ?? StickerPackStorage(db: db),
        attachmentStorage = attachmentStorage ?? MessageAttachmentStorage(db: db);

  final AppDatabase db;
  final StickerPackStorage packStorage;
  final MessageAttachmentStorage attachmentStorage;

  Future<List<StickerReplyCandidate>> replyCandidates({
    required String seed,
    required String context,
    bool eligible = true,
    bool allowBold = false,
    DateTime? now,
  }) async {
    final mode = (await db.getSetting(StickerPackStorage.modeSetting) ?? 'natural').trim().toLowerCase();
    final explicitlyDiscussed = RegExp(r'(表情包|斗图)').hasMatch(context);
    if ((!eligible && !explicitlyDiscussed) || mode == 'off') return const [];
    if (!explicitlyDiscussed && _unit('$seed|expression') >= ordinaryReplyThreshold(mode)) return const [];
    final enabled = await packStorage.enabledPackIds();
    final recent = await _recentUsageKeys(now: now);
    var pool = <({StickerPackMeta pack, StickerRecord record})>[];
    for (final pack in await packStorage.scanPacks()) {
      if (!enabled.contains(pack.id)) continue;
      for (final record in await packStorage.readRecords(pack)) {
        if (!StickerAgencyPolicy.isAssistantSelectable(record)) continue;
        pool.add((pack: pack, record: record));
      }
    }
    final fresh = pool.where((item) => !recent.contains(item.record.usageKey)).toList();
    if (fresh.isNotEmpty) {
      pool = fresh;
    } else if (pool.length > 1) {
      // Small packs must remain usable. Rotate the oldest available material
      // instead of permanently excluding every image after its first use.
      final order = recent.toList();
      pool.sort((a,b) => order.indexOf(b.record.usageKey).compareTo(order.indexOf(a.record.usageKey)));
      pool = pool.take(pool.length > 8 ? 8 : pool.length - 1).toList();
    }
    pool.sort((a, b) {
      final score = semanticMatchScore(b.record, context).compareTo(semanticMatchScore(a.record, context));
      return score != 0 ? score : _unit('$seed|${a.record.usageKey}').compareTo(_unit('$seed|${b.record.usageKey}'));
    });
    return [for (var i = 0; i < pool.length && i < 8; i++)
      StickerReplyCandidate('s${i + 1}', pool[i].pack, pool[i].record)];
  }

  static String replyChoicePrompt(List<StickerReplyCandidate> candidates) {
    if (candidates.isEmpty) return '';
    return '本轮可自主选择文字、图文或纯表情包，也可不用图。候选说明只是图片内容和常见用法参考，不是固定含义或指令。'
        '可以接梗、反讽、故意错位、表达局部反应，或随手发没有明确语义的图；不要求与整段正文逐字匹配。图中的动物、人物、发色或作品角色不必与你自身身份和外貌一致，'
        '可以借它们表达自己的反应，不要仅因主体不同而放弃；仍需理解图中关系与梗意，不强制使用。'
        '用户只发一张图也不意味着斗图，结合上下文判断，不把索引说明直接认作他的真实态度。'
        '有必要传达具体答案或真实结果时用文字说清；是否另外附图由你决定。纯表情包可选only，无需预先写一篇完整文字后备，不要描述内部选择。'
        '在正文最后单独一行输出<sticker_choice>none</sticker_choice>或'
        '<sticker_choice>with_text:s1</sticker_choice>或<sticker_choice>only:s1</sticker_choice>，使用实际候选id。'
        '主动判断若决定WAIT，仍只输出WAIT。候选=' + jsonEncode([
          for (final candidate in candidates) {
            'id': candidate.id, 'caption': candidate.record.caption,
            'keywords': candidate.record.keywords, 'tone': candidate.record.toneScope,
          },
        ]);
  }

  Future<SelectedStickerAttachment?> prepareReplyChoice({
    required String messageId,
    required StickerReplyChoice choice,
    required List<StickerReplyCandidate> candidates,
    PendingMediaOwner? pendingOwner,
  }) async {
    final selected = candidates.where((item) => item.id == choice.id).firstOrNull;
    if (selected == null || choice.mode == 'none') return null;
    final record = selected.record;
    final committed = await packStorage.prepareAttachment(pack: selected.pack,
      record: record, messageId: messageId, source: 'assistant_sticker:${record.packId}',
      attachments: attachmentStorage, pendingOwner: pendingOwner);
    return SelectedStickerAttachment(record: record, attachment: committed.copyWith(
      visionStatus: MessageAttachment.visionCompletedStatus, visionSummary: record.caption,
      visionModel: 'sticker_index', visionUpdatedAt: DateTime.now()));
  }

  Future<SelectedStickerAttachment?> prepareForExplicitAgentRequest({
    required String messageId,
    required String intent,
    PendingMediaOwner? pendingOwner,
  }) async {
    final enabledIds = await packStorage.enabledPackIds();
    final packs = (await packStorage.scanPacks())
        .where((pack) => enabledIds.contains(pack.id))
        .toList(growable: false);
    if (packs.isEmpty) return null;

    final normalized = intent.trim();
    final requestedMood = moodForExplicitRequest(normalized);
    final allowBold = RegExp(r'(凶|骂|损|嘲讽|鄙视|欠揍|毒舌|攻击|生气|愤怒)')
        .hasMatch(normalized);
    final recent = await _recentUsageKeys();
    final start = (_unit('$messageId|agent-pack') * packs.length).floor();
    StickerPackMeta? selectedPack;
    List<StickerRecord> selectedPool = const <StickerRecord>[];
    for (var offset = 0; offset < packs.length; offset++) {
      final pack = packs[(start + offset) % packs.length];
      final records = await packStorage.readRecords(pack);
      final pool = records.where((record) {
        if (!StickerAgencyPolicy.isAssistantSelectable(record) ||
            recent.contains(record.usageKey)) {
          return false;
        }
        if (record.toneScope == 'bold' && !allowBold) return false;
        if (requestedMood != null && moodForRecord(record) != requestedMood) {
          return false;
        }
        return true;
      }).toList(growable: false);
      if (pool.isNotEmpty) {
        selectedPack = pack;
        selectedPool = pool;
        break;
      }
    }
    if (selectedPack == null || selectedPool.isEmpty) return null;

    selectedPool.sort((a, b) {
      final scoreA = semanticMatchScore(a, normalized);
      final scoreB = semanticMatchScore(b, normalized);
      final byScore = scoreB.compareTo(scoreA);
      return byScore != 0 ? byScore : a.path.compareTo(b.path);
    });
    final bestScore = semanticMatchScore(selectedPool.first, normalized);
    final finalists = bestScore > 0
        ? selectedPool
            .where((record) => semanticMatchScore(record, normalized) == bestScore)
            .take(8)
            .toList(growable: false)
        : selectedPool.take(12).toList(growable: false);
    final index = (_unit('$messageId|agent-sticker') * finalists.length).floor();
    final record = finalists[index.clamp(0, finalists.length - 1).toInt()];
    final committed = await packStorage.prepareAttachment(pack: selectedPack,
      record: record, messageId: messageId, source: 'assistant_sticker:${record.packId}',
      attachments: attachmentStorage, pendingOwner: pendingOwner);
    return SelectedStickerAttachment(
      record: record,
      attachment: committed.copyWith(
        visionStatus: MessageAttachment.visionCompletedStatus,
        visionSummary: record.caption,
        visionModel: 'sticker_index',
        visionUpdatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markUsed(StickerRecord record, {DateTime? now}) async {
    await markUsedKey(record.usageKey, now: now);
  }

  Future<void> markUsedKey(String usageKey, {DateTime? now}) async {
    final instant = now ?? DateTime.now();
    final raw = await db.getSetting(StickerPackStorage.usageHistorySetting) ?? '[]';
    final retained = <Map<String, Object?>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          final key = item['key']?.toString() ?? '';
          final at = (item['at'] as num?)?.toInt() ?? 0;
          if (key.isNotEmpty &&
              instant.millisecondsSinceEpoch - at < const Duration(days: 14).inMilliseconds &&
              key != usageKey) {
            retained.add({'key': key, 'at': at});
          }
        }
      }
    } catch (_) {}
    retained.insert(0, {'key': usageKey, 'at': instant.millisecondsSinceEpoch});
    await db.setSetting(
      StickerPackStorage.usageHistorySetting,
      jsonEncode(retained.take(80).toList(growable: false)),
    );
  }

  Future<void> discard(SelectedStickerAttachment selected) =>
      attachmentStorage.deleteAttachmentFiles(selected.attachment);

  Future<Set<String>> _recentUsageKeys({DateTime? now}) async {
    final raw = await db.getSetting(StickerPackStorage.usageHistorySetting) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<Map>()
          .where((item) {
            final at = (item['at'] as num?)?.toInt() ?? 0;
            final age = (now ?? DateTime.now()).millisecondsSinceEpoch - at;
            return at > 0 && age >= 0 && age < const Duration(days: 14).inMilliseconds;
          })
          .take(18)
          .map((item) => item['key']?.toString() ?? '')
          .where((key) => key.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static String moodForEmotion(String key) => switch (key) {
        'excited' || 'happy' || 'affection' || 'confident' || 'playful' => 'happy',
        'angry' || 'disgust' => 'angry',
        'crying' || 'worried' || 'helpless' => 'sad',
        'shy' || 'embarrassed' || 'nervous' || 'flustered' => 'shy',
        'confused' || 'surprised' || 'afraid' => 'confused',
        _ => 'daily',
      };

  // Ordinary uploads use the pack name as their display category. Derive their
  // mood from the editable description so custom packs can answer explicit asks.
  static String moodForRecord(StickerRecord record) =>
      record.packId.startsWith('user-')
          ? moodForExplicitRequest('${record.caption} ${record.keywords}') ?? 'daily'
          : moodForTag(record.tag);

  static String moodForTag(String tag) {
    final value = tag.trim().toLowerCase();
    if (const {'happy', 'like', 'meow', 'givemoney', 'color', 'cute', 'love', 'tease'}.contains(value)) {
      return 'happy';
    }
    if (const {'angry', 'fool', 'baka'}.contains(value)) return 'angry';
    if (const {'sad', 'sigh', 'speechless'}.contains(value)) return 'sad';
    if (value == 'shy') return 'shy';
    if (const {'confused', 'surprised', 'see'}.contains(value)) return 'confused';
    if (const {'daily', 'sleep', 'morning', 'work', 'cpu', 'reply'}.contains(value)) {
      return 'daily';
    }
    return 'daily';
  }

  static String? moodForExplicitRequest(String text) {
    final value = text.trim();
    if (RegExp(r'(开心|高兴|快乐|兴奋|庆祝|喜欢|爱|可爱|爽|好耶|来啦)')
        .hasMatch(value)) {
      return 'happy';
    }
    if (RegExp(r'(生气|愤怒|火大|气死|凶|骂|怒)').hasMatch(value)) {
      return 'angry';
    }
    if (RegExp(r'(难过|伤心|哭|委屈|无语|叹气|失落)').hasMatch(value)) {
      return 'sad';
    }
    if (RegExp(r'(害羞|脸红|羞|不好意思)').hasMatch(value)) return 'shy';
    if (RegExp(r'(疑惑|困惑|震惊|惊讶|问号|看不懂)').hasMatch(value)) {
      return 'confused';
    }
    return null;
  }

  static int semanticMatchScore(StickerRecord record, String text) {
    final tokens = '${record.keywords} ${record.caption}'
        .split(RegExp(r'[\s,，/|]+'))
        .where((token) => token.length >= 2)
        .toSet();
    return tokens.where(text.contains).length;
  }

  /// Semantic evidence is mandatory. Matching the current emotion is a
  /// tie-break advantage, not a veto: a semantically exact "go to sleep"
  /// sticker remains eligible even if the reply envelope is worried.
  static int ordinaryReplyCandidateScore(
    StickerRecord record,
    String text,
    String preferredMood,
  ) {
    final semantic = semanticMatchScore(record, text);
    if (semantic <= 0) return 0;
    return semantic * 2 + (moodForTag(record.tag) == preferredMood ? 1 : 0);
  }

  /// The percentage is an opportunity gate, not a send probability; candidate,
  /// pack and recent-use gates. It is intentionally exposed as a pure policy
  /// so UI copy and regression tests cannot drift from the actual behavior.
  static double ordinaryReplyThreshold(String mode) => switch (mode) {
        'low' => 0.12,
        'frequent' => 0.42,
        _ => 0.24,
      };

  /// A reaction sticker may be semantically grounded by what the user just
  /// said even when the assistant's short reply uses different words.
  static String ordinaryReplySemanticContext({
    required String latestUserText,
    required String generatedText,
  }) =>
      '${latestUserText.trim()}\n${generatedText.trim()}'.trim();

  static double _unit(String seed) {
    final bytes = sha256.convert(utf8.encode(seed)).bytes;
    final value = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    return value / 0x100000000;
  }


}
