import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local only; deliberately outside the main API/backup allowlists.
class QqPrivateConfig {
  const QqPrivateConfig({this.appId = '', this.secret = '', this.owner = '',
    this.pairCode = '', this.pairUntil = 0, this.namespace = ''});
  final String appId, secret, owner, pairCode, namespace;
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
    return QqPrivateConfig(appId: raw['appId'] as String? ?? '', secret: raw['secret'] as String? ?? '',
      owner: raw['owner'] as String? ?? '', pairCode: raw['pairCode'] as String? ?? '',
      pairUntil: raw['pairUntil'] as int? ?? 0, namespace: raw['namespace'] as String? ?? '');
  }

  Future<void> save() => _storage.write(key: _key, value: jsonEncode({
    'appId': appId, 'secret': secret, 'owner': owner, 'pairCode': pairCode,
    'pairUntil': pairUntil, 'namespace': namespace}));

  QqPrivateConfig paired(String user) => QqPrivateConfig(appId: appId, secret: secret,
    owner: user, namespace: namespace);
}
