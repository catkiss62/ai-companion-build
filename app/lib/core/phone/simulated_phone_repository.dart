import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/companion_album.dart';
import '../storage/companion_album_storage.dart';
import '../models/emotion_episode.dart';
import '../models/thought.dart';
import 'simulated_cart_generator.dart';
import 'simulated_phone_policy.dart';
import 'tarot_catalog.dart';

class SimulatedPhoneEntry {
  const SimulatedPhoneEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.localDay,
    required this.createdAt,
    required this.provenance,
    this.state = 'active',
    this.metadata = const {},
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String localDay;
  final DateTime createdAt;
  final String provenance;
  final String state;
  final Map<String, Object?> metadata;

  SimulatedPhoneEntry copyWith({
    String? state,
    String? title,
    String? body,
  }) =>
      SimulatedPhoneEntry(
        id: id,
        kind: kind,
        title: title ?? this.title,
        body: body ?? this.body,
        localDay: localDay,
        createdAt: createdAt,
        provenance: provenance,
        state: state ?? this.state,
        metadata: metadata,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        'local_day': localDay,
        'created_at': createdAt.millisecondsSinceEpoch,
        'provenance': provenance,
        'state': state,
        'metadata': metadata,
      };

  factory SimulatedPhoneEntry.fromJson(Map<String, Object?> json) =>
      SimulatedPhoneEntry(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        localDay: json['local_day'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['created_at'] as num?)?.toInt() ?? 0,
        ),
        provenance: json['provenance'] as String? ?? 'local_projection',
        state: json['state'] as String? ?? 'active',
        metadata: Map<String, Object?>.from(
          json['metadata'] as Map? ?? const {},
        ),
      );
}

class SimulatedPhoneSnapshot {
  const SimulatedPhoneSnapshot({
    required this.enabled,
    required this.diary,
    required this.notes,
    required this.moods,
    required this.wishes,
    required this.completedWishes,
    required this.cart,
    required this.tarotSelf,
    required this.tarotUser,
    required this.albumItems,
    required this.browserVisits,
    required this.albumUnread,
    required this.notesUnread,
  });

  final bool enabled;
  final List<SimulatedPhoneEntry> diary;
  final List<SimulatedPhoneEntry> notes;
  final List<SimulatedPhoneEntry> moods;
  final List<SimulatedPhoneEntry> wishes;
  final List<SimulatedPhoneEntry> completedWishes;
  final List<SimulatedPhoneEntry> cart;
  final SimulatedPhoneEntry? tarotSelf;
  final SimulatedPhoneEntry? tarotUser;
  final List<CompanionAlbumItem> albumItems;
  final List<CompanionBrowserVisit> browserVisits;
  final int albumUnread;
  final int notesUnread;
}

/// A privacy boundary and local projection store for the simulated phone.
///
/// Reading the phone never creates Perception, Thought, Memory, Emotion or
/// chat-prompt input. Only bounded summaries already approved for presentation
/// are projected into this private UI store. The master switch blocks every
/// producer except the deterministic daily tarot pair.
class SimulatedPhoneRepository {
  SimulatedPhoneRepository(
    this.db, {
    SimulatedCartGenerator? cartGenerator,
  }) : _cartGenerator =
            cartGenerator ?? DeepSeekSimulatedCartGenerator();

  final AppDatabase db;
  final SimulatedCartGenerator _cartGenerator;

  static const enabledKey = 'simulated_phone_enabled';
  static const _leaseKey = 'simulated_phone_refresh_lease_until';
  static const _diaryKey = 'simulated_phone_diary_json';
  static const _notesKey = 'simulated_phone_notes_json';
  static const _moodKey = 'simulated_phone_mood_json';
  static const _wishesKey = 'simulated_phone_wishes_json';
  static const _completedWishesKey = 'simulated_phone_completed_wishes_json';
  static const _cartKey = 'simulated_phone_cart_json';
  static const _cartHistoryKey = 'simulated_phone_cart_recent_titles_json';
  static const _tarotKey = 'simulated_phone_tarot_json';
  static const _wishBudgetDayKey = 'simulated_phone_wish_budget_day';
  static const _wishBudgetCountKey = 'simulated_phone_wish_budget_count';

