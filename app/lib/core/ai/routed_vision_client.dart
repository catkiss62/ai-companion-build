import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../database/app_database.dart';
import '../diagnostics/model_usage_telemetry.dart';
import '../storage/secure_config.dart';
import 'deepseek_client.dart';
import 'first_channel_model.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';
import 'qwen_vision_client.dart';
import 'third_channel_client.dart';
import 'third_channel_config.dart';

/// Retains the canonical pixel input, observation parser and content hash.
/// The transport changes only the provider, never the image or business fields.
class RoutedVisionClient extends QwenVisionClient {
  factory RoutedVisionClient({SecureConfig? secure, AppDatabase? db, bool qq = false,
    Future<DeepSeekModelProfile> Function()? firstModel,
    http.Client Function()? clientFactory, ThirdChannelClient Function()? thirdFactory,
    Future<bool> Function()? current}) => RoutedVisionClient._(VisionRoutingTransport(
      secure: secure ?? SecureConfig.instance, db: db ?? (qq ? null : AppDatabase.instance),
      qq: qq, firstModel: firstModel, clientFactory: clientFactory,
      thirdFactory: thirdFactory, current: current));
  RoutedVisionClient._(this.routing) : super(client: routing, requiresApiKey: false);
  final VisionRoutingTransport routing;
  set sourceGuard(Future<bool> Function()? guard) => routing.current = guard;
  static const qwenEnabledKey = 'app_qwen_vision_enabled_v1';
  static Future<bool> configured(SecureConfig secure, {AppDatabase? db, bool qq = false}) async {
    ThirdChannelConfig third;
    try { third = await secure.readThirdChannel(); } catch (_) { third = const ThirdChannelConfig(); }
    if (third.enabled && third.configured) return true;
    if ((await secure.readApiKey())?.trim().isNotEmpty == true) return true;
    return !qq && await (db ?? AppDatabase.instance).getSetting(qwenEnabledKey) != '0' &&
      (await secure.readVisionApiKey())?.trim().isNotEmpty == true;
  }
}

class VisionRoutingTransport extends http.BaseClient {
  VisionRoutingTransport({required this.secure, this.db, required this.qq,
    this.firstModel, http.Client Function()? clientFactory, this.thirdFactory, this.current})
    : clientFactory = clientFactory ?? http.Client.new;
  final SecureConfig secure;
  final AppDatabase? db;
  final bool qq;
  final Future<DeepSeekModelProfile> Function()? firstModel;
  final http.Client Function() clientFactory;
  final ThirdChannelClient Function()? thirdFactory;
  Future<bool> Function()? current;
  final Set<http.Client> _active = {};
  final Set<ThirdChannelClient> _third = {};
  bool _closed = false;
  Future<bool> _valid() async => !_closed && (current == null || await current!()) &&
      (db == null || await db!.brainWorkAllowed());
  Future<void> _check() async {
    if (!await _valid()) throw const GenerationSuspendedByRuntimeGateException();
  }

