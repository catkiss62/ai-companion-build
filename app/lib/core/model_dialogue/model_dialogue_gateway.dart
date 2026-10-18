import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../ai/chat_api_provider.dart';
import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';
import 'model_dialogue_models.dart';

class ModelDialogueEndpoint {
  const ModelDialogueEndpoint({required this.speaker,required this.endpoint,
    required this.model,required this.apiKey,this.effort=ReasoningEffort.high});
  final String speaker,endpoint,model,apiKey;
  final ReasoningEffort effort;
  ChatApiProvider get provider => speaker=='deepseek'?ChatApiProvider.deepSeek:ChatApiProvider.aiWangYouGemini;
  String get fingerprint => sha256.convert(utf8.encode('${provider.storageValue}\n$endpoint\n$model')).toString();
  Map<String,Object?> get snapshot => {'model':model,'endpoint_hash':fingerprint};
  void validate() {
    final uri=Uri.tryParse(endpoint);
    if(apiKey.trim().isEmpty)throw ModelDialogueConfigurationError('${modelDialogueLabel(speaker)} API Key 尚未配置');
    if(uri==null||!const {'http','https'}.contains(uri.scheme)||uri.host.isEmpty||uri.userInfo.isNotEmpty) {
      throw ModelDialogueConfigurationError('${modelDialogueLabel(speaker)} 接口地址无效');
    }
    if(!model.toLowerCase().contains(speaker)) {
      throw ModelDialogueConfigurationError('${modelDialogueLabel(speaker)} 一侧必须配置对应模型，当前为 $model');
    }
  }
  bool matches(ModelDialogueRoom room) => room.modelName(speaker)==model &&
      room.participant(speaker)['endpoint_hash']==fingerprint;
}
class ModelDialogueConfiguration {
  const ModelDialogueConfiguration(this.deepSeek,this.gemini,{this.secondChannelEnabled=true});
  final bool secondChannelEnabled;
  void validateForCreation() {
    if (!secondChannelEnabled) throw const ModelDialogueConfigurationError('请先在模型设置中开启双通道，再创建模型对谈房间。');
    validate();
  }
  final ModelDialogueEndpoint deepSeek,gemini;
  ModelDialogueEndpoint forSpeaker(String speaker) => speaker=='deepseek'?deepSeek:gemini;
  void validate() {
    if(deepSeek.speaker!='deepseek'||gemini.speaker!='gemini')throw const ModelDialogueConfigurationError('两方模型身份配置无效');
    deepSeek.validate();gemini.validate();
  }
  Map<String,Object?> get snapshot => {'deepseek':deepSeek.snapshot,'gemini':gemini.snapshot};
  static Future<ModelDialogueConfiguration> load(AppDatabase db,{SecureConfig? secureConfig}) async {
    final secure=secureConfig??SecureConfig.instance;
    final effort=ReasoningEffort.fromApiName(await db.getSetting('reasoning_effort'));
    return ModelDialogueConfiguration(
      ModelDialogueEndpoint(speaker:'deepseek',endpoint:await secure.readDeepSeekEndpoint(),
        model:DeepSeekModelProfile.fromApiName(await db.getSetting('model')).apiName,
        apiKey:(await secure.readDeepSeekApiKey())??'',effort:effort),
      ModelDialogueEndpoint(speaker:'gemini',endpoint:await secure.readAiWangYouEndpoint(),
        model:await secure.readAiWangYouModel(),apiKey:(await secure.readAiWangYouApiKey())??'',effort:effort),
      secondChannelEnabled:(await secure.readChatProvider()).isGeminiRelay);
  }
}
class ModelDialogueConfigurationError implements Exception {
  const ModelDialogueConfigurationError(this.message);
  final String message;
  @override String toString()=>message;
}
class ModelDialogueRequestFailure implements Exception {
  const ModelDialogueRequestFailure(this.speaker,this.category);
  final String speaker,category;
  @override String toString()=>'${modelDialogueLabel(speaker)} 两次请求均失败（$category）。可检查配置后重试。';
}

/// A fixed endpoint/model/key snapshot is reused for both HTTP attempts. This
/// gateway has no FinalReplyRoute, fallback client or cross-provider branch.
class ModelDialogueGateway {
  ModelDialogueGateway(this.client,{this.retryDelay=const Duration(milliseconds:650)});
  final DeepSeekClient client;
  final Duration retryDelay;
  Future<ModelDialogueOutput> generate({required ModelDialogueEndpoint endpoint,
    required List<Map<String,Object?>> messages,required GenerationCancellationToken cancellation,
    required String requestId,required void Function(String) onPreview,
    required void Function(int) onAttempt}) async {
    endpoint.validate();
    Object? lastError;
    for(var attempt=1;attempt<=2;attempt++) {
      cancellation.throwIfCancelled();onAttempt(attempt);onPreview('');
      final body=StringBuffer();var terminal=false;var finish='';
      try {
        await for(final delta in client.streamChat(apiKey:endpoint.apiKey,
          endpoint:endpoint.endpoint,requestProvider:endpoint.provider,modelName:endpoint.model,
          model:DeepSeekModelProfile.fromApiName(endpoint.model),effort:endpoint.effort,
          messages:messages,cancellationToken:cancellation,usageLane:'model_dialogue_${endpoint.speaker}',
          usageExecutionId:requestId)) {
          cancellation.throwIfCancelled();
          if(delta.content.isNotEmpty){body.write(delta.content);if(body.length>200000)throw const FormatException('oversized_response');onPreview(ModelDialogueOutput.preview(body.toString()));}
          if(delta.toolCallDeltas.isNotEmpty)throw const FormatException('unexpected_tool_call');
          if(delta.finishReason!=null)finish=delta.finishReason!.toLowerCase();
          if(delta.done||delta.finishReason!=null)terminal=true;
        }
        cancellation.throwIfCancelled();
        if(!terminal||!const {'','stop'}.contains(finish))throw const FormatException('stream_incomplete');
        return ModelDialogueOutput.parse(body.toString());
      } on GenerationCancelledByUserException {rethrow;}
        on GenerationSuspendedByRuntimeGateException {rethrow;}
        catch(error){lastError=error;}
      if(attempt<2)await cancelWithToken(Future<void>.delayed(retryDelay),cancellation);
    }
    final category=lastError is DeepSeekException?'HTTP ${lastError.statusCode}':
      lastError is TimeoutException?'请求超时':lastError is FormatException?'响应不完整或格式错误':'连接或接口异常';
    onPreview('');throw ModelDialogueRequestFailure(endpoint.speaker,category);
  }
  void close()=>client.close();
}
