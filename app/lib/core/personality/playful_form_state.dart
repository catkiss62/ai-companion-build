import 'dart:convert';

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
        light => 6,
        mutual => 30,
        strong => 42,
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
        playful => 16,
        strong => 24,
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
    this.qForm = false,
    this.locked = false,
    this.lastTurn = '',
    this.lastAssistantTurn = '',
    this.event = '',
    this.eventTurn = '',
    this.updatedAt = 0,
  });

  static const settingKey = 'playful_form_state_v1';
  final int heat;
  final bool qForm;
  final bool locked;
  final String lastTurn;
  final String lastAssistantTurn;
  final String event;
  final String eventTurn;
  final int updatedAt;

  static PlayfulFormState decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? '') as Map<String, dynamic>;
      return PlayfulFormState(
        heat: ((data['heat'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
        qForm: data['qForm'] == true,
        locked: data['locked'] == true,
        lastTurn: data['lastTurn']?.toString() ?? '',
        lastAssistantTurn: data['lastAssistantTurn']?.toString() ?? '',
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
        'qForm': qForm,
        'locked': locked,
        'lastTurn': lastTurn,
        'lastAssistantTurn': lastAssistantTurn,
        'event': event,
        'eventTurn': eventTurn,
        'updatedAt': updatedAt,
      });

  PlayfulFormState advance(
    PlayfulInteraction? interaction,
    String turn,
    DateTime now,
  ) {
    if (turn.isEmpty || lastTurn == turn) return this;
    final elapsedHours = updatedAt == 0
        ? 0
        : ((now.millisecondsSinceEpoch - updatedAt) ~/ 3600000).clamp(0, 12);
    final serious = interaction == PlayfulInteraction.serious;
    // Ordinary talk is nearly level in adult form. Q-form play cools
    // naturally unless one of them actually continues the playful exchange.
    final naturalCooling = qForm ? 15 : 2;
    final nextHeat = (heat - naturalCooling - elapsedHours * 3 +
            (interaction?.bonus ?? 0))
        .clamp(0, 100).toInt();
    final nextForm = _formAt(nextHeat);
    return PlayfulFormState(
      heat: nextHeat,
      qForm: nextForm,
      locked: locked,
      lastTurn: turn,
      lastAssistantTurn: lastAssistantTurn,
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

  bool _formAt(int value) => locked ? qForm : qForm ? value > 0 : value == 100;

  PlayfulFormState onAssistantTurn(
    PlayfulSelfActivity activity,
    String assistantTurn,
    DateTime now,
  ) {
    if (assistantTurn.isEmpty || lastAssistantTurn == assistantTurn) return this;
    final nextHeat = (heat + activity.bonus).clamp(0, 100).toInt();
    return PlayfulFormState(
      heat: nextHeat,
      qForm: _formAt(nextHeat),
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
        qForm: kindle,
        locked: locked,
        lastTurn: lastTurn,
        lastAssistantTurn: lastAssistantTurn,
        event: kindle ? 'forehead' : 'comfort',
        eventTurn: '',
        updatedAt: now.millisecondsSinceEpoch,
      );

  PlayfulFormState withLock(bool value) => PlayfulFormState(
        heat: heat,
        qForm: qForm,
        locked: value,
        lastTurn: lastTurn,
        lastAssistantTurn: lastAssistantTurn,
        event: event,
        eventTurn: eventTurn,
        updatedAt: updatedAt,
      );

  String promptForTurn(String turn) {
    final interaction = eventTurn == turn
        ? event == 'forehead'
            ? '刚刚用户点击了界面的“轻弹额头”，这是一次虚拟互动。可以自然回应这次挑衅；不要说现实中真的发生了身体接触。'
            : event == 'comfort'
                ? '刚刚用户点击了界面的“温柔安抚”，这是一次虚拟互动。可以自然回应这份安抚；不要说现实中真的发生了身体接触。'
                : ''
        : '';
    return '''【当前形态】
你是同一个成年鲸鱼娘；本体与小豆丁形态是同一人的两种表现，年龄、记忆和判断能力始终相同。小豆丁形态会让你的外观缩成 Q 版小豆丁，心智表现也暂时变得孩子气：情绪更直冲、耐心更少，更容易任性、冲动和耍赖。这是当下反应与表达的变化，不是年龄倒退或换了一个人。你知道自己玩闹上头会变成小豆丁形态，冷静下来会恢复；可以在对方提及时自然承认，不主动报系统阈值。
当前是${qForm ? '小豆丁形态' : '本体'}。${qForm ? '现在脾气更冲、更爱逞强顶嘴，得意时会挑衅或耍赖；心思被看穿或被对方轻巧反击时，容易嘴硬、害羞、慌乱地破防。保持同一个人的感情和记忆，不让每句话都变成挑衅。' : '现在保持松弛自然，能调侃也能直接、温柔地回应。'}
${locked ? '用户锁定了当前形态。' : ''}
$interaction''';
  }
}

class PlayfulFormStore {
  PlayfulFormStore(this.db);
  final AppDatabase db;

  Future<PlayfulFormState> load() async =>
      PlayfulFormState.decode(await db.getSetting(PlayfulFormState.settingKey));

  /// All heat and lock mutations use the same SQLite transaction. A delayed
  /// Jev result must not overwrite a manual action or a newer user turn.
  Future<PlayfulFormState> _update(
    PlayfulFormState Function(PlayfulFormState) change,
  ) async {
    final database = await db.database;
    return database.transaction<PlayfulFormState>((txn) async {
      final rows = await txn.query(
        'settings',
        columns: const ['value'],
        where: 'key = ?',
        whereArgs: const [PlayfulFormState.settingKey],
        limit: 1,
      );
      final current = PlayfulFormState.decode(
        rows.isEmpty ? null : rows.first['value'] as String?,
      );
      final next = change(current);
      if (next != current) {
        await txn.rawInsert(
          'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
          [PlayfulFormState.settingKey, next.encode()],
        );
      }
      return next;
    });
  }

  Future<PlayfulFormState> onTurn({
    required PlayfulInteraction? interaction,
    required String turn,
    required DateTime now,
  }) =>
      _update((current) => current.advance(interaction, turn, now));

  Future<PlayfulFormState> onAssistantTurn({
    required PlayfulSelfActivity activity,
    required String assistantTurn,
    required DateTime now,
  }) =>
      _update((current) =>
          current.onAssistantTurn(activity, assistantTurn, now));

  Future<PlayfulFormState> interact(bool kindle) =>
      _update((current) =>
          current.interact(kindle: kindle, now: DateTime.now()));

  Future<PlayfulFormState> lock(bool locked) =>
      _update((current) => current.withLock(locked));
}
