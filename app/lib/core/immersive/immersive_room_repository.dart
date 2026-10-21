import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../ai/generation_cancellation.dart';
import '../database/brain_work_fence.dart';
import '../models/immersive_room.dart';
import '../models/generation_job.dart';
import '../models/chat_language_variant.dart';
import '../models/chat_segment.dart';
import '../personality/personality_catalog.dart';
import '../rules/rule_layer_content_immersive.dart';
import 'immersive_shared_memory_policy.dart';

class ImmersiveRoomRepository {
  ImmersiveRoomRepository(this.db, {this.beforeAssistantCommit, this.beforeDraftCommit});

  /// Blocks/throws only at the last transaction await for deterministic races.
  /// Production callers leave this unset; it cannot bypass admission checks.
  @visibleForTesting
  final Future<void> Function(Transaction txn)? beforeAssistantCommit;
  @visibleForTesting
  final Future<void> Function(Transaction txn)? beforeDraftCommit;

  final AppDatabase db;
  final Uuid _uuid = Uuid();
  static const archivePrefix = 'immersive_archive_pending:';
  static String archiveKey(String roomId) => '$archivePrefix$roomId';
  BrainWorkFence? stateFence;

  Future<T> _write<T>(Future<T> Function(Transaction) action, {
    BrainWorkFence? workFence,
  }) async {
    final fence = workFence ?? stateFence;
    final database = await db.database;
    return database.transaction((txn) async {
      if (fence == null ? !await BrainWorkFence.workAllowed(txn)
          : !await fence.matches(txn)) throw const BrainWorkInvalidated();
      return action(txn);
    });
  }


  Future<List<ImmersiveRoom>> listRooms() async {
    final database = await db.database;
    final rows = await database.rawQuery("SELECT r.*, EXISTS(SELECT 1 FROM settings s "
        "WHERE s.key = ? || r.id AND s.value != '') AS archive_pending "
        "FROM immersive_rooms r ORDER BY CASE r.status WHEN 'active' THEN 0 "
        "WHEN 'paused' THEN 1 ELSE 2 END, r.updated_at DESC", [archivePrefix]);
    return rows.map(ImmersiveRoom.fromDb).toList(growable: false);
  }

  Future<ImmersiveRoom?> roomById(String id) async {
    final database = await db.database;
    final rows = await database.rawQuery("SELECT r.*, EXISTS(SELECT 1 FROM settings s "
        "WHERE s.key = ? || r.id AND s.value != '') AS archive_pending "
        "FROM immersive_rooms r WHERE r.id = ? LIMIT 1", [archivePrefix, id]);
    return rows.isEmpty ? null : ImmersiveRoom.fromDb(rows.first);
  }

