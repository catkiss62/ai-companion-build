import 'dart:convert';

import 'mcp_turn_state_resolver.dart';

/// CedarDuet documents `state + wait=true` as the canonical observer for a
/// non-own turn. Official CedarToy normally supplies this as `next_call`, but
/// an immediate `new`, `rooms`, or one-shot reconciliation response can expose
/// only the room object. This adapter derives only a read, never a move, and
/// stays outside the game-neutral MCP turn resolver.
class CedarDuelObserverResolver {
  const CedarDuelObserverResolver._();

  static McpContinuationCall? resolve(String raw) {
    try {
      return resolveStructured(jsonDecode(raw.trim()));
    } catch (_) {
      return null;
    }
  }

  static McpContinuationCall? resolveStructured(Object? decoded) {
    final roomIds = <String>{};
    _collectActiveRoomIds(decoded, roomIds, 0);
    if (roomIds.length != 1) return null;
    return McpContinuationCall(
      game: 'duel',
      action: 'state',
      params: <String, Object?>{
        'room_id': roomIds.single,
        'wait': true,
      },
      waitScope: 'current_request_only',
    );
  }

  static void _collectActiveRoomIds(
    Object? value,
    Set<String> roomIds,
    int depth,
  ) {
    if (depth > 5) return;
    if (value is List) {
      for (final item in value.take(12)) {
        _collectActiveRoomIds(item, roomIds, depth + 1);
      }
      return;
    }
    if (value is! Map) return;
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    final status = map['status']?.toString().trim().toLowerCase() ?? '';
    final terminal = const <String>{
      'finished',
      'archived',
      'cancelled',
      'canceled',
      'left',
    }.contains(status);
    final roomId = map['room_id']?.toString().trim() ?? '';
    if (!terminal && RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(roomId)) {
      roomIds.add(roomId);
    }
    for (final key in const <String>[
      'snapshot',
      'state',
      'data',
      'result',
      'room',
      'rooms',
    ]) {
      _collectActiveRoomIds(map[key], roomIds, depth + 1);
    }
  }
}
