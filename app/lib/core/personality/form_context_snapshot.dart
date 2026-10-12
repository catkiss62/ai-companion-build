import 'dart:convert';

import 'playful_form_state.dart';

/// Immutable provenance of a message, never a second personality or memory.
/// An absent legacy value stays unknown; dialogue wording is not evidence.
class FormContextSnapshot {
  const FormContextSnapshot({
    this.form = 'unknown',
    this.capturedAt = 0,
    this.captureKind = '',
    this.manualRevision = 0,
    this.lastTransitionJson = '',
    this.afterForm = '',
    this.settledAt = 0,
  });

  final String form;
  final int capturedAt;
  final String captureKind;
  final int manualRevision;
  final String lastTransitionJson;
  final String afterForm;
  final int settledAt;
  bool get isKnown => form == 'normal' || form == 'q';

  factory FormContextSnapshot.capture(PlayfulFormState state, {
    required DateTime now, required String kind, bool generation = false,
  }) {
    final q = generation ? state.promptQForm : state.qForm;
    final entering = generation && !state.qForm && q;
    return FormContextSnapshot(
      form: q ? 'q' : 'normal', capturedAt: now.millisecondsSinceEpoch,
      captureKind: kind, manualRevision: state.manualRevision,
      lastTransitionJson: entering ? jsonEncode({
        'from': 'normal', 'to': 'q',
        'at': now.millisecondsSinceEpoch,
        'source': 'reply_generation', 'turn': state.lastTurn,
      }) : state.lastTransitionJson,
    );
  }

  factory FormContextSnapshot.fromForm({required bool qForm,
    required DateTime now, required String kind}) => FormContextSnapshot(
      form: qForm ? 'q' : 'normal', capturedAt: now.millisecondsSinceEpoch,
      captureKind: kind);

  static FormContextSnapshot decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? '') as Map<String, dynamic>;
      final form = data['form'];
      if (data['v'] != 1 || (form != 'normal' && form != 'q')) {
        return const FormContextSnapshot();
      }
      return FormContextSnapshot(form: form as String,
        capturedAt: (data['captured_at'] as num?)?.toInt() ?? 0,
        captureKind: data['capture_kind'] as String? ?? '',
        manualRevision: (data['manual_revision'] as num?)?.toInt() ?? 0,
        lastTransitionJson: data['last_transition_json'] as String? ?? '',
        afterForm: const ['normal', 'q'].contains(data['after_form'])
            ? data['after_form'] as String : '',
        settledAt: (data['settled_at'] as num?)?.toInt() ?? 0);
    } catch (_) { return const FormContextSnapshot(); }
  }

  String encode() => isKnown ? jsonEncode({
    'v': 1, 'form': form, 'captured_at': capturedAt,
    'capture_kind': captureKind, 'manual_revision': manualRevision,
    'last_transition_json': lastTransitionJson,
    if (afterForm.isNotEmpty) 'after_form': afterForm,
    if (settledAt > 0) 'settled_at': settledAt,
  }) : '';

  /// Only called after this exact reply wins its settlement transaction.
  FormContextSnapshot settled(PlayfulFormState state, DateTime now) {
    if (!isKnown || state.manualRevision != manualRevision) return this;
    return FormContextSnapshot(form: form, capturedAt: capturedAt,
      captureKind: captureKind, manualRevision: manualRevision,
      lastTransitionJson: lastTransitionJson,
      afterForm: state.qForm ? 'q' : 'normal',
      settledAt: now.millisecondsSinceEpoch);
  }

  static String _name(String form) => form == 'q' ? '小豆丁' : '正常本体';
  String get historicalLabel {
    if (!isKnown) return '当时形态：未知（旧记录未保存，不推断）';
    final phase = captureKind == 'user_received' ? '用户发言时'
        : captureKind == 'room_entry' ? '房间进入时固定'
        : '回复生成时';
    final after = afterForm.isNotEmpty && afterForm != form && settledAt > 0
        ? '；回复提交结算后于${DateTime.fromMillisecondsSinceEpoch(settledAt).toIso8601String()}恢复为${_name(afterForm)}'
        : '';
    return '当时形态：${_name(form)}（$phase）$after';
  }

  String get transitionLabel {
    try {
      final data = jsonDecode(lastTransitionJson) as Map<String, dynamic>;
      final from = data['from']; final to = data['to']; final at = data['at'];
      if (!const ['normal', 'q'].contains(from) ||
          !const ['normal', 'q'].contains(to) || from == to || at is! int || at <= 0) return '';
      final source = switch (data['source']) {
        'manual_forehead' => '轻弹额头', 'manual_comfort' => '温柔安抚',
        'reply_generation' => '该轮生成开始', 'reply_settlement' => '回复完成结算',
        _ => '已保存状态变更',
      };
      return '${DateTime.fromMillisecondsSinceEpoch(at).toIso8601String()}由${_name(from as String)}转为${_name(to as String)}（$source）';
    } catch (_) { return ''; }
  }
}
