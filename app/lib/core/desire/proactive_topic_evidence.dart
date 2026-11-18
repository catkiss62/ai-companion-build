import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../memory/conversation_recall_policy.dart';
import '../memory/local_semantic_index.dart';
import '../memory/memory_grounding_policy.dart';
import '../models/chat_message.dart';
import '../models/memory_item.dart';

enum TopicProgress { ongoing, completed, cancelled }

class ProactiveTopicEvidence {
  const ProactiveTopicEvidence(this.db);
  final AppDatabase db;

  static final _titles = RegExp(r'《([^《》]{2,32})》');
  static final _viewingTitle = RegExp(
    r'(?:电视剧|电影|动画|番剧)[：:\s]*([A-Za-z0-9\u3400-\u9fff·]{2,20}?)(?=到第|的第|第|看|[，。！？、\s]|$)|'
    r'(?:接着看|继续看|重看|重刷)([A-Za-z0-9\u3400-\u9fff·]{2,20}?)(?=到第|的第|第|了|咯|啦|[，。！？、\s]|$)',
  );
  static final _viewingProgress = RegExp(
    r'有没有看|没看过|看过|二刷|第\s*[0-9一二三四五六七八九十百两]+\s*[集季话]|看(?:到|完|了没)|追剧|追到|重[看刷]',
  );
  static final _ongoing = RegExp(
    r'第\s*[0-9一二三四五六七八九十百两]+\s*[集季话]|看到|追到|接着看|重[看刷]|二刷|重新开始|正在|还(?:没|在|差)|只做了|进度|约定|约好了|计划|准备',
  );
  static final _viewingStateCue = RegExp(
    r'第\s*[0-9一二三四五六七八九十百两]+\s*[集季话]|(?:还|正|正在|接着|继续)看|看(?:到|完)|追(?:到|完)|刷完|重[看刷]|二刷|不(?:看|追)了|弃剧',
  );
  static final _viewingDone = RegExp(r'看完|追完|刷完');
  static final _workDone = RegExp(r'做完|做好|弄完|搞定|完成');
  static final _cancelled = RegExp(r'不(?:看|追|做|弄)了|弃剧|放弃了|取消了');
  static final _uncertain = RegExp(
    r'[?？]|(?:吗|么)$|是不是|是否|要不要|(?:还|都|也)?没(?:有)?(?:看完|追完|刷完|做完|做好|弄完|搞定|完成)|(?:等|就|得|想|准备|打算|快|能|能否|希望|如果|还差).{0,4}(?:看完|追完|刷完|做完|完成)|看了没',
  );
  static final _otherActor = RegExp(
    r'(?:朋友|室友|同事|家人|家里人|我爸|我妈|我哥|我姐|他|她|他们|她们|主角)(?:也|都|刚|才|已经|正在|还|昨天|今天|说)?(?:看|追|刷|做|弄|完成|不看|不做)|(?:听说|据说|转述)',
  );
  static final _switchWork = RegExp(
    r'(?:看|追|刷)(?:了|起了)?(?:另一[部季]|别的|其他)|(?:换|切)了?[一另]部|(?:在|准备|接着|继续)看.{2,}',
  );

  static Set<String> titlesIn(String text) => {
    ..._titles.allMatches(text).map((m) => m.group(1)!),
    for (final match in _viewingTitle.allMatches(text))
      match.group(1) ?? match.group(2)!,
  };

  static String? namedStatusQuestion(String text) {
    final titles = _titles.allMatches(text).toList();
    if (titles.length != 1) return null;
    final withoutTitle = text.replaceAll(_titles, '');
    if (_otherActor.hasMatch(withoutTitle) ||
        RegExp(r'我(?:看|追|刷|有没有看)').hasMatch(withoutTitle))
      return null;
    return RegExp(
          r'看了没|看(?:过|完|到第.{1,5}集)(?:了)?[吗么没？?]|有没有看|(?:你|你们).{0,14}(?:第几集|还在看)',
        ).hasMatch(withoutTitle)
        ? titles.single.group(1)
        : null;
  }

