import 'dart:convert';

class McpTurnStateResolution {
  const McpTurnStateResolution({
    required this.nextActor,
    required this.reason,
  });

  final String nextActor;
  final String reason;
}

/// Extracts high-confidence turn ownership from common structured MCP
/// outcomes. It deliberately returns null for ambiguity so an LLM may still
/// interpret free-form or server-specific results without overriding explicit
/// protocol facts.
class McpTurnStateResolver {
  const McpTurnStateResolver._();

  static const Set<String> _companionLabels = <String>{
    'ai',
    'assistant',
    'companion',
    'machine',
    'bound_machine',
    'bot',
    'self',
    'own',
  };
  static const Set<String> _userLabels = <String>{
    'user',
    'human',
    'player',
    'opponent',
    'remote_user',
  };
  static const Set<String> _terminalLabels = <String>{
    'finished',
    'completed',
    'ended',
    'terminal',
    'game_over',
    'cancelled',
    'canceled',
    'resigned',
  };

  static McpTurnStateResolution? resolve(String raw) {
    final decoded = _decodeLeadingJson(raw);
    return resolveStructured(decoded);
  }

  static McpTurnStateResolution? resolveStructured(Object? decoded) {
    if (decoded is! Map) return null;
    final root = _stringMap(decoded);
    final candidates = <Map<String, Object?>>[root];
    for (final key in const <String>['snapshot', 'state', 'data', 'result']) {
      final value = root[key];
      if (value is Map) candidates.insert(0, _stringMap(value));
    }
    final rooms = root['rooms'];
    if (rooms is List && rooms.length == 1 && rooms.single is Map) {
      candidates.insert(0, _stringMap(rooms.single as Map));
    }

    for (final map in candidates) {
      final status = _label(map['status']);
      if (_terminalLabels.contains(status) || map['terminal'] == true) {
        return const McpTurnStateResolution(
          nextActor: 'finished',
          reason: 'structured_terminal_status',
        );
      }
    }

    for (final map in candidates) {
      final direct = _normalizeActor(map['next_actor']);
      if (direct != null) {
        return McpTurnStateResolution(
          nextActor: direct,
          reason: 'structured_next_actor',
        );
      }
    }

    for (final map in candidates) {
      final actor = map['current_actor'];
      if (actor is Map) {
        final actorMap = _stringMap(actor);
        final direct = _participantSide(actorMap);
        if (direct != null) {
          return McpTurnStateResolution(
            nextActor: direct,
            reason: 'structured_current_actor_role',
          );
        }
        final matched = _matchActorToParticipants(
          actorMap,
          map['participants'] ?? root['participants'],
        );
        if (matched != null) return matched;
      } else {
        final direct = _normalizeActor(actor);
        if (direct != null) {
          return McpTurnStateResolution(
            nextActor: direct,
            reason: 'structured_current_actor',
          );
        }
      }

      final ownSeat = map['own_seat'] ?? root['own_seat'];
      final actorSeat = map['current_actor_seat'] ??
          map['current_seat'] ??
          root['current_actor_seat'];
      if (ownSeat != null && actorSeat != null) {
        return McpTurnStateResolution(
          nextActor: ownSeat.toString() == actorSeat.toString()
              ? 'companion'
              : 'user',
          reason: 'structured_seat_ownership',
        );
      }

      final turn = _normalizeActor(map['turn'] ?? map['current_turn']);
      if (turn != null) {
        return McpTurnStateResolution(
          nextActor: turn,
          reason: 'structured_turn_label',
        );
      }
    }
    return null;
  }

  static McpTurnStateResolution? _matchActorToParticipants(
    Map<String, Object?> actor,
    Object? rawParticipants,
  ) {
    if (rawParticipants is! List) return null;
    for (final raw in rawParticipants) {
      if (raw is! Map) continue;
      final participant = _stringMap(raw);
      if (!_sameIdentity(actor, participant)) continue;
      final side = _participantSide(participant);
      if (side == null) return null;
      return McpTurnStateResolution(
        nextActor: side,
        reason: 'structured_participant_identity',
      );
    }
    return null;
  }

  static bool _sameIdentity(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    for (final key in const <String>['player_id', 'participant_id', 'id', 'seat', 'token']) {
      final a = left[key];
      final b = right[key];
      if (a != null && b != null && a.toString() == b.toString()) return true;
    }
    return false;
  }

  static String? _participantSide(Map<String, Object?> value) {
    for (final key in const <String>['role', 'kind', 'type', 'actor_type']) {
      final normalized = _normalizeActor(value[key]);
      if (normalized != null) return normalized;
    }
    return null;
  }

  static String? _normalizeActor(Object? raw) {
    final label = _label(raw);
    if (_companionLabels.contains(label)) return 'companion';
    if (_userLabels.contains(label)) return 'user';
    if (const <String>{'shared', 'both', 'choice', 'input_required'}
        .contains(label)) {
      return 'shared';
    }
    if (const <String>{'wait', 'waiting', 'remote', 'other', 'pending'}
        .contains(label)) {
      return 'wait';
    }
    if (_terminalLabels.contains(label)) return 'finished';
    return null;
  }

  static String _label(Object? value) =>
      value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';

  static Map<String, Object?> _stringMap(Map source) => source.map(
        (key, value) => MapEntry(key.toString(), value),
      );

  static Object? _decodeLeadingJson(String raw) {
    final clean = raw.trimLeft();
    if (clean.isEmpty || (clean[0] != '{' && clean[0] != '[')) return null;
    try {
      return jsonDecode(clean);
    } catch (_) {
      // Some MCP servers append a human-readable notice after one valid JSON
      // object. Extract only the balanced leading value without guessing any
      // content inside it.
    }
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var index = 0; index < clean.length; index++) {
      final char = clean[index];
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
        continue;
      }
      if (char == '"') {
        quoted = true;
      } else if (char == '{' || char == '[') {
        depth++;
      } else if (char == '}' || char == ']') {
        depth--;
        if (depth == 0) {
          try {
            return jsonDecode(clean.substring(0, index + 1));
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }
}
