import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'qq_api.dart';

/// Event-driven C2C-only gateway. It never downloads media, reads memory, or
/// drives a model. Those operations belong to the injected host/session.
class QqGateway {
  QqGateway(this.api, {required this.onMessage, required this.onStatus});
  final QqApi api;
  final Future<void> Function(Map<String, dynamic>) onMessage;
  final void Function(String) onStatus;
  WebSocket? _socket;
  Timer? _heartbeat;
  bool _stopped = false;
  String? _session;
  int? _sequence;
  bool _awaitingHeartbeat = false;
  final _stopSignal = Completer<void>();
  Future<void> _events = Future.value();

  Future<void> run() async {
    var failures = 0;
    while (!_stopped) {
      WebSocket? socket;
      try {
        onStatus('connecting');
        final token = await api.token();
        final url = await api.gatewayUrl();
        if (_stopped) break;
        socket = await WebSocket.connect(url).timeout(const Duration(seconds: 20));
        if (_stopped) { await socket.close(); break; }
        _socket = socket;
        final owned = socket;
        var ready = false;
        final handshake = Timer(const Duration(seconds: 25), () { if (!ready) unawaited(owned.close()); });
        try {
          await for (final frame in socket) {
            if (_stopped || !identical(_socket, owned)) break;
            final raw = frame is String ? frame : utf8.decode(frame as List<int>);
            if (raw.length > 256 * 1024) { await owned.close(); break; }
            final payload = jsonDecode(raw) as Map<String, dynamic>;
            switch (payload['op']) {
              case 10:
                final d = payload['d'] as Map;
                final interval = (d['heartbeat_interval'] as num).toInt();
                if (interval < 1000 || interval > 120000) throw QqApiException('heartbeat_invalid');
                owned.add(jsonEncode(_session != null && _sequence != null
                  ? {'op': 6, 'd': {'token': 'QQBot $token', 'session_id': _session, 'seq': _sequence}}
                  : {'op': 2, 'd': {'token': 'QQBot $token', 'intents': 1 << 25, 'shard': [0, 1]}}));
                _heartbeat?.cancel();
                _awaitingHeartbeat = false;
                _heartbeat = Timer.periodic(Duration(milliseconds: interval), (_) {
                  if (!identical(_socket, owned) || _stopped) return;
                  if (_awaitingHeartbeat) { unawaited(owned.close()); return; }
                  _awaitingHeartbeat = true;
                  owned.add(jsonEncode({'op': 1, 'd': _sequence}));
                });
                break;
              case 11: _awaitingHeartbeat = false; break;
              case 7: await owned.close(); break;
              case 9:
                _session = null; _sequence = null; api.invalidateToken();
                await owned.close();
                break;
              case 0:
                final type = payload['t'];
                final d = payload['d'];
                if (type == 'READY' && d is Map) {
                  _session = d['session_id'] as String?;
                  ready = true; failures = 0; onStatus('online');
                } else if (type == 'RESUMED') {
                  ready = true; failures = 0; onStatus('online');
                } else if (type == 'C2C_MESSAGE_CREATE' && d is Map<String, dynamic>) {
                  // Serial acceptance before advancing the replay cursor. The
                  // handler only durably queues: model generation never blocks
                  // heartbeats or reception of later QQ messages.
                  _events = _events.then((_) => onMessage(d));
                  await _events;
                }
                if (payload['s'] is num) _sequence = (payload['s'] as num).toInt();
                break;
            }
          }
        } finally { handshake.cancel(); }
        final close = socket.closeCode;
        if (close == 4007 || close == 4009) { _session = null; _sequence = null; }
        if (close == 4004) { _session = null; _sequence = null; api.invalidateToken(); }
        if (const {4010, 4011, 4012, 4013, 4014, 4914, 4915}.contains(close)) {
          onStatus('permission_error'); return;
        }
      } catch (error) {
        // Do not expose tokens, user content or provider response bodies.
        _events = Future.value();
        if (error is QqApiException && const {'http_400', 'http_401', 'http_403'}.contains(error.code)) {
          onStatus('credentials_error'); return;
        }
        if (!_stopped) onStatus('reconnecting');
      } finally {
        _heartbeat?.cancel();
        if (identical(_socket, socket)) _socket = null;
        await socket?.close();
      }
      if (!_stopped) {
        failures = (failures + 1).clamp(1, 6).toInt();
        onStatus('reconnecting');
        await Future.any([Future<void>.delayed(Duration(seconds: 1 << failures)), _stopSignal.future]);
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    if (!_stopSignal.isCompleted) _stopSignal.complete();
    _heartbeat?.cancel(); api.close(); await _socket?.close();
  }
}
