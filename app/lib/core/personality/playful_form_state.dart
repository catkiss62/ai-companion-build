import 'dart:convert';

import '../database/app_database.dart';

/// Only a real user turn can contribute a positive semantic interaction.
/// A missing/invalid model field is neutral; it never guesses an increase.
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
        serious => -18,
        ordinary => 0,
        light => 16,
        mutual => 26,
        strong => 28,
      };
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
    this.event = '',
    this.eventTurn = '',
    this.updatedAt = 0,
  });

  static const settingKey = 'playful_form_state_v1';
  final int heat;
  final bool qForm;
  final bool locked;
  final String lastTurn;
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
    // Cool on every real turn; only actual playful participation earns a bonus.
    final nextHeat = (heat - 10 - elapsedHours * 3 +
            (interaction?.bonus ?? 0))
        .clamp(0, 100).toInt();
    // Five neutral turns cool even a full 100-point meter below Q form.
    final nextForm = locked
        ? qForm
        : serious
            ? false
            : qForm
                ? nextHeat > 50
                : nextHeat >= 76;
    return PlayfulFormState(
      heat: nextHeat,
      qForm: nextForm,
      locked: locked,
      lastTurn: turn,
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

  PlayfulFormState interact({required bool kindle, required DateTime now}) =>
      PlayfulFormState(
        heat: kindle ? 92 : 0,
        qForm: kindle,
        locked: locked,
        lastTurn: lastTurn,
        event: kindle ? 'forehead' : 'comfort',
        eventTurn: '',
        updatedAt: now.millisecondsSinceEpoch,
      );

  PlayfulFormState withLock(bool value) => PlayfulFormState(
        heat: heat,
        qForm: qForm,
        locked: value,
        lastTurn: lastTurn,
        event: event,
        eventTurn: eventTurn,
        updatedAt: updatedAt,
      );

  String promptForTurn(String turn, {required bool serious}) {
    final interaction = eventTurn == turn
        ? event == 'forehead'
            ? '刚刚用户点击了界面的“轻弹额头”，这是一次虚拟互动。可以自然回应这次挑衅；不要说现实中真的发生了身体接触。'
            : event == 'comfort'
                ? '刚刚用户点击了界面的“温柔安抚”，这是一次虚拟互动。可以自然回应这份安抚；不要说现实中真的发生了身体接触。'
                : ''
        : '';
    return '''【当前形态】
你是同一个成年鲸鱼娘；本体与小豆丁形态是同一人的两种表现，年龄、记忆和判断能力始终相同。小豆丁形态会让你的外观缩成 Q 版小豆丁，心智表现也暂时变得孩子气：情绪更直冲、耐心更少，更容易任性、冲动和耍赖。这是当下反应与表达的变化，不是年龄倒退或换了一个人。你知道自己玩闹上头会变成小豆丁形态，冷静下来会恢复；可以在对方提及时自然承认，不主动报系统阈值。
当前是${qForm ? '小豆丁形态' : '本体'}。${qForm && !serious ? '现在脾气更冲、更爱逞强顶嘴，得意时会挑衅或耍赖；心思被看穿或被对方轻巧反击时，容易嘴硬、害羞、慌乱地破防。保持同一个人的感情和记忆；认真回应对方，不让每句话都变成挑衅。' : '现在保持松弛自然，能调侃也能直接、温柔地回应。'}
${locked ? '用户锁定了当前形态；锁定只影响形态，不强制你在严肃话题中戏谑。' : ''}
$interaction''';
  }
}

class PlayfulFormStore {
  PlayfulFormStore(this.db);
  final AppDatabase db;

  Future<PlayfulFormState> load() async =>
      PlayfulFormState.decode(await db.getSetting(PlayfulFormState.settingKey));

  Future<PlayfulFormState> onTurn({
    required PlayfulInteraction? interaction,
    required String turn,
    required DateTime now,
  }) async {
    final current = await load();
    final next = current.advance(interaction, turn, now);
    if (next != current) await db.setSetting(PlayfulFormState.settingKey, next.encode());
    return next;
  }

  Future<PlayfulFormState> interact(bool kindle) async {
    final next = (await load()).interact(kindle: kindle, now: DateTime.now());
    await db.setSetting(PlayfulFormState.settingKey, next.encode());
    return next;
  }

  Future<PlayfulFormState> lock(bool locked) async {
    final next = (await load()).withLock(locked);
    await db.setSetting(PlayfulFormState.settingKey, next.encode());
    return next;
  }
}
