import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'third_channel_config.dart';

/// One pool per Flutter engine, used only by the third channel. Request bodies,
/// accounting callbacks and cancellation never belong to this shared object.
class ThirdChannelTransportPool {
  ThirdChannelTransportPool({http.Client Function()? clientFactory,
      Future<String> Function()? networkIdentity, Duration Function()? elapsed})
      : _factory = clientFactory ?? (() => IOClient(HttpClient()
          ..idleTimeout = const Duration(seconds: 90))),
        _networkIdentity = networkIdentity ?? (clientFactory == null ? _readNetworkIdentity : (() async => 'test')),
        _elapsedOverride = elapsed;
  static final shared = ThirdChannelTransportPool();
  final http.Client Function() _factory;
  final Future<String> Function() _networkIdentity;
  final Duration Function()? _elapsedOverride;
  final Stopwatch _clock = Stopwatch()..start();
  static const healthTtl = Duration(seconds: 60);
  Duration _elapsed() => _elapsedOverride?.call() ?? _clock.elapsed;
  final Map<String, _TransportEntry> _entries = {};
  final Set<_TransportEntry> _all = {};
  int _unknownNetwork = 0;
  bool _closed = false;

  Future<ThirdChannelTransportLease> acquire(ThirdChannelConfig config) async {
    if (_closed) throw StateError('third_transport_closed');
    String network;
    try {network = await _networkIdentity();}
    catch (_) {network = 'unknown:${++_unknownNetwork}';}
    if (_closed) throw StateError('third_transport_closed');
    // Enablement and effort belong to each request's authority/body, not its
    // socket. A short test and saved reply may share only endpoint/auth/network.
    final key = sha256.convert(utf8.encode(jsonEncode([
      config.endpoint.toString(), config.apiKey.trim(), network]))).toString();
    // Configuration changes retire old transports without interrupting their
    // in-flight requests. Their own source/config guards revoke authority.
    for (final entry in _entries.values.toList()) {
      if (entry.key != key) _retire(entry);
    }
    final entry = _entries.putIfAbsent(key, () {
      final created = _TransportEntry(key, _factory()); _all.add(created); return created;
    });
    final reused = entry.uses++ > 0;
    entry.references++;
    return ThirdChannelTransportLease._(entry, reused, _elapsed, () => _retire(entry), () {
      entry.references--;
      _collect(entry);
    });
  }

  // No traffic or DNS lookup. Addresses are hashed in memory and never emitted
  // into diagnostics. Observable Wi-Fi/mobile/VPN changes retire idle sockets.
  static Future<String> _readNetworkIdentity() async {
    final interfaces = await NetworkInterface.list(includeLinkLocal: true);
    final values = [for (final interface in interfaces)
      for (final address in interface.addresses) '${interface.name}:${address.type}:${address.address}']..sort();
    if (values.isEmpty) throw StateError('network_unknown');
    return sha256.convert(utf8.encode(values.join('\n'))).toString();
  }
  void _retire(_TransportEntry entry) {
    entry.retired = true;
    entry.healthyAt = null;
    if (identical(_entries[entry.key], entry)) _entries.remove(entry.key);
    _collect(entry);
  }

  void _collect(_TransportEntry entry) {
    if (entry.retired && entry.references == 0) {
      if (_all.remove(entry)) entry.client.close();
    }
  }
  void close() {
    _closed = true;
    for (final entry in _all) { entry.client.close(); }
    _entries.clear(); _all.clear();
  }
}

class ThirdChannelTransportLease {
  ThirdChannelTransportLease._(this._entry, this.reused, this._elapsed, this._invalidate, this._release);
  final _TransportEntry _entry;
  final Duration Function() _elapsed;
  http.Client get client => _entry.client;
  final bool reused;
  final void Function() _invalidate;
  final void Function() _release;
  bool _released = false;
  bool get recentHealth {
    final at = _entry.healthyAt;
    if (_released || _entry.retired || at == null) return false;
    final age = _elapsed() - at;
    return !age.isNegative && age < ThirdChannelTransportPool.healthTtl;
  }
  void markHealthy() {
    if (!_released && !_entry.retired) _entry.healthyAt = _elapsed();
  }
  void invalidate() { if (!_released) _invalidate(); }
  void release() {
    if (!_released) { _released = true; _release(); }
  }
}

class _TransportEntry {
  _TransportEntry(this.key, this.client);
  final String key;
  final http.Client client;
  int uses = 0, references = 0;
  bool retired = false;
  Duration? healthyAt;
}
