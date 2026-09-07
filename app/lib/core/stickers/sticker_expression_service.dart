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
    required String emotionKey,
    required ConversationInitiativePlan conversationPlan,
    required DialogueResponseMode responseMode,
    required bool nsfwActive,
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
    final threshold = switch (mode) {
      'low' => 0.12,
      'frequent' => 0.42,
      _ => 0.24,
    };
    if (roll >= threshold) return null;

    final enabledIds = await packStorage.enabledPackIds();
    final packs = (await packStorage.scanPacks())
        .where((pack) => enabledIds.contains(pack.id))
        .toList(growable: false);
    if (packs.isEmpty) return null;
    final mood = moodForEmotion(emotionKey);
    final recent = await _recentUsageKeys();
    final start = (_unit('$messageId|pack') * packs.length).floor();
    StickerPackMeta? selectedPack;
    List<StickerRecord> selectedPool = const <StickerRecord>[];
    for (var offset = 0; offset < packs.length; offset++) {
      final pack = packs[(start + offset) % packs.length];
      final records = await packStorage.readRecords(pack);
      final pool = records.where((record) {
        if (!record.enabled || recent.contains(record.usageKey)) return false;
        if (moodForTag(record.tag) != mood) return false;
        if (record.toneScope == 'disabled') return false;
        if (record.toneScope == 'nsfw' && !nsfwActive) return false;
        if (record.toneScope == 'bold' && !_boldSpeechActs.contains(conversationPlan.speechAct)) {
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
      final scoreA = _textMatchScore(a, visible);
      final scoreB = _textMatchScore(b, visible);
      final byScore = scoreB.compareTo(scoreA);
      return byScore != 0 ? byScore : a.path.compareTo(b.path);
    });
    final bestScore = _textMatchScore(selectedPool.first, visible);
    final finalists = bestScore > 0
        ? selectedPool
            .where((record) => _textMatchScore(record, visible) == bestScore)
            .take(8)
            .toList(growable: false)
        : selectedPool.take(12).toList(growable: false);
    final index = (_unit('$messageId|sticker') * finalists.length).floor();
    final record = finalists[index.clamp(0, finalists.length - 1).toInt()];
    final source = await packStorage.fileFor(selectedPack, record);
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

  Future<void> markUsed(StickerRecord record, {DateTime? now}) async {
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
              key != record.usageKey) {
            retained.add({'key': key, 'at': at});
          }
        }
      }
    } catch (_) {}
    retained.insert(0, {'key': record.usageKey, 'at': instant.millisecondsSinceEpoch});
    await db.setSetting(
      StickerPackStorage.usageHistorySetting,
      jsonEncode(retained.take(80).toList(growable: false)),
    );
  }

  Future<void> discard(SelectedStickerAttachment selected) =>
      attachmentStorage.deleteAttachmentFiles(selected.attachment);

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

  static int _textMatchScore(StickerRecord record, String text) {
    final tokens = '${record.keywords} ${record.caption}'
        .split(RegExp(r'[\s,，/|]+'))
        .where((token) => token.length >= 2)
        .toSet();
    return tokens.where(text.contains).length;
  }

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