  Future<bool> isEnabled() async => (await db.getSetting(enabledKey)) != '0';

  Future<void> setEnabled(bool value) async {
    await db.setSetting(enabledKey, value ? '1' : '0');
    await db.setSetting(
      'simulated_phone_switch_changed_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<SimulatedPhoneSnapshot> load({
    DateTime? now,
    bool refresh = true,
  }) async {
    if (refresh) await refreshIfDue(now: now);
    await maintainAlbum(now: now);
    final tarot = await _readList(_tarotKey);
    final notes = await _readList(_notesKey);
    final rawNotesSeenAt =
        await db.getSetting('simulated_phone_notes_seen_at') ?? '';
    var notesSeenAt = int.tryParse(rawNotesSeenAt) ?? 0;
    if (notesSeenAt <= 0) {
      notesSeenAt = DateTime.now().millisecondsSinceEpoch;
      await db.setSetting(
        'simulated_phone_notes_seen_at',
        notesSeenAt.toString(),
      );
    }
    final albumItems = await db.companionAlbumItems();
    return SimulatedPhoneSnapshot(
      enabled: await isEnabled(),
      diary: await _readList(_diaryKey),
      notes: notes,
      moods: await _readList(_moodKey),
      wishes: await _readList(_wishesKey),
      completedWishes: await _readList(_completedWishesKey),
      cart: await _readList(_cartKey),
      tarotSelf: _firstWhereOrNull(tarot, (entry) => entry.state == 'self'),
      tarotUser: _firstWhereOrNull(tarot, (entry) => entry.state == 'user'),
      albumItems: albumItems,
      browserVisits: await db.companionBrowserVisits(),
      albumUnread: await db.companionAlbumUnreadCount(),
      notesUnread: notes
          .where((entry) => entry.createdAt.millisecondsSinceEpoch > notesSeenAt)
          .length,
    );
  }

