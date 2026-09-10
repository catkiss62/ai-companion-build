import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../ai/dialogue_expression_plan.dart';
import '../database/app_database.dart';
import '../desire/conversation_initiative_policy.dart';
import '../models/message_attachment.dart';
import '../storage/message_attachment_storage.dart';
import 'sticker_pack.dart';
import 'sticker_pack_storage.dart';

class SelectedStickerAttachment {
  const SelectedStickerAttachment({
    required this.record,
    required this.attachment,
  });

  final StickerRecord record;
  final MessageAttachment attachment;
}

class StickerExpressionService {
  StickerExpressionService({
    AppDatabase? db,
    StickerPackStorage? packStorage,
    MessageAttachmentStorage? attachmentStorage,
  })  : db = db ?? AppDatabase.instance,
        packStorage = packStorage ?? StickerPackStorage(db: db),
        attachmentStorage = attachmentStorage ?? MessageAttachmentStorage();

  final AppDatabase db;
  final StickerPackStorage packStorage;
  final MessageAttachmentStorage attachmentStorage;

  Future<SelectedStickerAttachment?> maybePrepareForOrdinaryReply({
    required String messageId,
    required String text,
    required String latestUserText,
    required String emotionKey,
    required ConversationInitiativePlan conversationPlan,
    required DialogueResponseMode responseMode,
  }) async {
    final mode = (await db.getSetting(StickerPackStorage.modeSetting) ?? 'natural')
        .trim()
        .toLowerCase();
    if (mode == 'off' || responseMode != DialogueResponseMode.casual) return null;
    if (!_eligibleSpeechActs.contains(conversationPlan.speechAct)) return null;
    final visible = text.trim();
    if (visible.isEmpty ||
        visible.length > 100 ||
        visible.contains('```') ||
        visible.contains('http://') ||
        visible.contains('https://')) {
      return null;
    }
    final roll = _unit('$messageId|expression');
    final threshold = ordinaryReplyThreshold(mode);
    if (roll >= threshold) return null;

    final enabledIds = await packStorage.enabledPackIds();
    final packs = (await packStorage.scanPacks())
        .where((pack) => enabledIds.contains(pack.id))
        .toList(growable: false);
    if (packs.isEmpty) return null;
    final mood = moodForEmotion(emotionKey);
    final recent = await _recentUsageKeys();
    final start = (_unit('$messageId|pack') * packs.length).floor();
    final semanticContext = ordinaryReplySemanticContext(
      latestUserText: latestUserText,
      generatedText: visible,
    );
    final candidates = <({StickerPackMeta pack, StickerRecord record})>[];
    for (var offset = 0; offset < packs.length; offset++) {
      final pack = packs[(start + offset) % packs.length];
      final records = await packStorage.readRecords(pack);
      for (final record in records) {
        if (!StickerAgencyPolicy.isAssistantSelectable(record) ||
            recent.contains(record.usageKey)) {
          continue;
        }
        if (record.toneScope == 'bold' &&
            !_boldSpeechActs.contains(conversationPlan.speechAct)) {
          continue;
        }
        candidates.add((pack: pack, record: record));
      }
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final scoreA = ordinaryReplyCandidateScore(
        a.record,
        semanticContext,
        mood,
      );
      final scoreB = ordinaryReplyCandidateScore(
        b.record,
        semanticContext,
        mood,
      );
      final byScore = scoreB.compareTo(scoreA);
      return byScore != 0 ? byScore : a.record.path.compareTo(b.record.path);
    });
    final bestScore = ordinaryReplyCandidateScore(
      candidates.first.record,
      semanticContext,
      mood,
    );
    // An ordinary textual reply must provide positive semantic evidence. A
    // random zero-score fallback can send a completely unrelated sticker.
    if (bestScore <= 0) return null;
    final finalists = candidates
        .where(
          (candidate) =>
              ordinaryReplyCandidateScore(
                candidate.record,
                semanticContext,
                mood,
              ) ==
              bestScore,
        )
        .take(8)
        .toList(growable: false);
    final index = (_unit('$messageId|sticker') * finalists.length).floor();
    final selected = finalists[index.clamp(0, finalists.length - 1).toInt()];
    final record = selected.record;
    final source = await packStorage.fileFor(selected.pack, record);
    final draft = await attachmentStorage.prepareImage(
      sourcePath: source.path,
      source: 'assistant_sticker:${record.packId}',
      mimeType: _mimeFor(record.path),
    );
    final committed = await attachmentStorage.commitDraft(draft, messageId: messageId);
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

