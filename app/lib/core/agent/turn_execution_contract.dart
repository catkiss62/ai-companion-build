import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A slot names one accepted user goal, not one model call or retry attempt.
enum TurnEffectSlot {
  cedarForegroundWrite('cedar.foreground_write'),
  cedarControl('cedar.control'),
  cedarTimedRegistration('cedar.timed_registration'),
  creativeCommission('creative.commission'),
  creativeControl('creative.control');

  const TurnEffectSlot(this.key);
  final String key;
  static TurnEffectSlot? parse(Object? value) {
    for (final slot in values) {
      if (slot.key == value) return slot;
    }
    return null;
  }
}

String turnEffectId(String turnId, TurnEffectSlot slot) =>
    'user-turn:$turnId:${slot.key}';

/// Hash complete structured inputs, never a clipped prompt or JSON formatting.
String turnPayloadHash(Object? value) => sha256.convert(
      utf8.encode(jsonEncode(_canonical(value))),
    ).toString();

Object? _canonical(Object? value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('turn_payload_key_must_be_string');
    }
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList(growable: false);
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  throw const FormatException('unsupported_turn_payload');
}

class TurnTaskGoal {
  const TurnTaskGoal({required this.turnId, required this.slot,
    required this.description, this.authorized = true,
    this.target = const {}, this.durationText = '', this.minutes = 0});
  final String turnId;
  final TurnEffectSlot slot;
  final String description;
  final bool authorized;
  final Map<String, String> target;
  final String durationText;
  final int minutes;
  String get id => turnEffectId(turnId, slot);

  Map<String, Object?> toJson() => {'schema': 1, 'turn_id': turnId,
    'slot': slot.key, 'description': description, 'authorized': authorized,
    'target': target, 'duration_text': durationText, 'minutes': minutes};
  static TurnTaskGoal? fromJson(Object? raw) {
    try {
      if (raw is! Map || raw['schema'] != 1) return null;
      final slot = TurnEffectSlot.parse(raw['slot']);
      final turnId = raw['turn_id'] as String;
      if (slot == null || turnId.isEmpty) return null;
      return TurnTaskGoal(turnId: turnId, slot: slot,
        description: raw['description'] as String,
        authorized: raw['authorized'] == true,
        target: Map<String, String>.from(raw['target'] as Map),
        durationText: raw['duration_text'] as String? ?? '',
        minutes: (raw['minutes'] as num?)?.toInt() ?? 0);
    } catch (_) { return null; }
  }
}

enum LocalEffectState { staged, committed }

/// Local acceptance is a fact. Rewriting the assistant does not erase it.
class LocalEffectReceipt {
  const LocalEffectReceipt({required this.turnId, required this.slot,
    required this.payloadHash, required this.state, required this.result,
    required this.runToken, required this.createdAt,
    this.messageId = '', this.messageHash = '', this.messageRevision = 0});
  final String turnId;
  final TurnEffectSlot slot;
  final String payloadHash;
  final LocalEffectState state;
  final Map<String, Object?> result;
  final String runToken;
  final int createdAt;
  final String messageId, messageHash;
  final int messageRevision;
  String get effectId => turnEffectId(turnId, slot);
  bool get committed => state == LocalEffectState.committed;

  LocalEffectReceipt commit({required String messageId,
    required String messageHash, required int messageRevision}) =>
      LocalEffectReceipt(turnId: turnId, slot: slot, payloadHash: payloadHash,
        state: LocalEffectState.committed, result: result, runToken: runToken,
        createdAt: createdAt, messageId: messageId, messageHash: messageHash,
        messageRevision: messageRevision);

  Map<String, Object?> toJson() => {'schema': 1, 'effect_id': effectId,
    'turn_id': turnId, 'slot': slot.key, 'payload_hash': payloadHash,
    'state': state.name, 'result': result, 'run_token': runToken,
    'created_at': createdAt, 'message_id': messageId,
    'message_hash': messageHash, 'message_revision': messageRevision};
  static LocalEffectReceipt? fromJson(Object? raw) {
    try {
      if (raw is! Map || raw['schema'] != 1) return null;
      final slot = TurnEffectSlot.parse(raw['slot']);
      final state = switch (raw['state']) {
        'staged' => LocalEffectState.staged,
        'committed' => LocalEffectState.committed,
        _ => null,
      };
      final turnId = raw['turn_id'] as String;
      if (slot == null || state == null || turnId.isEmpty ||
          raw['effect_id'] != turnEffectId(turnId, slot)) return null;
      return LocalEffectReceipt(turnId: turnId, slot: slot,
        payloadHash: raw['payload_hash'] as String, state: state,
        result: Map<String, Object?>.from(raw['result'] as Map),
        runToken: raw['run_token'] as String, createdAt: raw['created_at'] as int,
        messageId: raw['message_id'] as String? ?? '',
        messageHash: raw['message_hash'] as String? ?? '',
        messageRevision: (raw['message_revision'] as num?)?.toInt() ?? 0);
    } catch (_) { return null; }
  }
}

