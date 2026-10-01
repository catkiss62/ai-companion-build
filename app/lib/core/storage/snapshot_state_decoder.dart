import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// Hashing, UTF-8 and JSON decoding all run outside the UI isolate. Returning
/// the map with Isolate.run transfers ownership rather than retaining both a
/// large byte/string payload and another decoded copy on the UI isolate.
Future<({Map<String, dynamic> state, String hash, int bytes})> decodeSnapshotState(
  String path, {
  required String expectedHash,
  required int maxBytes,
  int? declaredBytes,
}) => Isolate.run(() {
  final file = File(path);
  final size = file.lengthSync();
  if (size <= 0 || size > maxBytes) throw const FormatException('状态包大小超出限制');
  final bytes = file.readAsBytesSync();
  if (declaredBytes != null && declaredBytes != bytes.length) {
    throw const FormatException('状态包声明大小与实际内容不一致');
  }
  final hash = sha256.convert(bytes).toString();
  if (hash != expectedHash) throw const FormatException('状态包 SHA-256 校验失败');
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) throw const FormatException('state.json 格式不正确');
  return (state: Map<String, dynamic>.from(decoded), hash: hash, bytes: bytes.length);
});