  Future<SelectedStickerAttachment?> prepareForExplicitAgentRequest({
    required String messageId,
    required String intent,
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
        if (requestedMood != null && moodForTag(record.tag) != requestedMood) {
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
    final source = await packStorage.fileFor(selectedPack, record);
    final draft = await attachmentStorage.prepareImage(
      sourcePath: source.path,
      source: 'assistant_sticker:${record.packId}',
      mimeType: _mimeFor(record.path),
    );
    final committed = await attachmentStorage.commitDraft(
      draft,
      messageId: messageId,
    );
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

  /// A real sticker can carry the whole conversational act. Explicit sticker
  /// tools and sticker battles always stay sticker-only. Ordinary casual
  /// expression gets a bounded deterministic chance, while questions, tasks
  /// and substantive text keep their words.
  static bool shouldUseStickerOnly({
    required String messageId,
    required String generatedText,
    required ConversationSpeechAct speechAct,
    bool stickerBattle = false,
    bool explicitStickerTool = false,
  }) {
    if (stickerBattle || explicitStickerTool) return true;
    final visible = generatedText.trim();
    if (visible.isEmpty ||
        visible.length > 42 ||
        visible.contains('？') ||
        visible.contains('?') ||
        visible.contains('http://') ||
        visible.contains('https://')) {
      return false;
    }
    if (!const <ConversationSpeechAct>{
      ConversationSpeechAct.react,
      ConversationSpeechAct.tease,
      ConversationSpeechAct.seekAttention,
      ConversationSpeechAct.showNeed,
      ConversationSpeechAct.pauseOrClose,
    }.contains(speechAct)) {
      return false;
    }
    return _unit('$messageId|sticker-only') < 0.30;
  }

  Future<Set<String>> _recentUsageKeys() async {
    final raw = await db.getSetting(StickerPackStorage.usageHistorySetting) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<Map>()
          .take(18)
          .map((item) => item['key']?.toString() ?? '')
          .where((key) => key.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static const _eligibleSpeechActs = <ConversationSpeechAct>{
    ConversationSpeechAct.react,
    ConversationSpeechAct.selfShare,
    ConversationSpeechAct.tease,
    ConversationSpeechAct.seekAttention,
    ConversationSpeechAct.showNeed,
    ConversationSpeechAct.pauseOrClose,
  };

  static const _boldSpeechActs = <ConversationSpeechAct>{
    ConversationSpeechAct.tease,
    ConversationSpeechAct.seekAttention,
    ConversationSpeechAct.showNeed,
  };

  static String moodForEmotion(String key) => switch (key) {
        'excited' || 'happy' || 'affection' || 'confident' || 'playful' => 'happy',
        'angry' || 'disgust' => 'angry',
        'crying' || 'worried' || 'helpless' => 'sad',
        'shy' || 'embarrassed' || 'nervous' || 'flustered' => 'shy',
        'confused' || 'surprised' || 'afraid' => 'confused',
        _ => 'daily',
      };

  static String moodForTag(String tag) {
    final value = tag.trim().toLowerCase();
    if (const {'happy', 'like', 'meow', 'givemoney', 'color'}.contains(value)) {
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

  /// The percentage is conditional on casual-mode, speech-act, length, mood,
  /// pack and recent-use gates. It is intentionally exposed as a pure policy
  /// so UI copy and regression tests cannot drift from the actual behavior.
  static double ordinaryReplyThreshold(String mode) => switch (mode) {
        'low' => 0.12,
        'frequent' => 0.55,
        _ => 0.36,
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

  static String _mimeFor(String path) => switch (p.extension(path).toLowerCase()) {
        '.gif' => 'image/gif',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