  @override Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _check();
    final ownerGuard = current;
    final fence = await db?.captureBrainWorkFence();
    var sourceLost = false;
    Future<bool> sourceCurrent() async {
      if (sourceLost) return false;
      var valid = false;
      try {
        valid = !_closed && (ownerGuard == null || await ownerGuard()) &&
          (db == null || fence != null && await db!.brainWorkFenceCurrent(fence));
      } catch (_) { /* Failure to verify ownership is not provider failure. */ }
      if (!valid) sourceLost = true;
      return valid;
    }
    Future<void> checkSource() async {
      if (!await sourceCurrent()) throw const GenerationSuspendedByRuntimeGateException();
    }
    await checkSource();
    if (request is! http.Request) throw const FormatException('vision_request_shape');
    final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
    ThirdChannelConfig config;
    try { config = await secure.readThirdChannel(); } catch (_) { config = const ThirdChannelConfig(); }
    if (config.enabled) {
      final third = thirdFactory?.call() ?? ThirdChannelClient(onUsage: (usage, attempt, elapsed) async {
        if (db == null) return;
        await ModelUsageTelemetry.record(db!, DeepSeekUsageEvent(lane: qq ? 'qq_vision' : 'app_vision',
          executionId: '', inputTokens: usage.input, outputTokens: usage.output, reasoningTokens: usage.reasoning,
          cacheHitTokens: 0, cacheMissTokens: 0, streaming: false, provider: 'third_channel',
          modelHash: sha256.convert(utf8.encode(ThirdChannelConfig.model)).toString(),
          endpointHash: sha256.convert(utf8.encode(config.endpoint.toString())).toString(), usageLatencyMs: elapsed,
          promptShape: const DeepSeekPromptShape(messages: [], toolCount: 0, toolCharacters: 0, toolHash: '')));
      });
      _third.add(third);
      try {
        final messages = (body['messages'] as List).map((m) => Map<String, Object?>.from(m as Map)).toList();
        messages.add({'role': 'system', 'content': '必须遵守输出schema，所有观察与判断针对本次唯一图片。'
          '未要求收藏评估时album.save=false，其余album字段填中性默认值；未提供找图目标时request_match.matches=true、confidence=1。'});
        final result = await third.complete(config: config, messages: messages, stream: false,
          maxTokens: 4096, responseFormat: {'type': 'json_schema', 'json_schema': {
            'name': 'image_observation', 'strict': true, 'schema': observationSchema}},
          current: () async => await sourceCurrent() && (await secure.readThirdChannel()).encode() == config.encode());
        await checkSource();
        _validate(jsonEncode(result.completion()));
        return _response(jsonEncode({...result.completion(), '_client_provider': 'third_channel'}), 200);
      } on GenerationCancelledByUserException { rethrow; }
      on GenerationSuspendedByRuntimeGateException { rethrow; }
      catch (_) { await checkSource(); }
      finally { _third.remove(third); third.close(); }
    }
    final useQwen = !qq && await (db ?? AppDatabase.instance).getSetting(RoutedVisionClient.qwenEnabledKey) != '0';
    if (useQwen) {
      try { return await _legacy(body, first: false, sourceCurrent: sourceCurrent); }
      on GenerationSuspendedByRuntimeGateException { rethrow; }
      on GenerationCancelledByUserException { rethrow; }
      catch (_) { await checkSource(); }
    }
    return _legacy(body, first: true, sourceCurrent: sourceCurrent);
  }

  Future<http.StreamedResponse> _legacy(Map<String, Object?> original,
      {required bool first, required Future<bool> Function() sourceCurrent}) async {
    Future<void> check() async {
      if (!await sourceCurrent()) throw const GenerationSuspendedByRuntimeGateException();
    }
    await check();
    final key = first ? await secure.readApiKey() : await secure.readVisionApiKey();
    if (key == null || key.trim().isEmpty) throw const QwenVisionException(0, '未配置可用的图片识别接口');
    final endpoint = first ? await secure.readEndpoint() : await secure.readVisionEndpoint();
    final model = first ? (await (firstModel?.call() ?? FirstChannelModel.read(db ?? AppDatabase.instance))).apiName
      : await secure.readVisionModel();
    final body = {...original, 'model': model, if (first) 'thinking': {'type': 'disabled'}};
    final client = clientFactory(); _active.add(client);
    var checking = false, invalid = false;
    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (checking) return; checking = true;
      try { if (!await sourceCurrent()) { invalid = true; client.close(); } } finally { checking = false; }
    });
    try {
      await check();
      final response = await client.post(Uri.parse(endpoint), headers: {
        'Content-Type': 'application/json', 'Authorization': 'Bearer ${key.trim()}'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
      await check();
      if (invalid) throw const GenerationSuspendedByRuntimeGateException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (first) return _response(response.body, response.statusCode);
        throw QwenVisionException(response.statusCode, 'vision_provider_failed');
      }
      _validate(response.body);
      return _response(jsonEncode({...Map<String, Object?>.from(jsonDecode(response.body) as Map),
        '_client_provider': first ? 'deepseek' : 'qwen_vision'}), response.statusCode);
    } catch (_) { await check(); rethrow; }
    finally { timer.cancel(); _active.remove(client); client.close(); }
  }

  static void _validate(String body) {
    final root = jsonDecode(body) as Map;
    if (root['error'] != null) throw const FormatException('vision_error');
    final choice = (root['choices'] as List).first as Map;
    final finish = choice['finish_reason'];
    if (finish != null && finish != '' && finish != 'stop') throw const FormatException('vision_incomplete');
    var content = ((choice['message'] as Map)['content'] as String).trim();
    if (content.startsWith('```')) content = content.replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
    final parsed = jsonDecode(content);
    if (parsed is! Map || parsed['summary'] is! String || (parsed['summary'] as String).trim().isEmpty) {
      throw const FormatException('vision_summary_missing');
    }
  }
  static http.StreamedResponse _response(String body, int status) => http.StreamedResponse(
    Stream.value(utf8.encode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});
  static Map<String, Object?> _object(Map<String, Object?> properties) => {
    'type': 'object', 'properties': properties, 'required': properties.keys.toList(), 'additionalProperties': false};
  static final observationSchema = _object({
    'summary': {'type': 'string'},
    'album': _object({'save': {'type': 'boolean'}, 'category': {'type': 'string'},
      'tags': {'type': 'array', 'items': {'type': 'string'}}, 'reason': {'type': 'string'},
      'aesthetic_tags': {'type': 'array', 'items': {'type': 'string'}}, 'confidence': {'type': 'number'}, 'adult_content': {'type': 'boolean'}}),
    'request_match': _object({'matches': {'type': 'boolean'}, 'confidence': {'type': 'number'}, 'reason': {'type': 'string'}}),
  });
  @override void close() {
    _closed = true;
    for (final client in _active.toList()) { client.close(); }
    for (final client in _third.toList()) { client.close(); }
  }
}