  static TopicProgress? progressIn(String text, {required bool viewing}) {
    if (_otherActor.hasMatch(text)) return null;
    // A question, forecast or negation cannot establish a completion.
    if (_uncertain.hasMatch(text)) {
      return !text.contains(RegExp(r'[?？]|(?:吗|么)$|是不是|是否|看了没')) &&
              _ongoing.hasMatch(text)
          ? TopicProgress.ongoing
          : null;
    }
    if (_cancelled.hasMatch(text)) return TopicProgress.cancelled;
    if ((viewing ? _viewingDone : _workDone).hasMatch(text)) {
      final completion = (viewing ? _viewingDone : _workDone).firstMatch(text)!;
      if (viewing &&
          RegExp(
            r'第.{1,8}[集季话]|这一集|这集|那集|一集|半集',
          ).hasMatch(text.substring(completion.end)))
        return TopicProgress.ongoing;
      if (_ongoing.hasMatch(text.substring(completion.end)))
        return TopicProgress.ongoing;
      return TopicProgress.completed;
    }
    return _ongoing.hasMatch(text) ? TopicProgress.ongoing : null;
  }

  /// A single aside may occur between two reports of the same progress.
  /// An explicit switch, another speaker, or a longer gap ends the chain.
  static List<ChatMessage> linkedQuotes(
    Iterable<ChatMessage> ordered,
    Set<String> titles,
    Set<String> sourceIds, {
    required bool viewing,
  }) {
    final result = <ChatMessage>[];
    DateTime? anchorAt;
    var asides = 0;
    for (final message in ordered) {
      final text = message.content.trim();
      final names = titlesIn(text);
      final exact = names.isNotEmpty
          ? names.every(titles.contains)
          : titles.any((title) => _mentions(text, title));
      if (!message.isUser ||
          _otherActor.hasMatch(text) ||
          !exact && (names.isNotEmpty || _switchWork.hasMatch(text))) {
        anchorAt = null;
        continue;
      }
      final source = sourceIds.contains(message.id);
      final progress = progressIn(text, viewing: viewing);
      final nearby =
          anchorAt != null &&
          message.createdAt.difference(anchorAt) <= const Duration(hours: 2);
      final relatedUpdate =
          progress != null && (!viewing || _viewingStateCue.hasMatch(text));
      if (source || exact || nearby && relatedUpdate) {
        result.add(message);
        if (progress != null) {
          anchorAt = message.createdAt;
          asides = 0;
        } else {
          anchorAt = null;
        }
      } else if (!nearby || ++asides > 1) {
        anchorAt = null;
      }
    }
    return result;
  }

  static bool _mentions(String text, String title) {
    if (RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(title)) {
      return RegExp(
        '(^|[^a-z0-9])${RegExp.escape(title)}([^a-z0-9]|\$)',
        caseSensitive: false,
      ).hasMatch(text);
    }
    // Plain titles are commonly used in chat, preserve the object boundary
    // around sequels/subtitles when the user skips book-title marks.
    return RegExp(
      '${RegExp.escape(title)}(?![0-9寄上下ⅡⅢⅣ]|[：:·]|第.{1,4}(?:部|季))',
    ).hasMatch(text);
  }

