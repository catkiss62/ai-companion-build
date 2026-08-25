import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/emotion_episode.dart';
import '../models/thought.dart';
import 'simulated_phone_policy.dart';

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
}

/// A privacy boundary and local projection store for the simulated phone.
///
/// Reading the phone never creates Perception, Thought, Memory, Emotion or
/// chat-prompt input. Only bounded summaries already approved for presentation
/// are projected into this private UI store. The master switch blocks every
/// producer except the deterministic daily tarot pair.
class SimulatedPhoneRepository {
  SimulatedPhoneRepository(this.db);

  final AppDatabase db;

  static const enabledKey = 'simulated_phone_enabled';
  static const _leaseKey = 'simulated_phone_refresh_lease_until';
  static const _diaryKey = 'simulated_phone_diary_json';
  static const _notesKey = 'simulated_phone_notes_json';
  static const _moodKey = 'simulated_phone_mood_json';
  static const _wishesKey = 'simulated_phone_wishes_json';
  static const _completedWishesKey = 'simulated_phone_completed_wishes_json';
  static const _cartKey = 'simulated_phone_cart_json';
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
    final tarot = await _readList(_tarotKey);
    return SimulatedPhoneSnapshot(
      enabled: await isEnabled(),
      diary: await _readList(_diaryKey),
      notes: await _readList(_notesKey),
      moods: await _readList(_moodKey),
      wishes: await _readList(_wishesKey),
      completedWishes: await _readList(_completedWishesKey),
      cart: await _readList(_cartKey),
      tarotSelf: _firstWhereOrNull(tarot, (entry) => entry.state == 'self'),
      tarotUser: _firstWhereOrNull(tarot, (entry) => entry.state == 'user'),
    );
  }

  Future<void> refreshIfDue({DateTime? now}) async {
    final current = (now ?? DateTime.now()).toLocal();
    await _refreshTarot(current);
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
    if (existing.isNotEmpty && existing.every((entry) => entry.localDay == day)) {
      return;
    }
    const normal = <(String, String, int)>[
      ('海盐蓝软毯', '看起来很适合把尾巴也一起裹进去。', 18),
      ('鲸鱼形玻璃杯', '喝水的时候会有一只小鲸鱼在杯底游。', 12),
      ('深蓝色发带', '和女仆装应该会很搭。', 9),
      ('迷你照片打印机', '想把真正喜欢的图变成能摸到的小纸片。', 26),
      ('夜航星空灯', '关灯以后，房间里也能留一点海面的光。', 21),
    ];
    const funny = <(String, String, int)>[
      ('备用脑子一箱', '原装脑子偶尔会被自己绕晕。', 3),
      ('防剪鱼鳍护甲', '据说能抵挡至少十三次坏心眼。', 7),
      ('无限续杯青盐奶茶', '第一杯绝对不许再记错。', 5),
      ('会替人写检讨的贝壳', '缺点是它可能先替自己辩解。', 4),
      ('尾巴专用停车位', '禁止其他鱼类临时占用。', 6),
    ];
    final a = SimulatedPhonePolicy.stableIndex(day, normal.length, salt: 11);
    final b = SimulatedPhonePolicy.stableIndex(day, normal.length, salt: 29);
    final c = SimulatedPhonePolicy.stableIndex(day, funny.length, salt: 47);
    final e = SimulatedPhonePolicy.stableIndex(day, funny.length, salt: 71);
    final picks = <(String, String, int)>[
      normal[a],
      normal[b == a ? (b + 1) % normal.length : b],
      funny[c],
      funny[e == c ? (e + 1) % funny.length : e],
    ];
    final entries = <SimulatedPhoneEntry>[];
    for (var i = 0; i < picks.length; i++) {
      final item = picks[i];
      entries.add(
        SimulatedPhoneEntry(
          id: 'cart:$day:$i',
          kind: 'cart',
          title: item.$1,
          body: item.$2,
          localDay: day,
          createdAt: now,
          provenance: 'persona_cart_catalog',
          metadata: {'token_price': item.$3},
        ),
      );
    }
    await _writeList(_cartKey, entries);
  }

  Future<void> _refreshTarot(DateTime now) async {
    final day = SimulatedPhonePolicy.localDay(now);
    final existing = await _readList(_tarotKey);
    if (existing.length == 2 &&
        existing.every((entry) => entry.localDay == day)) {
      return;
    }
    const cards = <(String, String, String)>[
      ('愚者', '先迈出一步，再慢慢认识路。今天适合保留一点不那么功利的好奇。', '别急着把所有可能性都算完。今天允许自己试一次没有标准答案的小事。'),
      ('魔术师', '手边已经有能用的东西，差的只是把念头变成第一个动作。', '今天真正有用的不是准备更多，而是挑一件能马上动手的小事。'),
      ('女祭司', '有些答案不适合追着跑，安静下来反而会浮上来。', '今天可以相信那种说不清原因、但一直没有消失的直觉。'),
      ('皇后', '照顾感受不是偷懒。把自己安顿好，创造力才有地方长出来。', '今天适合把生活里一个小角落弄得舒服一点，也照顾一下自己的心情。'),
      ('战车', '方向比速度重要。选定以后，杂音就只是路边的浪。', '今天容易被几件事一起拉扯，先决定最想抵达哪里。'),
      ('力量', '真正的力量不是压住一切，而是能温柔地牵住那头乱撞的小兽。', '别和自己的情绪硬碰硬。慢一点，反而更容易把事情握稳。'),
      ('隐者', '独处不是离开世界，是把灯提近一点，看清自己正在找什么。', '今天适合留一点不被消息打断的时间，想清楚一个真正属于自己的问题。'),
      ('命运之轮', '变化已经在转动。抓不住每一根辐条，也仍然可以选好站姿。', '计划外的变化未必是坏事，先看看它把哪扇门转到了面前。'),
      ('星星', '希望不一定很响，它也可以只是一点一直没有灭掉的蓝光。', '今天适合重新捡起一件曾经期待、后来暂时放下的事。'),
      ('月亮', '看不清的时候，想象会把影子拉得很长。先别急着给影子定罪。', '今天遇到含糊的信号，最好多确认一次，不要让脑补替事实回答。'),
      ('太阳', '光落下来以后，很多事情其实比想象中简单。', '今天适合坦率一点。能说清楚的喜欢、感谢和期待，就不要藏得太深。'),
      ('世界', '一个小循环正在收尾。完成不是停下，而是终于能带着经验去下一站。', '今天适合把一件拖了很久的小事真正收口，给自己一个明确的完成感。'),
    ];
    final selfIndex = SimulatedPhonePolicy.stableIndex(day, cards.length, salt: 101);
    var userIndex = SimulatedPhonePolicy.stableIndex(day, cards.length, salt: 307);
    if (userIndex == selfIndex) userIndex = (userIndex + 1) % cards.length;
    final self = cards[selfIndex];
    final user = cards[userIndex];
    final entries = [
      SimulatedPhoneEntry(
        id: 'tarot:$day:self',
        kind: 'tarot',
        title: self.$1,
        body: self.$2,
        localDay: day,
        createdAt: now,
        provenance: 'daily_tarot_catalog',
        state: 'self',
      ),
      SimulatedPhoneEntry(
        id: 'tarot:$day:user',
        kind: 'tarot',
        title: user.$1,
        body: user.$3,
        localDay: day,
        createdAt: now,
        provenance: 'daily_tarot_catalog',
        state: 'user',
      ),
    ];
    await _writeList(_tarotKey, entries);
    await db.setSetting('simulated_phone_tarot_last_day', day);
  }

  Future<int> _wishBudget(String day) async {
    final storedDay = await db.getSetting(_wishBudgetDayKey);
    if (storedDay != day) return 0;
    return (int.tryParse(await db.getSetting(_wishBudgetCountKey) ?? '') ?? 0)
        .clamp(0, 3);
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
