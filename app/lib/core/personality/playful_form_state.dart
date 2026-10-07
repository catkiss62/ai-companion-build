import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Jev (or DeepSeek on failure) classifies the user's actual participation.
/// Unclear turns never receive a positive user contribution.
enum PlayfulInteraction {
  serious,
  ordinary,
  light,
  mutual,
  strong;

  static PlayfulInteraction? parse(Object? value) => switch (value) {
        'serious' => serious,
        'ordinary' => ordinary,
        'light' => light,
        'mutual' => mutual,
        'strong' => strong,
        _ => null,
      };

  int get bonus => switch (this) {
        serious || ordinary => 0,
        light => 5,
        mutual => 30,
        strong => 34,
      };
}

/// The assistant can contribute only when Jev (or its DeepSeek fallback)
/// classifies the actual final visible reply, not a proposed prompt direction.
enum PlayfulSelfActivity {
  none,
  playful,
  strong,
  settle;

  static PlayfulSelfActivity? parse(Object? value) => switch (value) {
        'none' => none,
        'playful' => playful,
        'strong' => strong,
        'settle' => settle,
        _ => null,
      };

  int get bonus => switch (this) {
        none => 0,
        playful => 3,
        strong => 5,
        settle => -8,
      };
}

/// A stable per-turn draw only offers an optional chance to initiate; it
/// never changes heat. Replaying a generation yields the same opportunity.
class PlayfulInitiativePolicy {
  const PlayfulInitiativePolicy._();

  static bool offer(String turnId, {required bool opportunity}) {
    if (!opportunity || turnId.isEmpty) return false;
    var hash = 2166136261;
    for (final unit in turnId.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return hash % 100 < 30;
  }
}

/// One persisted source of truth for the visible portrait and model-facing form.
/// A manual interaction changes the same value that ordinary dialogue later
/// advances; it does not install a permanent prompt override.
class PlayfulFormState {
  const PlayfulFormState({
    this.heat = 0,
    this.stimulusStreak = 0,
    this.beforeStimulusStreak = 0,
    this.manualRevision = 0,
    this.qForm = false,
    this.locked = false,
    this.lastTurn = '',
    this.lastAssistantTurn = '',
    this.pendingTurn = false,
    this.pendingInteraction = PlayfulInteraction.ordinary,
    this.pendingBreakthrough = false,
    this.pendingElapsedHours = 0,
    this.breakthroughReady = false,
    this.beforeBreakthroughReady = false,
    this.beforeHeat = 0,
    this.beforeQForm = false,
    this.beforeUpdatedAt = 0,
    this.beforeLastTurn = '',
    this.beforeEvent = '',
    this.beforeEventTurn = '',
    this.event = '',
    this.eventTurn = '',
    this.updatedAt = 0,
  });

  static const settingKey = 'playful_form_state_v1';
  final int heat;
  final int stimulusStreak;
  final int beforeStimulusStreak;
  final int manualRevision;
  bool get promptQForm => (!locked && pendingTurn && pendingBreakthrough) || qForm;
  final bool qForm;
  final bool locked;
  final String lastTurn;
  final String lastAssistantTurn;
  /// Only the newest uncommitted user turn is reversible on Stop.
  final bool pendingTurn;
  final PlayfulInteraction pendingInteraction;
  final bool pendingBreakthrough;
  final int pendingElapsedHours;
  /// The first full-meter turn gets one guaranteed hold. While later turns
  /// actually keep the meter at 100, they remain eligible for breakthrough.
  final bool breakthroughReady;
  final bool beforeBreakthroughReady;
  bool get breakthroughDue => heat == 100 && !qForm && !locked;
  final int beforeHeat;
  final bool beforeQForm;
  final int beforeUpdatedAt;
  final String beforeLastTurn;
  final String beforeEvent;
  final String beforeEventTurn;
  final String event;
  final String eventTurn;
  final int updatedAt;

