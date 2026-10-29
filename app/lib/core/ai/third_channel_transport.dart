import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'third_channel_config.dart';

/// One pool per Flutter engine, used only by the third channel. Request bodies,
/// accounting callbacks and cancellation never belong to this shared object.
class ThirdChannelTransportPool {
  ThirdChannelTransportPool({http.Client Function()? clientFactory})
      : _factory = clientFactory ?? (() => IOClient(HttpClient()
          ..idleTimeout = const Duration(seconds: 90)));
  static final shared = ThirdChannelTransportPool();
  final http.Client Function() _factory;
  final Map<String, _TransportEntry> _entries = {};
  bool _closed = false;

  ThirdChannelTransportLease acquire(ThirdChannelConfig config) {
    if (_closed) throw StateError('third_transport_closed');
    final key = sha256.convert(utf8.encode(config.encode())).toString();
    // Configuration changes retire old transports without interrupting their
    // in-flight requests. Their own source/config guards revoke authority.
    for (final entry in _entries.values.toList()) {
      if (entry.key != key) { entry.retired = true; _collect(entry); }
    }
    final entry = _entries.putIfAbsent(key, () => _TransportEntry(key, _factory()));
    entry.retired = false;
    final reused = entry.uses++ > 0;
    entry.references++;
    return ThirdChannelTransportLease(entry.client, reused, () {
      entry.references--;
      _collect(entry);
    });
  }

  void _collect(_TransportEntry entry) {
    if (entry.retired && entry.references == 0) {
      if (identical(_entries[entry.key], entry)) _entries.remove(entry.key);
      entry.client.close();
    }
  }
  void close() {
    _closed = true;
    for (final entry in _entries.values) { entry.client.close(); }
    _entries.clear();
  }
}

class ThirdChannelTransportLease {
  ThirdChannelTransportLease(this.client, this.reused, this._release);
  final http.Client client;
  final bool reused;
  final void Function() _release;
  bool _released = false;
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
}