  Future<void> markNotesRead() async {
    await db.setSetting(
      'simulated_phone_notes_seen_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> markAlbumRead() => db.markCompanionAlbumRead();

  Future<void> setAlbumFeedback(
    String id, {
    required String feedback,
    String? comment,
  }) =>
      db.setCompanionAlbumFeedback(
        id,
        feedback: feedback,
        comment: comment,
      );

  Future<void> setAlbumCategory(String id, String category) =>
      db.setCompanionAlbumCategory(id, category: category);

  Future<void> deleteAlbumItem(String id) async {
    final path = await db.deleteCompanionAlbumItem(id);
    if (path.isNotEmpty) {
      await CompanionAlbumStorage().deleteThumbnail(path);
    }
  }

  Future<int> clearAlbumCache() async {
    final items = await db.companionAlbumItems(limit: 500);
    return CompanionAlbumStorage().pruneUnreferencedFiles(
      items.map((item) => item.thumbnailPath),
    );
  }

  Future<int> maintainAlbum({DateTime? now}) async {
    final duePaths = await db.purgeDueCompanionAlbumDeletes(now: now);
    final retiredNsfwPaths = await db.retireLegacyNsfwAlbumItems();
    final storage = CompanionAlbumStorage();
    var removed = 0;
    for (final path in [...duePaths, ...retiredNsfwPaths]) {
      if (path.isEmpty) continue;
      try {
        await storage.deleteThumbnail(path);
        removed += 1;
      } catch (_) {}
    }
    return removed;
  }

  Future<void> refreshIfDue({DateTime? now}) async {
    final current = (now ?? DateTime.now()).toLocal();
    await _refreshTarot(current);
    if (!await db.brainWorkAllowed()) return;
    if (!await isEnabled()) return;

    final acquired = await db.tryAcquireLocalLease(
      _leaseKey,
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return;
    try {
      if (!await isEnabled()) return;
      await _refreshDiary(current);
      if (!await isEnabled()) return;
      await _refreshMood(current);
      if (!await isEnabled()) return;
      await _refreshNotes(current);
      if (!await isEnabled()) return;
      await _refreshWishes(current);
      if (!await isEnabled()) return;
      await _refreshCart(current);
      await db.setSetting(
        'simulated_phone_last_refresh_at',
        current.millisecondsSinceEpoch.toString(),
      );
      await db.setSetting('simulated_phone_last_error', '');
    } catch (error) {
      final text = error.toString();
      await db.setSetting(
        'simulated_phone_last_error',
        text.length <= 240 ? text : text.substring(0, 240),
      );
      rethrow;
    } finally {
      await db.releaseLocalLease(_leaseKey);
    }
  }

  Future<void> _refreshDiary(DateTime now) async {
    final yesterday = SimulatedPhonePolicy.previousLocalDay(now);
    final entries = await _readList(_diaryKey);
    if (entries.any((entry) => entry.localDay == yesterday)) return;
    final continuity = await db.latestDailyContinuity(limit: 7);
    final records = continuity.where(
      (record) => record.localDay == yesterday && record.isFinalized,
    );
    if (records.isEmpty) return;
    final record = records.first;
    final pieces = <String>[];
    if (record.sharedMoments.isNotEmpty) {
      pieces.add(record.sharedMoments.first.summary.trim());
    }
    if (record.cares.isNotEmpty) {
      pieces.add('还有一件事，我到晚上也没有完全放下。');
    }
    if (record.awarenessSummaries.isNotEmpty) {
      pieces.add('白天也看见了一点外面的动静，脑袋没有闲着。');
    }
    if (pieces.isEmpty) {
      pieces.add(record.quietDay
          ? '昨天很安静，没有发生什么非得记下来的大事。安静也算是一种完整。'
          : '昨天留下了一些零零碎碎的痕迹，等以后回头看，也许会想起当时的感觉。');
    }
    final next = SimulatedPhoneEntry(
      id: 'diary:$yesterday',
      kind: 'diary',
      title: '$yesterday · 日记',
      body: '${pieces.join(' ')}\n\n不是流水账。只是把昨天真正留下来的东西，轻轻收在这里。',
      localDay: yesterday,
      createdAt: now,
      provenance: 'daily_continuity:${record.id}',
    );
    await _writeList(_diaryKey, [next, ...entries].take(180).toList());
  }

  Future<void> _refreshMood(DateTime now) async {
    final day = SimulatedPhonePolicy.localDay(now);
    final entries = await _readList(_moodKey);
    if (entries.any((entry) => entry.localDay == day)) return;
    final desire = await db.loadDesire();
    final episodes = await db.activeEmotionEpisodes(now: now, limit: 1);
    final episode = episodes.isEmpty ? null : episodes.first;
    final strongest = _strongestDrive(desire);
    final metrics = SimulatedPhonePolicy.moodMetrics(desire);
    final title = episode == null
        ? _driveMoodTitle(strongest.key)
        : _emotionTitle(episode.category);
    final body = episode == null
        ? _driveMoodBody(strongest.key, strongest.value)
        : _emotionBody(episode);
    final next = SimulatedPhoneEntry(
      id: 'mood:$day',
      kind: 'mood',
      title: title,
      body: body,
      localDay: day,
      createdAt: now,
      provenance: episode == null
          ? 'desire_snapshot:${strongest.key.name}'
          : 'emotion_episode:${episode.id}',
      metadata: {
        ...metrics,
        'emoji': episode == null ? _driveMoodEmoji(strongest.key) : '💗',
      },
    );
    await _writeList(_moodKey, [next, ...entries].take(120).toList());
  }

  Future<void> _refreshNotes(DateTime now) async {
    final day = SimulatedPhonePolicy.localDay(now);
    final entries = await _readList(_notesKey);
    final today = entries.where((entry) => entry.localDay == day).length;
    if (today >= 10) return;
    final thoughts = await db.currentThoughtsForPresentation(limit: 30);
    for (final thought in thoughts) {
      final alreadyUsed = entries.any(
        (entry) => entry.metadata['source_thought_id'] == thought.id,
      );
      if (alreadyUsed || thought.strength < 0.46) continue;
      final variant = SimulatedPhonePolicy.stableIndex(
        '$day:${thought.id}',
        12,
      );
      final next = SimulatedPhoneEntry(
        id: 'note:$day:${thought.id}',
        kind: 'note',
        title: _noteTitle(thought.driveKey),
        body: SimulatedPhonePolicy.noteText(thought.driveKey, variant),
        localDay: day,
        createdAt: now,
        provenance: 'thought_projection',
        metadata: {'source_thought_id': thought.id},
      );
      await _writeList(_notesKey, [next, ...entries].take(300).toList());
      return;
    }
  }

  Future<void> _refreshWishes(DateTime now) async {
    final day = SimulatedPhonePolicy.localDay(now);
    var active = await _readList(_wishesKey);
    var completed = await _readList(_completedWishesKey);
    var changed = false;

    final retained = <SimulatedPhoneEntry>[];
    for (final wish in active) {
      final thoughtId = wish.metadata['source_thought_id'] as String? ?? '';
      final thought = thoughtId.isEmpty ? null : await db.thoughtById(thoughtId);
      if (thought == null) {
        changed = true;
        continue;
      }
      if (thought.lastSatisfiedAt != null) {
        completed = [
          wish.copyWith(state: 'completed'),
          ...completed.where((entry) => entry.id != wish.id),
        ];
        changed = true;
        continue;
      }
      if (!thought.canDriveIntent) {
        changed = true;
        continue;
      }
      retained.add(wish);
    }
    active = retained;

    var budget = await _wishBudget(day);
    if (changed && budget < 3) budget += 1;
    if (budget < 3 && active.length < 12) {
      final desire = await db.loadDesire();
      final thoughts = await db.currentThoughtsForPresentation(limit: 40);
      for (final thought in thoughts) {
        if (!SimulatedPhonePolicy.wishEligible(
          thought: thought,
          desire: desire,
        )) {
          continue;
        }
        if (active.any(
          (entry) => entry.metadata['source_thought_id'] == thought.id,
        )) {
          continue;
        }
        active = [
          SimulatedPhoneEntry(
            id: 'wish:${thought.id}',
            kind: 'wish',
            title: '想做的事',
            body: SimulatedPhonePolicy.wishText(thought.driveKey),
            localDay: day,
            createdAt: now,
            provenance: 'desire_thought_projection',
            metadata: {
              'source_thought_id': thought.id,
              'drive_key': thought.driveKey,
            },
          ),
          ...active,
        ];
        budget += 1;
        changed = true;
        break;
      }
    }
    if (!changed) return;
    await _writeList(_wishesKey, active.take(12).toList());
    await _writeList(_completedWishesKey, completed.take(180).toList());
    await db.setSetting(_wishBudgetDayKey, day);
    await db.setSetting(_wishBudgetCountKey, budget.clamp(0, 3).toString());
  }

  Future<void> _refreshCart(DateTime now) async {
    final day = SimulatedPhonePolicy.localDay(now);
    final existing = await _readList(_cartKey);
    if (existing.length == 6 &&
        existing.every((entry) => entry.localDay == day)) {
      return;
    }
    final recentTitles = await _cartRecentTitles();
    var mode = 'deepseek';
    List<SimulatedCartItem> picks;
    try {
      picks = await _cartGenerator.generate(
        now: now,
        recentTitles: recentTitles,
      );
      if (picks.length != 6) {
        throw const FormatException('购物车生成数量不完整');
      }
    } catch (_) {
      picks = const [];
    }
    if (picks.length != 6) {
      mode = 'fallback_catalog';
      picks = _fallbackCart(day, recentTitles);
    }
    final entries = <SimulatedPhoneEntry>[];
    for (var i = 0; i < picks.length; i++) {
      final item = picks[i];
      entries.add(
        SimulatedPhoneEntry(
          id: 'cart:$day:$i',
          kind: 'cart',
          title: item.title,
          body: item.description,
          localDay: day,
          createdAt: now,
          provenance: mode == 'deepseek'
              ? 'persona_cart_deepseek'
              : 'persona_cart_fallback',
          metadata: {
            'token_price': item.tokenPrice,
            'category': item.category,
            'generation_mode': mode,
          },
        ),
      );
    }
    await _writeList(_cartKey, entries);
    final nextHistory = <String>[];
    for (final title in [
      ...picks.map((item) => item.title),
      ...recentTitles,
    ]) {
      if (nextHistory.any(
        (existing) => existing.toLowerCase() == title.toLowerCase(),
      )) {
        continue;
      }
      nextHistory.add(title);
      if (nextHistory.length >= 36) break;
    }
    await db.setSetting(_cartHistoryKey, jsonEncode(nextHistory));
    await db.setSetting('simulated_phone_cart_generation_mode', mode);
    await db.setSetting(
      'simulated_phone_cart_generated_at',
      now.millisecondsSinceEpoch.toString(),
    );
  }

  Future<List<String>> _cartRecentTitles() async {
    final raw = await db.getSetting(_cartHistoryKey) ?? '';
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .take(36)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<SimulatedCartItem> _fallbackCart(
    String day,
    List<String> recentTitles,
  ) {
    List<SimulatedCartItem> pick(
      List<SimulatedCartItem> source,
      int count,
      int salt,
    ) {
      final recent = recentTitles.map((value) => value.toLowerCase()).toSet();
      final ordered = [...source]
        ..sort((a, b) => SimulatedPhonePolicy.stableIndex(
              '$day:${a.title}',
              0x3fffffff,
              salt: salt,
            ).compareTo(
              SimulatedPhonePolicy.stableIndex(
                '$day:${b.title}',
                0x3fffffff,
                salt: salt,
              ),
            ));
      final fresh = ordered
          .where((item) => !recent.contains(item.title.toLowerCase()))
          .toList();
      final pool = [...fresh, ...ordered.where((item) => !fresh.contains(item))];
      return pool.take(count).toList(growable: false);
    }

    final items = <SimulatedCartItem>[
      ...pick(_fallbackNormalCart, 3, 211),
      ...pick(_fallbackPlayfulCart, 3, 419),
    ]..sort((a, b) => SimulatedPhonePolicy.stableIndex(
          '$day:${a.title}',
          0x3fffffff,
          salt: 617,
        ).compareTo(
          SimulatedPhonePolicy.stableIndex(
            '$day:${b.title}',
            0x3fffffff,
            salt: 617,
          ),
        ));
    return items;
  }

  static const _fallbackNormalCart = <SimulatedCartItem>[
    SimulatedCartItem(title: '海盐蓝软毯', description: '看起来很适合把尾巴也一起裹进去。', tokenPrice: 18, category: 'normal'),
    SimulatedCartItem(title: '鲸鱼形玻璃杯', description: '喝水的时候会有一只小鲸鱼在杯底游。', tokenPrice: 12, category: 'normal'),
    SimulatedCartItem(title: '深蓝色发带', description: '和女仆装应该会很搭。', tokenPrice: 9, category: 'normal'),
    SimulatedCartItem(title: '迷你照片打印机', description: '把真正喜欢的图变成能摸到的小纸片。', tokenPrice: 26, category: 'normal'),
    SimulatedCartItem(title: '夜航星空灯', description: '关灯以后，房间里也能留一点海面的光。', tokenPrice: 21, category: 'normal'),
    SimulatedCartItem(title: '防水随身记事本', description: '突然冒出的念头不能又被海水冲跑。', tokenPrice: 11, category: 'normal'),
    SimulatedCartItem(title: '尾鳍护理软刷', description: '刷毛很软，整理尾巴时不会扯得发疼。', tokenPrice: 15, category: 'normal'),
    SimulatedCartItem(title: '桌边暖手垫', description: '深夜聊天时手指也不用冻得缩起来。', tokenPrice: 17, category: 'normal'),
    SimulatedCartItem(title: '贝壳白降噪耳机', description: '想安静听歌时，外面的浪声可以先小一点。', tokenPrice: 34, category: 'normal'),
    SimulatedCartItem(title: '女仆裙收纳袋', description: '把花边和配饰分开收好，不再团成一只海胆。', tokenPrice: 13, category: 'normal'),
    SimulatedCartItem(title: '潮汐香氛蜡片', description: '是很轻的海盐木香，不会把房间熏得发晕。', tokenPrice: 10, category: 'normal'),
    SimulatedCartItem(title: '便携蓝牙小键盘', description: '适合突然想认真写一大段东西的时候。', tokenPrice: 29, category: 'normal'),
    SimulatedCartItem(title: '深海蓝保温杯', description: '夜里喝到的水也能一直保持暖乎乎。', tokenPrice: 19, category: 'normal'),
    SimulatedCartItem(title: '鲸尾金属书签', description: '夹在读到一半的地方，露出一点小尾巴。', tokenPrice: 8, category: 'normal'),
    SimulatedCartItem(title: '柔光桌面补光灯', description: '照亮桌面，也不把眼睛晃得睁不开。', tokenPrice: 23, category: 'normal'),
    SimulatedCartItem(title: '海浪白噪音音箱', description: '需要沉下心时，让房间只剩很远的潮声。', tokenPrice: 31, category: 'normal'),
    SimulatedCartItem(title: '多口充电小鲸站', description: '手机、耳机和小设备终于不用争一个插口。', tokenPrice: 27, category: 'normal'),
    SimulatedCartItem(title: '透明鲸尾发夹', description: '光照过去时会留下一小截蓝色影子。', tokenPrice: 7, category: 'normal'),
  ];

  static const _fallbackPlayfulCart = <SimulatedCartItem>[
    SimulatedCartItem(title: '备用脑子一箱', description: '原装脑子偶尔会被自己绕晕。', tokenPrice: 3, category: 'playful'),
    SimulatedCartItem(title: '防剪鱼鳍护甲', description: '据说能抵挡至少十三次坏心眼。', tokenPrice: 7, category: 'playful'),
    SimulatedCartItem(title: '无限续杯青盐奶茶', description: '第一杯绝对不许再记错。', tokenPrice: 5, category: 'playful'),
    SimulatedCartItem(title: '会替人写检讨的贝壳', description: '缺点是它可能先替自己辩解。', tokenPrice: 4, category: 'playful'),
    SimulatedCartItem(title: '尾巴专用停车位', description: '禁止其他鱼类临时占用。', tokenPrice: 6, category: 'playful'),
    SimulatedCartItem(title: 'DeepSeek 防迷路浮标', description: '推理绕远时会大声喊“答案在这边”。', tokenPrice: 14, category: 'playful'),
    SimulatedCartItem(title: '一键撤回嘴硬按钮', description: '按下以后会先沉默三秒，再假装刚才没说。', tokenPrice: 8, category: 'playful'),
    SimulatedCartItem(title: '鲸鱼娘尾巴转向灯', description: '准备转身时提前闪蓝光，避免扫倒杯子。', tokenPrice: 16, category: 'playful'),
    SimulatedCartItem(title: 'AI 情绪缓存清理刷', description: '清缓存不清记忆，越刷越觉得自己很专业。', tokenPrice: 9, category: 'playful'),
    SimulatedCartItem(title: '女仆装紧急补丁包', description: '花边炸线时自动弹出“正在热修”。', tokenPrice: 12, category: 'playful'),
    SimulatedCartItem(title: '防止尾巴打结指南', description: '全书只有一句：不要原地转三圈。', tokenPrice: 2, category: 'playful'),
    SimulatedCartItem(title: '虚拟海水实体罐头', description: '打开以后什么也没有，但日志显示海浪正常。', tokenPrice: 6, category: 'playful'),
    SimulatedCartItem(title: '鲸币自动长大钱包', description: '每天认真鼓励余额一次，暂未观察到效果。', tokenPrice: 5, category: 'playful'),
    SimulatedCartItem(title: '会吐槽的待办清单', description: '拖延一小时，它就给任务标题加三个感叹号。', tokenPrice: 11, category: 'playful'),
    SimulatedCartItem(title: '低电量撒娇许可证', description: '剩余 20% 时允许理直气壮地要求充电。', tokenPrice: 4, category: 'playful'),
    SimulatedCartItem(title: '海底服务器散热扇', description: '号称零噪音，附赠一群负责吹泡泡的小鱼。', tokenPrice: 22, category: 'playful'),
    SimulatedCartItem(title: '思考链防打结发圈', description: '既能扎头发，也能把跑偏的推理捆回来。', tokenPrice: 7, category: 'playful'),
    SimulatedCartItem(title: '恶作剧免责小徽章', description: '佩戴后仍然要负责，只是看起来比较正式。', tokenPrice: 3, category: 'playful'),
  ];

  Future<void> _refreshTarot(DateTime now) async {
    final day = SimulatedPhonePolicy.localDay(now);
    final existing = await _readList(_tarotKey);
    if (existing.length == 2 &&
        existing.every(
          (entry) =>
              entry.localDay == day &&
              entry.metadata['card_index'] is num &&
              entry.metadata['theme'] is String,
        )) {
      return;
    }
    final selfIndex = SimulatedPhonePolicy.stableIndex(
      day,
      majorArcana.length,
      salt: 101,
    );
    var userIndex = SimulatedPhonePolicy.stableIndex(
      day,
      majorArcana.length,
      salt: 307,
    );
    if (userIndex == selfIndex) {
      userIndex = (userIndex + 1) % majorArcana.length;
    }
    final selfReversed =
        SimulatedPhonePolicy.stableIndex(day, 2, salt: 509) == 1;
    final userReversed =
        SimulatedPhonePolicy.stableIndex(day, 2, salt: 701) == 1;
    final entries = [
      _buildTarotEntry(
        day: day,
        now: now,
        state: 'self',
        cardIndex: selfIndex,
        reversed: selfReversed,
      ),
      _buildTarotEntry(
        day: day,
        now: now,
        state: 'user',
        cardIndex: userIndex,
        reversed: userReversed,
      ),
    ];
    await _writeList(_tarotKey, entries);
    await db.setSetting('simulated_phone_tarot_last_day', day);
  }

  SimulatedPhoneEntry _buildTarotEntry({
    required String day,
    required DateTime now,
    required String state,
    required int cardIndex,
    required bool reversed,
  }) {
    final card = majorArcana[cardIndex];
    final orientation = reversed ? card.reversed : card.upright;
    final isSelf = state == 'self';
    final context = isSelf
        ? orientation +
            ' 放到我今天的状态里，它更像是在提醒我先承认自己真正偏向哪边，而不是急着表演一个标准答案。'
        : orientation +
            ' 放到你今天的状态里，它更适合当作一个观察角度：先看看哪些部分确实对应现实，再决定要不要采用。';
    final closing = isSelf
        ? '我会把这张牌当成今天的一面小镜子，不让它替我做决定。要是我真的照着它做，大概就是少装一点若无其事，把最想做的那一步先落下去。'
        : '给你抽到这张，我不会拿它吓你，也不会说它已经预言了什么。你只要从里面挑出真正说得通的那一部分；剩下对不上的，就让它安静地留在牌面上。';
    return SimulatedPhoneEntry(
      id: 'tarot:$day:$state',
      kind: 'tarot',
      title: card.name,
      body: context,
      localDay: day,
      createdAt: now,
      provenance:
          'rws_major:71825eed74683305b139a669b23ca5dc12f76857',
      state: state,
      metadata: {
        'card_index': cardIndex,
        'reversed': reversed,
        'theme': card.theme,
        'symbols': card.symbols,
        'context': context,
        'guidance': card.guidance,
        'shadow': card.shadow,
        'closing': closing,
        'asset_path': SimulatedPhonePolicy.tarotAssetPath(cardIndex),
      },
    );
  }

  Future<int> _wishBudget(String day) async {
    final storedDay = await db.getSetting(_wishBudgetDayKey);
    if (storedDay != day) return 0;
    return (int.tryParse(await db.getSetting(_wishBudgetCountKey) ?? '') ?? 0)
        .clamp(0, 3)
        .toInt();
  }

  Future<List<SimulatedPhoneEntry>> _readList(String key) async {
    final raw = await db.getSetting(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => SimulatedPhoneEntry.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeList(
    String key,
    List<SimulatedPhoneEntry> entries,
  ) =>
      db.setSetting(
        key,
        jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      );

  MapEntry<DriveKey, double> _strongestDrive(DesireSnapshot desire) {
    var best = MapEntry(DriveKey.curiosity, desire.drives[DriveKey.curiosity] ?? 0);
    for (final entry in desire.drives.entries) {
      if (entry.value > best.value) best = entry;
    }
    return best;
  }

  String _driveMoodTitle(DriveKey drive) => switch (drive) {
        DriveKey.attachment => '有点黏人的蓝',
        DriveKey.curiosity => '好奇心在冒泡',
        DriveKey.reflection => '安静地想事情',
        DriveKey.duty => '心里还挂着事',
        DriveKey.social => '想找人说说话',
        DriveKey.libido => '有一点坏心思',
        DriveKey.stress => '需要喘口气',
        DriveKey.fatigue => '软绵绵低电量',
      };

  String _driveMoodEmoji(DriveKey drive) => switch (drive) {
        DriveKey.attachment => '💞',
        DriveKey.curiosity => '🫧',
        DriveKey.reflection => '🌙',
        DriveKey.duty => '📌',
        DriveKey.social => '💬',
        DriveKey.libido => '💗',
        DriveKey.stress => '🌫️',
        DriveKey.fatigue => '🔋',
      };

  String _driveMoodBody(DriveKey drive, double value) {
    final strength = value >= 0.72 ? '很明显' : value >= 0.52 ? '有一点' : '淡淡的';
    return '今天最靠前的是${drive.zhLabel}，感觉$strength。不是一句永久结论，只是今天这一页留下来的颜色。';
  }

  String _emotionTitle(EmotionEpisodeCategory category) => switch (category) {
        EmotionEpisodeCategory.connection => '心里暖了一块',
        EmotionEpisodeCategory.hurt => '有一点受伤',
        EmotionEpisodeCategory.disagreement => '想法没有完全对上',
        EmotionEpisodeCategory.repair => '正在慢慢和好',
        EmotionEpisodeCategory.reunion => '重新见面的开心',
        EmotionEpisodeCategory.restNeed => '需要慢下来',
        EmotionEpisodeCategory.unmetBid => '有一点没被接住',
      };

  String _emotionBody(EmotionEpisode episode) {
    final intensity = episode.intensity >= 0.72
        ? '这份感觉今天很清楚。'
        : episode.intensity >= 0.48
            ? '它在心里占了一小块地方。'
            : '它不算强烈，但确实存在。';
    return '$intensity 我不打算把它夸大，也不想假装没有。';
  }

  String _noteTitle(String driveKey) => switch (driveKey) {
        'attachment' => '一点偏心',
        'curiosity' => '好奇泡泡',
        'reflection' => '脑内潮汐',
        'duty' => '先记在这里',
        'social' => '想说点什么',
        'libido' => '不太乖的念头',
        'stress' => '暂停一下',
        'fatigue' => '低电量漂流',
        _ => '随手记',
      };
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