  static PlayfulFormState decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? '') as Map<String, dynamic>;
      return PlayfulFormState(
        stimulusStreak: ((data['stimulusStreak'] as num?)?.toInt() ?? 0).clamp(0, 1).toInt(),
        beforeStimulusStreak: ((data['beforeStimulusStreak'] as num?)?.toInt() ?? 0).clamp(0, 1).toInt(),
        manualRevision: (data['manualRevision'] as num?)?.toInt() ?? 0,
        heat: ((data['heat'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
        qForm: data['qForm'] == true,
        locked: data['locked'] == true,
        lastTurn: data['lastTurn']?.toString() ?? '',
        lastAssistantTurn: data['lastAssistantTurn']?.toString() ?? '',
        pendingTurn: data['pendingTurn'] == true,
        pendingInteraction: PlayfulInteraction.parse(data['pendingInteraction']) ??
            PlayfulInteraction.ordinary,
        pendingBreakthrough: data['pendingBreakthrough'] == true,
        pendingElapsedHours: ((data['pendingElapsedHours'] as num?)?.toInt() ?? 0)
            .clamp(0, 12).toInt(),
        breakthroughReady: data['breakthroughReady'] == true,
        beforeBreakthroughReady: data['beforeBreakthroughReady'] == true,
        beforeHeat: ((data['beforeHeat'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
        beforeQForm: data['beforeQForm'] == true,
        beforeUpdatedAt: (data['beforeUpdatedAt'] as num?)?.toInt() ?? 0,
        beforeLastTurn: data['beforeLastTurn']?.toString() ?? '',
        beforeEvent: data['beforeEvent']?.toString() ?? '',
        beforeEventTurn: data['beforeEventTurn']?.toString() ?? '',
        event: data['event']?.toString() ?? '',
        eventTurn: data['eventTurn']?.toString() ?? '',
        updatedAt: (data['updatedAt'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const PlayfulFormState();
    }
  }

  String encode() => jsonEncode({
        'heat': heat,
        'stimulusStreak': stimulusStreak,
        'beforeStimulusStreak': beforeStimulusStreak,
        'manualRevision': manualRevision,
        'qForm': qForm,
        'locked': locked,
        'lastTurn': lastTurn,
        'lastAssistantTurn': lastAssistantTurn,
        'pendingTurn': pendingTurn,
        'pendingInteraction': pendingInteraction.name,
        'pendingBreakthrough': pendingBreakthrough,
        'pendingElapsedHours': pendingElapsedHours,
        'breakthroughReady': breakthroughReady,
        'beforeBreakthroughReady': beforeBreakthroughReady,
        'beforeHeat': beforeHeat,
        'beforeQForm': beforeQForm,
        'beforeUpdatedAt': beforeUpdatedAt,
        'beforeLastTurn': beforeLastTurn,
        'beforeEvent': beforeEvent,
        'beforeEventTurn': beforeEventTurn,
        'event': event,
        'eventTurn': eventTurn,
        'updatedAt': updatedAt,
      });

  PlayfulFormState advance(
    PlayfulInteraction? interaction,
    String turn,
    DateTime now,
    {bool? breakthrough}
  ) {
    if (turn.isEmpty || lastTurn == turn) return this;
    final elapsedHours = updatedAt == 0
        ? 0
        : ((now.millisecondsSinceEpoch - updatedAt) ~/ 3600000).clamp(0, 12);
    final serious = interaction == PlayfulInteraction.serious;
    final gentle = interaction == PlayfulInteraction.light ||
        interaction == PlayfulInteraction.mutual;
    // The turn that first fills the meter is protected. Only a completed,
    // still-full prior turn can contribute to the two-stimulus sequence.
    final stimulated = breakthroughDue &&
        (interaction == PlayfulInteraction.strong ||
         gentle && elapsedHours == 0 && stimulusStreak >= 1 ||
         breakthrough == true);
    // Keep the user classification provisional. Applying a negative delta now
    // can hit zero before the visible reply contributes its own real activity.
    return PlayfulFormState(
      heat: heat,
      qForm: qForm,
      locked: locked,
      lastTurn: turn,
      lastAssistantTurn: lastAssistantTurn,
      pendingTurn: true,
      pendingInteraction: interaction ?? PlayfulInteraction.ordinary,
      pendingBreakthrough: stimulated,
      stimulusStreak: stimulusStreak,
      beforeStimulusStreak: stimulusStreak,
      manualRevision: manualRevision,
      pendingElapsedHours: elapsedHours,
      breakthroughReady: breakthroughReady,
      beforeBreakthroughReady: breakthroughReady,
      beforeHeat: heat,
      beforeQForm: qForm,
      beforeUpdatedAt: updatedAt,
      beforeLastTurn: lastTurn,
      beforeEvent: event,
      beforeEventTurn: eventTurn,
      event: event.isNotEmpty && eventTurn.isEmpty && !serious &&
              now.millisecondsSinceEpoch - updatedAt <= 10 * 60 * 1000
          ? event
          : '',
      eventTurn: event.isNotEmpty && eventTurn.isEmpty && !serious &&
              now.millisecondsSinceEpoch - updatedAt <= 10 * 60 * 1000
          ? turn
          : '',
      updatedAt: now.millisecondsSinceEpoch,
    );
  }

  /// Restore a stopped turn only while no manual action or later turn has
  /// superseded its provisional heat. The caller performs this in the same
  /// SQLite transaction that withdraws the user message.
  PlayfulFormState rollbackTurn(String turn) {
    if (!pendingTurn || turn.isEmpty || lastTurn != turn) return this;
    return PlayfulFormState(
      heat: beforeHeat,
      stimulusStreak: beforeStimulusStreak,
      manualRevision: manualRevision,
      qForm: beforeQForm,
      breakthroughReady: beforeBreakthroughReady,
      locked: locked,
      lastTurn: beforeLastTurn,
      lastAssistantTurn: lastAssistantTurn,
      event: beforeEvent,
      eventTurn: beforeEventTurn,
      updatedAt: beforeUpdatedAt,
    );
  }

  PlayfulFormState onAssistantTurn(
    PlayfulSelfActivity activity,
    String assistantTurn,
    DateTime now,
  ) {
    if (!pendingTurn || assistantTurn.isEmpty || lastAssistantTurn == assistantTurn) return this;
    // One clamp and one form decision after both participants and the fixed
    // per-turn cooling have contributed. A pending Stop rolls back all of it.
    // Only the small form cools by 18 per completed turn.
    final cooling = qForm ? 18 : 0;
    final nextHeat = (heat + (pendingTurn ? pendingInteraction.bonus - cooling -
                (pendingInteraction == PlayfulInteraction.serious ? 12 : 0) -
                pendingElapsedHours * 3 : 0) + activity.bonus)
        .clamp(0, 100).toInt();
    final nextForm = locked ? qForm : qForm
        ? nextHeat > 0
        : pendingBreakthrough;
    final gentle = pendingInteraction == PlayfulInteraction.light ||
        pendingInteraction == PlayfulInteraction.mutual;
    // A long gap discards the previous streak, not this fresh stimulus.
    // Cooling still participates in nextHeat; dropping below full resets it.
    final nextStreak = !nextForm && !locked && heat == 100 && nextHeat == 100 &&
        gentle ? 1 : 0;
    return PlayfulFormState(
      heat: nextHeat,
      stimulusStreak: nextStreak,
      manualRevision: manualRevision,
      qForm: nextForm,
      breakthroughReady: !nextForm && !locked && nextHeat == 100,
      locked: locked,
      lastTurn: lastTurn,
      lastAssistantTurn: assistantTurn,
      event: event,
      eventTurn: eventTurn,
      updatedAt: now.millisecondsSinceEpoch,
    );
  }

  PlayfulFormState interact({required bool kindle, required DateTime now}) =>
      PlayfulFormState(
        heat: kindle ? 100 : 0,
        manualRevision: manualRevision + 1,
        qForm: kindle,
        breakthroughReady: false,
        locked: locked,
        lastTurn: lastTurn,
        lastAssistantTurn: lastAssistantTurn,
        event: kindle ? 'forehead' : 'comfort',
        eventTurn: '',
        updatedAt: now.millisecondsSinceEpoch,
      );

  PlayfulFormState withLock(bool value) {
    final data = jsonDecode(encode()) as Map<String, dynamic>;
    data['locked'] = value;
    if (value) {
      data['stimulusStreak'] = 0;
      data['beforeStimulusStreak'] = 0;
      data['pendingBreakthrough'] = false;
    }
    return PlayfulFormState.decode(jsonEncode(data));
  }

  String get currentFormFact => promptQForm
      ? '【本轮形态事实】当前为小豆丁形态，以本轮状态为准；本轮回复完成前不预判降温后的形态。'
      : '【本轮形态事实】当前为正常本体，不是小豆丁形态。历史消息里的小豆丁、变小、小短腿等描述属于当时的形态，不延续为当前身体或自称；回忆和引用历史不受此限制。可以继续自然调侃、亲近，不必播报恢复，也不必因形态正常而变严肃。';

  /// Reassert live state after historical Q-form dialogue, keeping a real
  /// current user message last. Both reasoning and final prose see one fact.
  void anchorCurrentForm(List<Map<String, Object?>> messages) {
    final index = messages.isNotEmpty && messages.last['role'] == 'user'
        ? messages.length - 1 : messages.length;
    messages.insert(index, {
      'role': 'system',
      'content': '$currentFormFact 推理与正文使用同一当前形态；历史措辞不改变形态事实。',
    });
  }

  String promptForTurn(String turn) {
    final interaction = eventTurn == turn
        ? event == 'forehead'
            ? '刚刚用户点击了界面的“轻弹额头”，这是一次虚拟互动。可以自然回应这次挑衅；不要说现实中真的发生了身体接触。'
            : event == 'comfort'
                ? '刚刚用户点击了界面的“温柔安抚”，这是一次虚拟互动。可以自然回应这份安抚；不要说现实中真的发生了身体接触。'
                : ''
        : '';
    return '''【当前形态】
你是同一个成年鲸鱼娘；本体与小豆丁形态是同一人的两种表现，年龄、记忆和判断能力始终相同。小豆丁形态会让你的外观缩成 Q 版小豆丁，心智表现也暂时变得孩子气：情绪更直冲、耐心更少，更容易任性、冲动和耍赖。这是当下反应与表达的变化，不是年龄倒退或换了一个人。玩闹的气焰升满只表示蓄势，连续被故意逗弄、明显的强挑衅或被逗到强烈害羞时会变成小豆丁；冷静下来会恢复。可以在对方提及时自然承认，不主动报系统阈值。
${pendingBreakthrough && !locked ? '这一轮被对方接连逗弄或强烈刺激，已经转为小豆丁；自然接着互动，不必专门播报变身。' : ''}
当前是${promptQForm ? '小豆丁形态' : '本体'}。${promptQForm ? '现在脾气更冲、更爱逞强顶嘴，得意时会挑衅或耍赖；心思被看穿或被对方轻巧反击时，容易嘴硬、害羞、慌乱地破防。保持同一个人的感情和记忆，不让每句话都变成挑衅。冷静是否完成在这轮回复结束后结算，不自行宣告已经恢复本体。' : '现在保持松弛自然，能调侃也能直接、温柔地回应。'}
${locked ? '用户锁定了当前形态。' : ''}
$interaction''';
  }
}

class PlayfulFormStore {
  PlayfulFormStore(this.db);
  final AppDatabase db;
  static const settlementKey = 'playful_last_settlement_v2';

  Future<PlayfulFormState> load() async =>
      PlayfulFormState.decode(await db.getSetting(PlayfulFormState.settingKey));

  static Future<PlayfulFormState> readInTransaction(DatabaseExecutor txn) async {
    final rows = await txn.query('settings', columns: const ['value'],
        where: 'key = ?', whereArgs: const [PlayfulFormState.settingKey], limit: 1);
    return PlayfulFormState.decode(rows.isEmpty ? null : rows.first['value'] as String?);
  }

  static Future<void> writeInTransaction(DatabaseExecutor txn, PlayfulFormState state) =>
      txn.rawInsert('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        [PlayfulFormState.settingKey, state.encode()]).then((_) {});

  Future<PlayfulFormState> _update(PlayfulFormState Function(PlayfulFormState) change) async {
    final database = await db.database;
    return database.transaction((txn) async {
      final current = await readInTransaction(txn);
      final next = change(current);
      if (!identical(next, current)) await writeInTransaction(txn, next);
      return next;
    });
  }

  /// The winning reply and this settlement share the same SQLite transaction.
  /// A manual form action invalidates the pending turn; a lock preserves it.
  static Future<void> settleInTransaction(DatabaseExecutor txn, {
    required String userTurn, required String assistantTurn,
    required PlayfulSelfActivity activity, required DateTime now,
  }) async {
    final current = await readInTransaction(txn);
    if (!current.pendingTurn || current.lastTurn != userTurn) return;
    final next = current.onAssistantTurn(activity, assistantTurn, now);
    if (identical(next, current)) return;
    final before = current.rollbackTurn(userTurn);
    await writeInTransaction(txn, next);
    await txn.rawInsert('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      [settlementKey, jsonEncode({'assistantTurn': assistantTurn,
        'before': before.encode(), 'after': next.encode()})]);
    const traceKey = 'playful_heat_trace_v1';
    final rows = await txn.query('settings', columns: const ['value'],
      where: 'key = ?', whereArgs: const [traceKey], limit: 1);
    List<dynamic> events;
    try { events = jsonDecode(rows.isEmpty ? '[]' : rows.first['value'] as String) as List; }
    catch (_) { events = []; }
    events.add({
      'at': now.millisecondsSinceEpoch, 'userTurn': userTurn,
      'assistantTurn': assistantTurn, 'beforeHeat': current.heat, 'afterHeat': next.heat,
      'beforeQForm': current.qForm, 'afterQForm': next.qForm,
      'interaction': current.pendingInteraction.name,
      'interactionBonus': current.pendingInteraction.bonus,
      'selfActivity': activity.name, 'selfBonus': activity.bonus,
      'fixedCooling': current.qForm ? 18 : 0,
      'seriousCooling': current.pendingInteraction == PlayfulInteraction.serious ? 12 : 0,
      'elapsedHours': current.pendingElapsedHours,
      'breakthrough': current.pendingBreakthrough,
      'stimulusBefore': current.beforeStimulusStreak, 'stimulusAfter': next.stimulusStreak,
      'settlementVersion': 2,
    });
    await txn.rawInsert('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      [traceKey, jsonEncode(events.length > 120 ? events.sublist(events.length - 120) : events)]);
  }

  /// Undo only the latest matching reply version, never a newer manual action.
  static Future<void> undoReplyInTransaction(DatabaseExecutor txn, String assistantTurn) async {
    final rows = await txn.query('settings', columns: const ['value'],
      where: 'key = ?', whereArgs: const [settlementKey], limit: 1);
    if (rows.isEmpty) return; // Older app versions did not retain an undo snapshot.
    Map<String, dynamic> record;
    try { record = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>; }
    catch (_) { return; }
    if (record['assistantTurn'] != assistantTurn) return;
    final current = await readInTransaction(txn);
    final after = PlayfulFormState.decode(record['after'] as String?);
    if (current.lastAssistantTurn != assistantTurn ||
        current.manualRevision != after.manualRevision || current.pendingTurn) return;
    final before = PlayfulFormState.decode(record['before'] as String?);
    final restored = jsonDecode(before.withLock(current.locked).encode())
        as Map<String, dynamic>;
    // A lock taken after the old reply must keep the form the user locked,
    // even when undoing that reply would otherwise cross a form boundary.
    if (current.locked) restored['qForm'] = current.qForm;
    await writeInTransaction(txn, PlayfulFormState.decode(jsonEncode(restored)));
    await txn.delete('settings', where: 'key = ?', whereArgs: const [settlementKey]);
  }

  Future<PlayfulFormState> onTurn({required PlayfulInteraction? interaction,
    required String turn, required DateTime now, bool? breakthrough}) =>
    _update((current) => current.advance(interaction, turn, now, breakthrough: breakthrough));

  Future<PlayfulFormState> onAssistantTurn({required PlayfulSelfActivity activity,
    required String assistantTurn, required DateTime now}) async {
    final database = await db.database;
    return database.transaction((txn) async {
      final current = await readInTransaction(txn);
      await settleInTransaction(txn, userTurn: current.lastTurn,
        assistantTurn: assistantTurn, activity: activity, now: now);
      return readInTransaction(txn);
    });
  }

  Future<PlayfulFormState> interact(bool kindle) =>
    _update((current) => current.interact(kindle: kindle, now: DateTime.now()));
  Future<PlayfulFormState> lock(bool locked) => _update((current) => current.withLock(locked));
}