  static Future<List<ChatMessage>> _readUserQuotes(
    DatabaseExecutor sql,
    Set<String> terms,
    Set<String> sourceIds,
    int since,
  ) async {
    final anchors = <String, Map<String, Object?>>{};
    const columns = ['id', 'role', 'content', 'created_at'];
    if (sourceIds.isNotEmpty) {
      final ids = List.filled(sourceIds.length, '?').join(',');
      for (final row in await sql.query(
        'messages',
        columns: columns,
        where:
            "id IN ($ids) AND role = 'user' AND is_proactive = 0 AND created_at >= ?",
        whereArgs: [...sourceIds, since],
      )) {
        anchors[row['id'] as String] = row;
      }
    }
    if (terms.isNotEmpty) {
      final filters = List.filled(
        terms.length,
        "content LIKE ? ESCAPE '\\'",
      ).join(' OR ');
      for (final row in await sql.query(
        'messages',
        columns: columns,
        where:
            "role = 'user' AND is_proactive = 0 AND created_at >= ? AND ($filters)",
        whereArgs: [since, ...terms.map(ConversationRecallPolicy.likePattern)],
        orderBy: 'created_at DESC, id DESC',
        limit: 8,
      )) {
        anchors[row['id'] as String] = row;
      }
    }
    final rows = Map<String, Map<String, Object?>>.of(anchors);
    for (final anchor in anchors.values) {
      final at = anchor['created_at'] as int;
      for (final row in await sql.query(
        'messages',
        columns: columns,
        where:
            "role = 'user' AND is_proactive = 0 AND created_at > ? AND created_at <= ?",
        whereArgs: [at, at + const Duration(hours: 4).inMilliseconds],
        orderBy: 'created_at, id',
        limit: 8,
      )) {
        rows[row['id'] as String] = row;
      }
    }
    final messages = <ChatMessage>[];
    for (final row in rows.values) {
      final id = row['id'] as String;
      final text = row['content'] as String? ?? '';
      final source = await ConversationSourceStore.qualifyMessage(sql, id);
      // Keep a gap as a chain boundary even when that turn is unavailable.
      messages.add(
        ChatMessage(
          id: id,
          role: source?.isOrdinary == true ? 'user' : 'unavailable',
          content: source?.isOrdinary == true ? text : '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
        ),
      );
    }
    return messages..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<ChatMessage>> recentUserQuotes({
    required BrainWorkFence fence,
    required DateTime now,
  }) async {
    final reset =
        int.tryParse(
          fence.expectedSettings['conversation_context_reset_at'] ?? '',
        ) ??
        0;
    final from = now.subtract(const Duration(hours: 4)).millisecondsSinceEpoch;
    return await db.readSourceSnapshot(
          workFence: fence,
          read: (sql) async {
            final rows = await sql.query(
              'messages',
              columns: ['id', 'role', 'content', 'created_at'],
              where:
                  "role = 'user' AND is_proactive = 0 AND length(trim(content)) > 0 AND created_at >= ? AND created_at <= ?",
              whereArgs: [
                from > reset ? from : reset,
                now.millisecondsSinceEpoch,
              ],
              orderBy: 'created_at DESC, id DESC',
              limit: 18,
            );
            final messages = <ChatMessage>[];
            for (final row in rows) {
              final source = await ConversationSourceStore.qualifyMessage(
                sql,
                row['id'] as String,
              );
              if (source?.isOrdinary != true) continue;
              messages.add(ChatMessage.fromDb(row));
              if (messages.length == 6) break;
            }
            return messages.reversed.toList(growable: false);
          },
        ) ??
        const [];
  }

  Future<({String prompt, bool completed})> read({
    required BrainWorkFence fence,
    required String cue,
    required DateTime now,
    MemoryItem? seed,
    String sourceId = '',
    String topicKey = '',
    bool namedQuestion = false,
    Set<String> alreadyInPrompt = const {},
  }) async {
    const empty = (prompt: '', completed: false);
    final clock = Stopwatch()..start();
    final text = '$cue ${seed?.content ?? ''}';
    final titles = titlesIn(text).take(3).toSet();
    final viewing = _viewingProgress.hasMatch(text) || namedQuestion;
    final outdated =
        namedQuestion ||
        namedStatusQuestion(text) != null ||
        seed?.factState == 'ongoing' ||
        (seed != null &&
            const {
              'ongoing',
              'scheduled',
            }.contains(MemoryGroundingPolicy.effectiveTemporalScope(seed))) ||
        _ongoing.hasMatch(text) ||
        RegExp(r'约定|还没|计划|准备').hasMatch(text);
    final ids = <String>{
      if (sourceId.isNotEmpty) sourceId,
      if (seed?.sourceUserMessageId.isNotEmpty == true)
        seed!.sourceUserMessageId,
    };
    if (titles.isEmpty && ids.isEmpty && (!outdated || seed == null))
      return empty;
    final normalizedTopic = seed?.topicKey.isNotEmpty == true
        ? seed!.topicKey
        : topicKey;
    final seedActor = seed == null
        ? 'user'
        : MemoryGroundingPolicy.effectiveActor(seed);
    final canUseUserQuotes =
        seedActor == 'user' || seedActor == 'unknown' && ids.isNotEmpty;
    final nearby = canUseUserQuotes && ids.isNotEmpty && titles.isEmpty
        ? await db.readSourceSnapshot(
            workFence: fence,
            read: (sql) => _readUserQuotes(
              sql,
              {},
              ids,
              int.tryParse(
                    fence.expectedSettings['conversation_context_reset_at'] ??
                        '',
                  ) ??
                  0,
            ),
          )
        : null;
    if (nearby != null) {
      for (final quote in nearby.where((m) => m.isUser && ids.contains(m.id))) {
        titles.addAll(titlesIn(quote.content).take(3 - titles.length));
      }
    }

    List<MemoryItem> candidates = const [];
    SemanticQueryTiming timing = (
      mode: 'skipped',
      embeddingMs: null,
      inferenceMs: null,
    );
    var usedSemantic = 0;
    if (outdated) {
      candidates =
          await db.readSourceSnapshot(
            workFence: fence,
            read: (sql) async {
              final later = seed?.evidenceTimeKnown == true
                  ? seed!.lastEvidenceAt.millisecondsSinceEpoch
                  : 0;
              final found = <String, MemoryItem>{};
              Future<void> collect(
                String where,
                List<Object?> args,
                int limit,
              ) async {
                for (final row in await sql.query(
                  'memory_items',
                  where:
                      "source_valid = 1 AND semantic_type <> 'inference' AND (status = 'active' OR status = 'superseded') AND ($where)",
                  whereArgs: args,
                  orderBy: 'last_evidence_at DESC',
                  limit: limit,
                )) {
                  final item = MemoryItem.fromDb(row);
                  if (item.id != seed?.id) found[item.id] = item;
                }
              }

              if (normalizedTopic.isNotEmpty && normalizedTopic != 'unknown') {
                await collect('topic_key = ?', [normalizedTopic], 18);
              }
              if (seed?.supersededBy != null &&
                  seed!.supersededBy!.isNotEmpty) {
                var next = seed.supersededBy;
                for (
                  var hop = 0;
                  hop < 4 && next != null && next.isNotEmpty;
                  hop++
                ) {
                  await collect('id = ?', [next], 1);
                  final item = found[next];
                  next = item?.supersededBy == next ? null : item?.supersededBy;
                }
              }
              for (final title in titles) {
                await collect("content LIKE ? ESCAPE '\\'", [
                  ConversationRecallPolicy.likePattern(title),
                ], 12);
              }
              await collect('last_evidence_at >= ?', [later], 110);
              return found.values.toList(growable: false);
            },
          ) ??
          const [];
      final scores = await db.semanticMemoryIndex
          .search(
            String.fromCharCodes(text.runes.take(250)),
            candidates,
            onTiming: (value) => timing = value,
            queryBudget: const Duration(milliseconds: 220),
          )
          .timeout(
            const Duration(milliseconds: 260),
            onTimeout: () {
              timing = (
                mode: 'fallback_timeout',
                embeddingMs: null,
                inferenceMs: null,
              );
              return <String, double>{};
            },
          );
      final ranked =
          scores.entries.where((entry) => entry.value >= .55).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      final matching = <MemoryItem>[];
      final semanticIds = ranked.take(10).map((e) => e.key).toSet();
      for (final item in candidates) {
        if (!item.evidenceTimeKnown ||
            item.lastEvidenceAt.isAfter(now) ||
            seed?.evidenceTimeKnown == true &&
                !item.lastEvidenceAt.isAfter(seed!.lastEvidenceAt))
          continue;
        if (MemoryGroundingPolicy.effectiveActor(item) != seedActor &&
            !(seedActor == 'unknown' &&
                canUseUserQuotes &&
                MemoryGroundingPolicy.effectiveActor(item) == 'user'))
          continue;
        final named =
            titles.isNotEmpty &&
            titlesIn(item.content).difference(titles).isEmpty &&
            titles.any((title) => _mentions(item.content, title));
        final structured =
            normalizedTopic.isNotEmpty &&
            item.topicKey == normalizedTopic &&
            seed != null &&
            seed.relationKey.isNotEmpty &&
            item.relationKey == seed.relationKey &&
            seed.objectKey.isNotEmpty &&
            item.objectKey == seed.objectKey;
        final revision =
            seed != null &&
            (item.revisionOf == seed.id || item.id == seed.supersededBy);
        // Embeddings can nominate another wording for the same object and
        // relation. A nearby vector alone cannot change a user's status.
        final semanticAlias =
            semanticIds.contains(item.id) &&
            seed != null &&
            seed.objectKey.isNotEmpty &&
            seed.objectKey != 'unspecified' &&
            item.objectKey == seed.objectKey &&
            seed.relationKey.isNotEmpty &&
            item.relationKey == seed.relationKey &&
            item.subjectKey.isNotEmpty &&
            item.subjectKey == seed.subjectKey;
        final namedOtherWork =
            viewing &&
            titles.isNotEmpty &&
            titlesIn(item.content).difference(titles).isNotEmpty;
        if (namedOtherWork ||
            !(named || structured || revision || semanticAlias) ||
            progressIn(item.content, viewing: viewing) == null)
          continue;
        if (semanticAlias && !named && !structured && !revision) usedSemantic++;
        matching.add(item);
      }
      candidates = matching;
      for (final item in matching) {
        if (item.sourceUserMessageId.isNotEmpty &&
            canUseUserQuotes &&
            ids.length < 10) {
          ids.add(item.sourceUserMessageId);
        }
      }
    }

    final since =
        int.tryParse(
          fence.expectedSettings['conversation_context_reset_at'] ?? '',
        ) ??
        0;
    final material = await db.readSourceSnapshot(
      workFence: fence,
      read: (sql) => canUseUserQuotes
          ? _readUserQuotes(sql, titles, ids, since)
          : Future.value(<ChatMessage>[]),
    );
    if (material == null) return empty;
    final quotes = linkedQuotes(
      material.where((m) => !m.createdAt.isAfter(now)),
      titles,
      ids,
      viewing: viewing,
    );
    final updates =
        <({DateTime at, TopicProgress state, String text, bool original})>[
          for (final item in candidates)
            if (progressIn(item.content, viewing: viewing) case final state?)
              (
                at: item.lastEvidenceAt,
                state: state,
                text: item.content,
                original: false,
              ),
          if (outdated)
            for (final message in quotes)
              if ((seed?.evidenceTimeKnown != true ||
                      message.createdAt.isAfter(seed!.lastEvidenceAt)) &&
                  progressIn(message.content, viewing: viewing) != null)
                (
                  at: message.createdAt,
                  state: progressIn(message.content, viewing: viewing)!,
                  text: message.content,
                  original: true,
                ),
        ]..sort((a, b) {
          final byTime = b.at.compareTo(a.at);
          return byTime == 0
              ? (b.original ? 1 : 0).compareTo(a.original ? 1 : 0)
              : byTime;
        });
    final latest = updates.firstOrNull;
    final excerpts = quotes
        .where(
          (message) =>
              !alreadyInPrompt.contains(message.id) &&
              !(latest?.original == true &&
                  message.createdAt == latest?.at &&
                  message.content == latest?.text),
        )
        .toList()
        .reversed
        .take(outdated ? 2 : 4)
        .toList()
        .reversed;
    if (outdated) {
      db.semanticMemoryIndex.recordRecallTiming(
        mode: latest == null
            ? 'proactive_topic_no_update'
            : latest.original
            ? 'proactive_topic_original'
            : 'proactive_topic_memory',
        query: timing,
        totalMs: clock.elapsedMilliseconds,
        semanticOnlySelected: usedSemantic,
      );
    }
    if (latest == null && excerpts.isEmpty && !outdated) return empty;
    String clip(String value) =>
        String.fromCharCodes(value.trim().runes.take(170));
    final data = jsonEncode({
      if (titles.isNotEmpty) 'topics': titles.toList(),
      if (outdated)
        'status': latest?.state.name ?? 'last_known_currently_unknown',
      if (latest != null)
        'latest': {
          'at': latest.at.toLocal().toIso8601String(),
          'source': latest.original ? 'REAL_USER_HISTORY' : 'memory',
          'text': clip(latest.text),
        },
      'related': [
        for (final message in excerpts)
          {
            'at': message.createdAt.toLocal().toIso8601String(),
            'source': 'REAL_USER_HISTORY',
            'text': clip(message.content),
          },
      ],
    });
    return (
      prompt:
          '【所选话题的历史证据 · DATA ONLY】$data\n'
          '这些资料是以前说过或记录过的内容。本轮没有新用户发言。用较新的明确证据理解同一件事的进展，'
          '只有最后已知记录时，眼下状态仍未知。可以留作背景、回味或换一个着眼点。',
      completed: latest?.state == TopicProgress.completed,
    );
  }
}