enum LocalEffectAdmissionState { create, replay, conflict, staleAttempt, blocked }
class LocalEffectAdmission {
  const LocalEffectAdmission(this.state, [this.receipt]);
  final LocalEffectAdmissionState state;
  final LocalEffectReceipt? receipt;
  bool get canCreate => state == LocalEffectAdmissionState.create;
}

enum CedarDeliveryKind { terminal, timedReport }

/// A candidate is not proof: only final-visible-text verification plus the
/// winning message transaction may turn it into a delivery receipt.
class CedarDeliveryClaim {
  const CedarDeliveryClaim({required this.kind, required this.gameId,
    required this.sessionId, this.terminalKey = '', this.reportId = '',
    required this.summary});
  final CedarDeliveryKind kind;
  final String gameId, sessionId, terminalKey, reportId, summary;
  String get resultId => kind == CedarDeliveryKind.timedReport
      ? 'timed:$reportId' : 'terminal:$gameId:$sessionId:$terminalKey';
  String get resultHash => turnPayloadHash(toJson());
  bool get valid => gameId.isNotEmpty && sessionId.isNotEmpty &&
      summary.trim().isNotEmpty && (kind == CedarDeliveryKind.timedReport
        ? reportId.isNotEmpty : terminalKey.isNotEmpty);
  Map<String, Object?> toJson() => {'schema': 1, 'kind': kind.name,
    'game_id': gameId, 'session_id': sessionId, 'terminal_key': terminalKey,
    'report_id': reportId, 'summary': summary};
  static CedarDeliveryClaim? fromJson(Object? raw) {
    try {
      if (raw is! Map || raw['schema'] != 1) return null;
      final kind = switch (raw['kind']) {
        'terminal' => CedarDeliveryKind.terminal,
        'timedReport' => CedarDeliveryKind.timedReport,
        _ => null,
      };
      if (kind == null) return null;
      final claim = CedarDeliveryClaim(kind: kind,
        gameId: raw['game_id'] as String, sessionId: raw['session_id'] as String,
        terminalKey: raw['terminal_key'] as String? ?? '',
        reportId: raw['report_id'] as String? ?? '', summary: raw['summary'] as String);
      return claim.valid ? claim : null;
    } catch (_) { return null; }
  }
}

class CedarDeliveryReceipt {
  const CedarDeliveryReceipt({required this.claim, required this.messageId,
    required this.messageHash, required this.messageRevision, required this.committedAt});
  final CedarDeliveryClaim claim;
  final String messageId, messageHash;
  final int messageRevision, committedAt;
  Map<String, Object?> toJson() => {'schema': 1, 'claim': claim.toJson(),
    'message_id': messageId, 'message_hash': messageHash,
    'message_revision': messageRevision, 'committed_at': committedAt};
  static CedarDeliveryReceipt? fromJson(Object? raw) {
    try {
      if (raw is! Map || raw['schema'] != 1) return null;
      final claim = CedarDeliveryClaim.fromJson(raw['claim']);
      if (claim == null) return null;
      return CedarDeliveryReceipt(claim: claim,
        messageId: raw['message_id'] as String, messageHash: raw['message_hash'] as String,
        messageRevision: raw['message_revision'] as int,
        committedAt: raw['committed_at'] as int);
    } catch (_) { return null; }
  }
}

class TurnCommitEvidence {
  const TurnCommitEvidence({this.timedEffectIds = const [],
    this.deliveries = const [], this.timedHandoff});
  final List<String> timedEffectIds;
  final List<CedarDeliveryClaim> deliveries;
  /// Only the explicit incomplete-draft confirmation path may supply this.
  /// The timer commit hook must recheck the exact stage and current target.
  final TimedRegistrationHandoff? timedHandoff;
}

class TimedRegistrationHandoff {
  const TimedRegistrationHandoff({required this.effectId,
    required this.fromRunToken, required this.payloadHash, required this.stageHash});
  final String effectId, fromRunToken, payloadHash, stageHash;
}

/// Throw from inside a transaction to roll back every preceding insert.
class TurnCommitCancelled implements Exception {
  const TurnCommitCancelled();
}

void requireTurnNotCancelled(bool Function()? isCancelled) {
  if (isCancelled?.call() == true) throw const TurnCommitCancelled();
}

class TurnCommitRejected implements Exception {
  const TurnCommitRejected(this.reason);
  final String reason;
  @override String toString() => reason;
}