  Future<ImmersiveRoom> createRoom({
    required String title,
    required String openingScene,
    required bool inheritCurrentChat,
    String fateWheelEntry = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final activeSpecial = await db.activeSpecialStyleTrial();
    final inheritedSpecialKey = activeSpecial != null &&
            PersonalityCatalog.isKnownSpecial(activeSpecial.styleKey)
        ? activeSpecial.styleKey
        : '';
    final inherited = inheritCurrentChat ? await currentChatEntryContext() : '';
    final entryParts = <String>[
      if (openingScene.trim().isNotEmpty) '【开场设定】\n${openingScene.trim()}',
      if (inherited.isNotEmpty) inherited,
      if (fateWheelEntry.trim().isNotEmpty) fateWheelEntry.trim(),
    ];
    await _write((txn) async {
      await txn.update(
        'immersive_rooms',
        {'status': 'paused', 'updated_at': now},
        where: "status = 'active'",
      );
      await txn.insert('immersive_rooms', {
        'id': id,
        'title': title.trim().isEmpty ? '新的沉浸房间' : title.trim(),
        'status': 'active',
        'novel_rules': immersiveDefaultRoomNovelRules,
        'entry_context': entryParts.join('\n\n'),
        'rolling_summary': '',
        'scene_ledger': openingScene.trim(),
        'shared_memory_summary': '',
        'summarized_message_count': 0,
        'nsfw_active': 0,
        'nsfw_manual_override': '',
        'nsfw_route_source': 'initial',
        'special_style_key': inheritedSpecialKey,
        'special_style_binding': inheritedSpecialKey.isEmpty ? 'inherit' : 'pinned',
        'created_at': now,
        'updated_at': now,
        'ended_at': null,
      });
    });
    return (await roomById(id))!;
  }

  Future<void> activateRoom(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _write((txn) async {
      await txn.update(
        'immersive_rooms',
        {'status': 'paused', 'updated_at': now},
        where: "status = 'active' AND id != ?",
        whereArgs: [id],
      );
      await txn.update(
        'immersive_rooms',
        {'status': 'active', 'updated_at': now, 'ended_at': null},
        where: "id = ? AND status != 'ended'",
        whereArgs: [id],
      );
    });
  }

  Future<ImmersiveRoom?> inheritActiveSpecialStyleIfNeeded(String id) async {
    final current = await roomById(id);
    if (current == null || current.isEnded || current.specialStyleBinding != 'inherit') {
      return current;
    }
    final active = await db.activeSpecialStyleTrial();
    if (active == null || !PersonalityCatalog.isKnownSpecial(active.styleKey)) {
      return current;
    }
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'special_style_key': active.styleKey,
        'special_style_binding': 'pinned',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended' AND special_style_binding = 'inherit'",
      whereArgs: [id],
    ));
    return roomById(id);
  }

  Future<ImmersiveRoom?> pinCurrentSpecialStyle(String id) async {
    final active = await db.activeSpecialStyleTrial();
    if (active == null || !PersonalityCatalog.isKnownSpecial(active.styleKey)) {
      return roomById(id);
    }
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'special_style_key': active.styleKey,
        'special_style_binding': 'pinned',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    ));
    return roomById(id);
  }

  Future<ImmersiveRoom?> disableSpecialStyle(String id) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'special_style_key': '',
        'special_style_binding': 'disabled',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    ));
    return roomById(id);
  }

  Future<void> pauseRoom(String id) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'status': 'paused',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    ));
  }

  Future<void> renameRoom(String id, String title) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'title': title.trim().isEmpty ? '未命名房间' : title.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    ));
  }

  Future<void> deleteRoom(String id) async {
    await _write((txn) async {
      await txn.delete('settings', where: 'key = ?', whereArgs: [archiveKey(id)]);
      await txn.delete('settings', where: 'key = ?', whereArgs: ['room_history_detail_v1:immersive:$id']);
      final modelPrefix = 'immersive_message_model_v1:$id:';
      await txn.delete('settings', where: 'key >= ? AND key < ?',
          whereArgs: [modelPrefix, '$modelPrefix\uffff']);
      await txn.delete(
        'immersive_messages',
        where: 'room_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'interrupted_turn_displays',
        where: 'surface = ? AND context_id = ?',
        whereArgs: ['immersive', id],
      );
      await txn.delete(
        'immersive_rooms',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> updateRoomDetails({
    required String id,
    required String title,
    required String entryContext,
    required String novelRules,
  }) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'title': title.trim().isEmpty ? '未命名房间' : title.trim(),
        'entry_context': entryContext.trim(),
        'novel_rules': novelRules.trim().isEmpty
            ? immersiveDefaultRoomNovelRules
            : novelRules.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    ));
  }

  Future<void> setNsfwManualOverride(String id, bool active) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'nsfw_active': active ? 1 : 0,
        'nsfw_manual_override': active ? 'on' : 'off',
        'nsfw_route_source': active ? 'manual_pending_on' : 'manual_pending_off',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    ));
  }

  Future<void> saveNsfwRoute({
    required String id,
    required bool active,
    required String source,
  }) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'nsfw_active': active ? 1 : 0,
        'nsfw_manual_override': '',
        'nsfw_route_source': source,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    ));
  }

  Future<List<ImmersiveMessage>> messagesForRoom(String roomId) async {
    final database = await db.database;
    final rows = await database.query(
      'immersive_messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ImmersiveMessage.fromDb).toList(growable: false);
  }

  Future<ImmersiveMessage?> messageById(String messageId) async {
    final database = await db.database;
    final rows = await database.query(
      'immersive_messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : ImmersiveMessage.fromDb(rows.single);
  }

  Future<void> saveLanguageVariant(ChatLanguageVariant variant) async {
    if (variant.language == ChatLanguage.chinese ||
        variant.messageId.trim().isEmpty ||
        variant.content.trim().isEmpty ||
        variant.segments.isEmpty) {
      throw StateError('invalid_immersive_message_language_variant');
    }
    final prefix = variant.language == ChatLanguage.japanese ? 'ja' : 'en';
    final updated = await _write((txn) => txn.update(
      'immersive_messages',
      <String, Object?>{
        '${prefix}_content': variant.content,
        '${prefix}_segments_json': ChatSegmentCodec.encode(variant.segments),
      },
      where: 'id = ? AND role = ?',
      whereArgs: [variant.messageId, 'assistant'],
    ));
    if (updated != 1) throw StateError('language_variant_owner_missing');
  }

  Future<List<InterruptedTurnDisplay>> interruptionsForRoom(
    String roomId,
  ) => db.interruptedTurnDisplays(
        surface: 'immersive',
        contextId: roomId,
      );

  Future<InterruptedTurnDisplay?> interruptUserMessageForDisplay({
    required String roomId,
    required String messageId,
    BrainWorkFence? workFence,
    ImmersiveMessage? expectedSourceUser,
  }) => db.interruptImmersiveUserMessageForDisplay(
        roomId: roomId,
        messageId: messageId,
        workFence: workFence ?? stateFence,
        expectedSourceUser: expectedSourceUser,
      );

  /// Assistant admission is tied to the original user snapshot and cancellation
  /// signal. The final synchronous check is the local commit decision point.
  Future<ImmersiveMessage> addAssistantReply({
    required String roomId,
    required ImmersiveMessage sourceUser,
    required GenerationCancellationToken cancellation,
    required BrainWorkFence workFence,
    required String content,
    String reasoningContent = '',
    String formContextJson = '',
    String? expectedDraft,
    Map<String, Object?>? modelRoute,
  }) {
    if (!sourceUser.isUser || sourceUser.roomId != roomId) {
      throw const BrainWorkInvalidated();
    }
    return _addMessage(roomId: roomId, role: 'assistant', content: content,
        reasoningContent: reasoningContent, formContextJson: formContextJson,
        sourceUser: sourceUser, cancellation: cancellation,
        expectedDraft: expectedDraft, workFence: workFence, modelRoute: modelRoute);
  }

  Future<ImmersiveMessage> addMessage({
    required String roomId,
    required String role,
    required String content,
    String reasoningContent = '',
    String formContextJson = '',
  }) => _addMessage(roomId: roomId, role: role, content: content,
      reasoningContent: reasoningContent, formContextJson: formContextJson);

  Future<ImmersiveMessage> _addMessage({
    required String roomId,
    required String role,
    required String content,
    String reasoningContent = '',
    String formContextJson = '',
    ImmersiveMessage? sourceUser,
    GenerationCancellationToken? cancellation,
    BrainWorkFence? workFence,
    String? expectedDraft,
    Map<String, Object?>? modelRoute,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final message = ImmersiveMessage(
      id: _uuid.v4(),
      roomId: roomId,
      role: role,
      content: content.trim(),
      reasoningContent: reasoningContent.trim(),
      formContextJson: formContextJson,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    await _write((txn) async {
      cancellation?.throwIfCancelled();
      final open = await txn.query('immersive_rooms', columns: ['id'],
          where: "id = ? AND status != 'ended'", whereArgs: [roomId], limit: 1);
      if (open.isEmpty) throw const BrainWorkInvalidated();
      if (sourceUser != null) {
        await _requireReplySource(txn, roomId, sourceUser);
      }
      final draftKey = 'immersive_pending_reply_${Uri.encodeComponent(roomId)}';
      if (expectedDraft != null &&
          await BrainWorkFence.value(txn, draftKey) != expectedDraft) {
        throw const BrainWorkInvalidated();
      }
      cancellation?.throwIfCancelled();
      await txn.insert('immersive_messages', {
        'id': message.id,
        'room_id': roomId,
        'role': role,
        'content': message.content,
        'reasoning_content': message.reasoningContent,
        'form_context_json': message.formContextJson,
        'created_at': now,
      });
      if (role == 'assistant' && modelRoute != null) {
        await txn.insert('settings', {'key': 'immersive_message_model_v1:$roomId:${message.id}',
          'value': jsonEncode({'room_id': roomId, 'message_id': message.id,
            for (final key in const ['source','model','provider','reason'])
              if (modelRoute[key] is String) key: modelRoute[key]})},
          conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.update(
        'immersive_rooms',
        {'status': 'active', 'updated_at': now},
        where: "id = ? AND status != 'ended'",
        whereArgs: [roomId],
      );
      if (expectedDraft != null) {
        await txn.insert('settings', {'key': draftKey, 'value': ''},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (sourceUser != null && beforeAssistantCommit != null) {
        await beforeAssistantCommit!(txn);
      }
      // Throwing inside the callback rolls back message, room and draft. A
      // false return after insert would still COMMIT them. No awaits follow.
      cancellation?.throwIfCancelled();
    }, workFence: workFence);
    return message;
  }

  Future<void> saveIncompleteReply({
    required String roomId,
    required ImmersiveMessage sourceUser,
    required GenerationCancellationToken cancellation,
    required BrainWorkFence workFence,
    required String rawDraft,
  }) => _write((txn) async {
    cancellation.throwIfCancelled();
    await _requireReplySource(txn, roomId, sourceUser);
    cancellation.throwIfCancelled();
    await txn.insert('settings', {
      'key': 'immersive_pending_reply_${Uri.encodeComponent(roomId)}',
      'value': rawDraft,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (beforeDraftCommit != null) await beforeDraftCommit!(txn);
    cancellation.throwIfCancelled();
  }, workFence: workFence);

  static Future<void> _requireReplySource(Transaction txn, String roomId,
      ImmersiveMessage source) async {
    final room = await txn.query('immersive_rooms', columns: ['id'],
        where: "id = ? AND status != 'ended'", whereArgs: [roomId], limit: 1);
    final latest = await txn.query('immersive_messages',
        where: 'room_id = ?', whereArgs: [roomId],
        orderBy: 'created_at DESC, rowid DESC', limit: 1);
    if (room.isEmpty || !source.isUser || source.roomId != roomId ||
        latest.isEmpty || !_sameSource(latest.single, source)) {
      throw const BrainWorkInvalidated();
    }
  }

  static bool _sameSource(Map<String, Object?> row, ImmersiveMessage source) =>
      row['id'] == source.id && row['room_id'] == source.roomId &&
      row['role'] == 'user' && row['content'] == source.content &&
      (row['reasoning_content'] ?? '') == source.reasoningContent &&
      (row['form_context_json'] ?? '') == source.formContextJson &&
      row['created_at'] == source.createdAt.millisecondsSinceEpoch;

  /// Deletes a completed assistant reply only when it is still the newest
  /// room message and directly follows a user turn. This keeps regeneration
  /// on one linear room history instead of creating an unseen branch.
  Future<String?> removeLatestAssistantForRegeneration({
    required String roomId,
    required String assistantMessageId,
  }) async {
    return _write<String?>((txn) async {
      final rows = await txn.query(
        'immersive_messages',
        where: 'room_id = ?',
        whereArgs: [roomId],
        orderBy: 'created_at DESC, id DESC',
        limit: 2,
      );
      if (rows.length < 2 ||
          rows.first['id'] != assistantMessageId ||
          rows.first['role'] != 'assistant' ||
          rows[1]['role'] != 'user') {
        return null;
      }
      final roomRows = await txn.query(
        'immersive_rooms',
        columns: const ['summarized_message_count'],
        where: 'id = ? AND status != ?',
        whereArgs: [roomId, 'ended'],
        limit: 1,
      );
      if (roomRows.isEmpty) return null;
      final totalRows = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM immersive_messages WHERE room_id = ?',
        [roomId],
      );
      final total = (totalRows.first['c'] as num?)?.toInt() ?? 0;
      final summarized =
          (roomRows.first['summarized_message_count'] as num?)?.toInt() ?? 0;
      if (summarized >= total) return null;
      await txn.delete(
        'immersive_messages',
        where: 'id = ? AND room_id = ? AND role = ?',
        whereArgs: [assistantMessageId, roomId, 'assistant'],
      );
      await txn.update(
        'immersive_rooms',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [roomId],
      );
      return rows[1]['id'] as String;
    });
  }

  Future<void> saveRollingState({
    required String roomId,
    required String rollingSummary,
    required String sceneLedger,
    required int summarizedMessageCount,
  }) async {
    await _write((txn) => txn.update(
      'immersive_rooms',
      {
        'rolling_summary': rollingSummary.trim(),
        'scene_ledger': sceneLedger.trim(),
        'summarized_message_count': summarizedMessageCount,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [roomId],
    ));
  }

  /// End locally and enqueue archive work in the same transaction. No network
  /// result is required to leave a room, and all original messages stay intact.
  Future<void> endRoomLocally(String roomId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _write((txn) async {
      final changed = await txn.update('immersive_rooms',
          {'status': 'ended', 'ended_at': now, 'updated_at': now},
          where: "id = ? AND status != 'ended'", whereArgs: [roomId]);
      if (changed != 1) return;
      await txn.insert('settings', {'key': archiveKey(roomId),
        'value': jsonEncode({'roomId': roomId, 'endedAt': now,
          'attempts': 0, 'nextAttemptAt': 0})},
        conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> endRoom({
    required String roomId,
    required String archiveSummary,
    required String sceneLedger,
    required List<String> sharedMemories,
    String? expectedArchiveJob,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final admittedMemories = ImmersiveSharedMemoryPolicy.admit(sharedMemories);
    final room = await roomById(roomId);
    final style = PersonalityCatalog.special(room?.specialStyleKey ?? '');
    await _write((txn) async {
      if (expectedArchiveJob != null) {
        if (await BrainWorkFence.value(txn, archiveKey(roomId)) != expectedArchiveJob) {
          throw const BrainWorkInvalidated();
        }
        final expected = jsonDecode(expectedArchiveJob) as Map;
        final current = await txn.query('immersive_rooms', columns: ['status', 'ended_at'],
            where: 'id = ?', whereArgs: [roomId], limit: 1);
        if (current.isEmpty || current.first['status'] != 'ended' ||
            current.first['ended_at'] != expected['endedAt']) {
          throw const BrainWorkInvalidated();
        }
      } else if (room == null || room.isEnded) {
        return;
      }
      await txn.update(
      'immersive_rooms',
      {
        'status': 'ended',
        'rolling_summary': archiveSummary.trim(),
        'scene_ledger': sceneLedger.trim(),
        'shared_memory_summary': admittedMemories.join('\n'),
        'updated_at': now,
        'ended_at': room?.endedAt?.millisecondsSinceEpoch ?? now,
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
    for (final memory in admittedMemories) {
      final normalized = memory.trim();
      if (normalized.isEmpty) continue;
      await db.insertMemory(
        kind: 'shared_experience',
        content: style.key.isEmpty
            ? normalized
            : '[特殊风格体验·${style.label}] $normalized',
        importance: 0.72,
        confidence: 0.82,
        tags: [
          '沉浸房间',
          if (style.key.isNotEmpty) '特殊风格体验',
          if (style.key.isNotEmpty) style.label,
        ],
        source: 'immersive_room:$roomId${style.key.isNotEmpty ? '|special_style:${style.key}' : ''}',
        semanticType: 'shared_experience',
        transaction: txn,
      );
    }
      await txn.delete('settings', where: 'key = ?', whereArgs: [archiveKey(roomId)]);
    });
  }

  Future<String> currentChatEntryContext() async {
    final messages = await db.recentMessages(limit: 8);
    if (messages.isEmpty) return '';
    final buffer = StringBuffer('【进入房间前的普通聊天片段】\n');
    var used = 0;
    for (final message in messages) {
      final text = message.content.trim();
      if (text.isEmpty) continue;
      final remaining = 3200 - used;
      if (remaining <= 0) break;
      final clipped = text.length <= remaining
          ? text
          : '${text.substring(0, remaining)}…';
      buffer.writeln('${message.isUser ? '用户输入' : 'AI正文'}'
          '〔${message.historicalFormLabel}〕：$clipped');
      used += clipped.length;
    }
    return buffer.toString().trim();
  }
}
