import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local only; deliberately outside the main API/backup allowlists.
class QqPrivateConfig {
  const QqPrivateConfig({this.appId = '', this.secret = '', this.owner = '',
    this.pairCode = '', this.pairUntil = 0, this.namespace = '', this.replyChannel = ''});
  final String appId, secret, owner, pairCode, namespace, replyChannel;
  final int pairUntil;
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static const _key = 'qq_private_config_v1';

  static String randomId([int length = 24]) {
    final random = Random.secure();
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<QqPrivateConfig> read() async {
    final text = await _storage.read(key: _key);
    if (text == null) return const QqPrivateConfig();
    final raw = jsonDecode(text) as Map;
    final namespace = raw['namespace'] as String? ?? '';
    return QqPrivateConfig(appId: raw['appId'] as String? ?? '', secret: raw['secret'] as String? ?? '',
      owner: namespace.isEmpty ? '' : await _storage.read(key: 'qq_private_owner_$namespace') ?? '',
      pairCode: raw['pairCode'] as String? ?? '',
      pairUntil: raw['pairUntil'] as int? ?? 0, namespace: namespace,
      replyChannel: const {'first','second'}.contains(raw['replyChannel']) ? raw['replyChannel'] as String : '');
  }

  Future<void> save() => _storage.write(key: _key, value: jsonEncode({
    'appId': appId, 'secret': secret, 'pairCode': pairCode,
    'pairUntil': pairUntil, 'namespace': namespace, 'replyChannel': replyChannel}));

  QqPrivateConfig withReplyChannel(String value) {
    if (!const {'first','second'}.contains(value)) throw ArgumentError.value(value);
    return QqPrivateConfig(appId: appId, secret: secret, owner: owner,
      pairCode: pairCode, pairUntil: pairUntil, namespace: namespace, replyChannel: value);
  }

  /// A late binding callback can only write the namespace it owns. It must
  /// never overwrite newly saved credentials or a replacement binding.
  static Future<void> bind(String namespace, String user) =>
    _storage.write(key: 'qq_private_owner_$namespace', value: user);
}
