import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import 'illustration_prompt.dart';

class IllustrationConnection {
  const IllustrationConnection({
    this.baseUrl = '',
    this.apiKey = '',
    this.enabled = false,
    this.autonomous = false,
    this.diary = false,
  });

  final String baseUrl;
  final String apiKey;
  final bool enabled;
  final bool autonomous;
  final bool diary;

  bool get configured => apiKey.trim().isNotEmpty && endpoint != null;
  bool get active => enabled && configured;

  Uri? get endpoint {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment)
      return null;
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(
      path: path.endsWith('/ai/generate-image')
          ? path
          : '$path/ai/generate-image',
    );
  }

  String encode() => jsonEncode({
    'url': baseUrl,
    'key': apiKey,
    'enabled': enabled,
    'autonomous': autonomous,
    'diary': diary,
  });

  factory IllustrationConnection.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const IllustrationConnection();
    try {
      final value = jsonDecode(raw);
      if (value is Map) {
        return IllustrationConnection(
          baseUrl: value['url'] is String ? value['url'] as String : '',
          apiKey: value['key'] is String ? value['key'] as String : '',
          enabled: value['enabled'] == true,
          autonomous: value['autonomous'] == true,
          diary: value['diary'] == true,
        );
      }
    } on FormatException {
      // A missing or old local profile leaves the optional capability off.
    }
    return const IllustrationConnection();
  }
}

class IllustrationFailure implements Exception {
  const IllustrationFailure(this.code);
  final String code;

  int? get httpStatus =>
      code.startsWith('http_') ? int.tryParse(code.substring(5)) : null;

  String get label => switch (code) {
    'configuration' => '请在「能力 → 生图」检查服务地址和密钥',
    'disabled' => '生图已关闭',
    'authorization' => '生图服务鉴权失败，请检查密钥',
    'quota' => '生图服务额度不足或触发限流',
    'timeout' => '生图服务超时',
    'invalid_image' => '生图服务未返回可用图片',
    'planning' => '这次没有生成可用的绘图方案',
    'storage' => '图片已返回，但本地保存失败',
    'storage_unavailable' => '本地图片存储不可用',
    'restore' => '备份中这次配图尚未完成',
    _ when httpStatus != null => '生图服务返回 HTTP $httpStatus',
    _ => '生图服务连接失败，请检查 API',
  };
}

class IllustrationBytes {
  const IllustrationBytes(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class IllustrationClient {
  IllustrationClient({
    http.Client Function()? clientFactory,
    this.requestTimeout = defaultRequestTimeout,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  final Duration requestTimeout;
  static const defaultRequestTimeout = Duration(minutes: 2);
  static const model = 'nai-diffusion-4-5-full';
  static const maxBytes = 25 * 1024 * 1024;

  Future<IllustrationBytes> generate(
    IllustrationConnection connection,
    IllustrationPrompt prompt, {
    required int seed,
  }) async {
    final endpoint = connection.endpoint;
    if (endpoint == null || connection.apiKey.trim().isEmpty) {
      throw const IllustrationFailure('configuration');
    }
    final client = _clientFactory();
    try {
      return await _request(
        client,
        endpoint,
        connection.apiKey.trim(),
        prompt,
        seed,
      ).timeout(requestTimeout);
    } on TimeoutException {
      throw const IllustrationFailure('timeout');
    } on IllustrationFailure {
      rethrow;
    } catch (_) {
      throw const IllustrationFailure('network');
    } finally {
      client.close();
    }
  }

  static int newSeed() => Random.secure().nextInt(2147483646) + 1;

  Future<IllustrationBytes> _request(
    http.Client client,
    Uri uri,
    String key,
    IllustrationPrompt prompt,
    int seed,
  ) async {
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'input': prompt.positive,
        'model': model,
        'action': 'generate',
        'parameters': {
          'width': 832,
          'height': 1216,
          'steps': 23,
          'scale': 5,
          'sampler': 'k_euler_ancestral',
          'noise_schedule': 'karras',
          'n_samples': 1,
          'seed': seed,
          'negative_prompt': prompt.negative,
        },
      });
    final response = await client.send(request);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const IllustrationFailure('authorization');
    }
    if (response.statusCode == 402 || response.statusCode == 429) {
      throw const IllustrationFailure('quota');
    }
    if (response.statusCode != 200) {
      throw IllustrationFailure('http_${response.statusCode}');
    }
    final result = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (result.length + chunk.length > maxBytes) {
        throw const IllustrationFailure('invalid_image');
      }
      result.add(chunk);
    }
    final bytes = result.takeBytes();
    final direct = imageType(bytes);
    if (direct != null) return IllustrationBytes(bytes, direct);
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (!file.isFile ||
            file.size <= 0 ||
            file.size > maxBytes ||
            !RegExp(
              r'\.(png|jpe?g|webp)$',
              caseSensitive: false,
            ).hasMatch(file.name))
          continue;
        final data = file.content;
        final mime = imageType(data);
        if (mime != null && data.length <= maxBytes)
          return IllustrationBytes(data, mime);
      }
    } catch (_) {
      throw const IllustrationFailure('invalid_image');
    }
    throw const IllustrationFailure('invalid_image');
  }

  static String? imageType(Uint8List bytes) {
    if (bytes.length >= 24 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10)
      return 'image/png';
    if (bytes.length >= 4 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP')
      return 'image/webp';
    return null;
  }
}
