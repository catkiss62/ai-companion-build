import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../ai/qwen_vision_client.dart';
import '../ai/routed_vision_client.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';

/// Durable reservation before a paid effect; interrupted reviews never replay.
abstract final class CreativeVisualBudget {
  static Map<String,Object?>? prior(Map agent,String requestId) {
    final row=agent['visual_review'];
    return row is Map && row['request_id']==requestId?Map<String,Object?>.from(row):null;
  }
  static Map<String,Object?> reserve(String requestId,String hash)=>{
    'request_id':requestId,'hash':hash,'status':'reserved'};
  static Map<String,Object?> feedback(Map row)=>{
    'ok':true,'visual_review':row['status']=='reserved'?'interrupted_no_retry':row['status'],
    'reviewed_hash':row['hash'],'advice':row['advice']??'',
    'note':'本委托最多一次视觉复审；意见不代替功能/存档验证，源码变更后旧图不能冒充新版本验收。'};
  static Uint8List pixels(Map verification,String hash) {
    if(verification['ok']!=true || verification['hash']!=hash)throw const FormatException('先成功预览当前源码，再按返回hash请求视觉复审');
    final raw=verification['cover'];
    if(raw is! String || raw.isEmpty || raw.length>240000)throw const FormatException('当前预览没有可用截图，不生成或猜测图片');
    final bytes=base64Decode(raw);
    if(bytes.length>180000 || bytes.length<24 || bytes[0]!=137 || bytes[1]!=80 || bytes[2]!=78 || bytes[3]!=71)
      throw const FormatException('预览截图格式不受支持');
    final header=ByteData.sublistView(bytes);
    final w=header.getUint32(16),h=header.getUint32(20);
    if(w<1 || h<1 || w>2048 || h>4096 || w*h>4194304)throw const FormatException('预览截图尺寸不受支持');
    return bytes;
  }
}

class CreativeVisualReview {
  CreativeVisualReview({QwenVisionClient Function(AppDatabase,Future<bool> Function())? factory,
    Future<bool> Function(AppDatabase)? configured})
    : factory=factory??((db,current)=>RoutedVisionClient(db:db,current:current)),
      configured=configured??((db)=>RoutedVisionClient.configured(SecureConfig.instance,db:db));
  final QwenVisionClient Function(AppDatabase,Future<bool> Function()) factory;
  final Future<bool> Function(AppDatabase) configured;
  Future<String> review(AppDatabase db,Uint8List bytes,String brief,Future<bool> Function() current) async {
    if(!await current())throw const FormatException('review_source_lost');
    if(!await configured(db))throw const FormatException('review_unconfigured');
    if(!await current())throw const FormatException('review_source_lost');
    final vision=factory(db,current);
    try {
      final result=await vision.reviewWorkBytes(apiKey:'',endpoint:QwenVisionClient.defaultEndpoint,
        model:QwenVisionClient.defaultModel,imageBytes:bytes,
        brief:brief.length>400?brief.substring(0,400):brief).timeout(const Duration(seconds:45));
      if(!await current())throw const FormatException('review_source_lost');
      final advice=result.summary.trim();
      if(advice.isEmpty)throw const FormatException('review_empty');
      return advice.length>900?advice.substring(0,900):advice;
    } finally {vision.close();}
  }
}
