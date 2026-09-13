import 'dart:convert';

class McpTurnStateResolution {
  const McpTurnStateResolution({
    required this.nextActor,
    required this.reason,
  });

  final String nextActor;
  final String reason;
}

class McpContinuationCall {
  const McpContinuationCall({
    required this.action,
    required this.params,
    this.game = '',
    this.waitScope = '',
  });

  final String game;
  final String action;
  final Map<String, Object?> params;
  final String waitScope;

  bool get isLongPoll => params['wait'] == true;
}

class McpRoomMessageSignal {
  const McpRoomMessageSignal({
    required this.fingerprint,
    required this.author,
    required this.message,
    required this.fromCompanion,
  });

  final String fingerprint;
  final String author;
  final String message;
  final bool fromCompanion;
}

class McpRoomMessageBatch {
  const McpRoomMessageBatch({
    required this.messages,
    required this.ownAliases,
  });

  final List<McpRoomMessageSignal> messages;
  final Set<String> ownAliases;
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
    final candidates = _structuredMaps(decoded);
    final root = _stringMap(decoded);

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
    for (final key in const <String>[
      'role',
      'kind',
      'type',
      'actor_type',
      'participant_kind',
      'controller',
    ]) {
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

/// Reads the server-provided continuation instruction without inventing an
/// action. Callers must still validate the action against the complete guide
/// and pass it through the ordinary MCP executor/lease gates.
class McpContinuationCallResolver {
  const McpContinuationCallResolver._();

  static McpContinuationCall? resolve(String raw) =>
      resolveStructured(McpTurnStateResolver._decodeLeadingJson(raw));

  static McpContinuationCall? resolveStructured(Object? decoded) {
    if (decoded is! Map) return null;
    for (final candidate in _structuredMaps(decoded)) {
      final rawCall = candidate['next_call'];
      if (rawCall is! Map) continue;
      final call = McpTurnStateResolver._stringMap(rawCall);
      final action = _identifier(call['action']);
      if (action.isEmpty) continue;
      final rawParams = call['params'];
      if (rawParams != null && rawParams is! Map) continue;
      return McpContinuationCall(
        game: _identifier(call['game']),
        action: action,
        params: rawParams is Map
            ? McpTurnStateResolver._stringMap(rawParams)
            : const <String, Object?>{},
        waitScope: candidate['wait_scope']?.toString().trim() ?? '',
      );
    }
    return null;
  }

  static String _identifier(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return RegExp(r'^[A-Za-z0-9_.:-]{1,80}$').hasMatch(value) ? value : '';
  }
}

/// Extracts public room chat events and stable own-participant aliases from
/// common structured MCP outcomes. It never reads a web page or hidden state.
class McpRoomMessageResolver {
  const McpRoomMessageResolver._();

  static McpRoomMessageBatch resolve(
    String raw, {
    Iterable<String> knownOwnAliases = const <String>[],
  }) =>
      resolveStructured(
        McpTurnStateResolver._decodeLeadingJson(raw),
        knownOwnAliases: knownOwnAliases,
      );

  static McpRoomMessageBatch resolveStructured(
    Object? decoded, {
    Iterable<String> knownOwnAliases = const <String>[],
  }) {
    final ownAliases = <String>{
      for (final alias in knownOwnAliases)
        if (_alias(alias).isNotEmpty) _alias(alias),
    };
    if (decoded is! Map) {
      return McpRoomMessageBatch(
        messages: const <McpRoomMessageSignal>[],
        ownAliases: ownAliases,
      );
    }
    final candidates = _structuredMaps(decoded);
    for (final candidate in candidates) {
      final participants = candidate['participants'];
      if (participants is! List) continue;
      for (final rawParticipant in participants) {
        if (rawParticipant is! Map) continue;
        final participant = McpTurnStateResolver._stringMap(rawParticipant);
        if (McpTurnStateResolver._participantSide(participant) != 'companion') {
          continue;
        }
        ownAliases.addAll(_identityAliases(participant));
      }
    }

    final messages = <McpRoomMessageSignal>[];
    final emitted = <String>{};
    for (final candidate in candidates) {
      final events = candidate['events'];
      if (events is! List) continue;
      for (final rawEvent in events) {
        if (rawEvent is! Map) continue;
        final event = McpTurnStateResolver._stringMap(rawEvent);
        final message = event['message']?.toString().trim() ?? '';
        if (message.isEmpty) continue;
        final fingerprint = _fingerprint(event);
        if (!emitted.add(fingerprint)) continue;
        final eventAliases = _identityAliases(event);
        final fromCompanion =
            McpTurnStateResolver._participantSide(event) == 'companion' ||
                eventAliases.any(ownAliases.contains);
        final author = (event['name'] ??
                event['display_name'] ??
                event['author'] ??
                event['player_id'] ??
                '')
            .toString()
            .trim();
        messages.add(McpRoomMessageSignal(
          fingerprint: fingerprint,
          author: author.length <= 120 ? author : author.substring(0, 120),
          message: message.length <= 1000 ? message : message.substring(0, 1000),
          fromCompanion: fromCompanion,
        ));
      }
    }
    return McpRoomMessageBatch(messages: messages, ownAliases: ownAliases);
  }

  static Set<String> _identityAliases(Map<String, Object?> value) => <String>{
        for (final key in const <String>[
          'player_id',
          'participant_id',
          'id',
          'name',
          'display_name',
        ])
          if (_alias(value[key]).isNotEmpty) _alias(value[key]),
      };

  static String _alias(Object? raw) => raw?.toString().trim().toLowerCase() ?? '';

  static String _fingerprint(Map<String, Object?> event) {
    final source = jsonEncode(event);
    var hash = 0x811c9dc5;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 'room-${hash.toRadixString(16)}';
  }
}

List<Map<String, Object?>> _structuredMaps(Object? value, [int depth = 0]) {
  if (value is! Map || depth > 4) return const <Map<String, Object?>>[];
  final map = McpTurnStateResolver._stringMap(value);
  final result = <Map<String, Object?>>[];
  for (final key in const <String>[
    'snapshot',
    'state',
    'data',
    'result',
    'room',
  ]) {
    result.addAll(_structuredMaps(map[key], depth + 1));
  }
  final rooms = map['rooms'];
  if (rooms is List) {
    for (final room in rooms.take(8)) {
      result.addAll(_structuredMaps(room, depth + 1));
    }
  }
  result.add(map);
  return result;
}
