import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// No credentials, response bodies or remote text in user-visible errors.
class QqApiException implements Exception {
  QqApiException(this.code, {this.uncertain = false});
  final String code;
  final bool uncertain;
  @override
  String toString() => 'QQ: $code';
}

class QqMediaUpload {
  const QqMediaUpload(this.fileInfo,{this.ttl});
  final String fileInfo;
  final int? ttl;
  int reusableUntil(int now) => ttl!=null && ttl!>60 ? now+(ttl!-60)*1000 : now;
}

class QqApi {
  QqApi({required this.appId, required this.secret, HttpClient? client,
    this.apiBase = 'https://api.bot.qq.com',
    this.tokenBase = 'https://bots.qq.com'}): _client = client ?? HttpClient();
  final String appId;
  final String secret;
  final String apiBase;
  final String tokenBase;
  final HttpClient _client;
  String? _token;
  DateTime _expires = DateTime(2000);
  Future<String>? _refreshing;
  bool _closed = false;

  Future<String> token() {
    if (_token != null && DateTime.now().isBefore(_expires)) return Future.value(_token!);
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh() async {
    final data = await request('POST', '$tokenBase/app/getAppAccessToken',
      body: {'appId': appId, 'clientSecret': secret});
    final value = data['access_token'];
    if (value is! String || value.isEmpty) throw QqApiException('token_missing');
    final seconds = int.tryParse('${data['expires_in']}') ?? 0;
    if (seconds < 10) throw QqApiException('token_expired');
    _token = value;
    _expires = DateTime.now().add(Duration(seconds: seconds > 120 ? seconds - 60 : seconds ~/ 2));
    return value;
  }

  void invalidateToken() { _token = null; }

  Future<Map<String, dynamic>> authenticated(String method, String path,
      {Map<String, Object?>? body, bool sending = false}) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await request(method, '$apiBase$path', body: body, accessToken: await token(), sending: sending);
      } on QqApiException catch (e) {
        // An explicit HTTP 401 rejected the operation: refresh once. Never
        // blindly retry a send whose network result is unknown.
        if (e.code != 'http_401' || attempt != 0) rethrow;
        invalidateToken();
      }
    }
  }

  Future<String> gatewayUrl() async {
    final data = await authenticated('GET', '/gateway/bot');
    final value = data['url'];
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || uri.scheme != 'wss' || uri.userInfo.isNotEmpty ||
        !(uri.host == 'qq.com' || uri.host.endsWith('.qq.com'))) throw QqApiException('gateway_invalid');
    return value as String;
  }

  Future<void> send(String owner, String messageId, String text, int sequence) async {
    if (owner.isEmpty || messageId.isEmpty || text.isEmpty) throw QqApiException('invalid_target');
    final data = await authenticated('POST', '/v2/users/${Uri.encodeComponent(owner)}/messages', sending: true,
      body: {'msg_type': 0, 'content': text, 'msg_id': messageId, 'msg_seq': sequence});
    if (data['id'] is! String || (data['id'] as String).isEmpty) {
      throw QqApiException('send_receipt_missing', uncertain: true);
    }
  }

  String _target(bool group,String target) {
    if(target.isEmpty || target.length>256) throw QqApiException('invalid_target');
    return '/v2/${group?'groups':'users'}/${Uri.encodeComponent(target)}';
  }
  Future<void> sendMessage({required bool group,required String target,required String messageId,
    required int sequence,String text='',String fileInfo=''}) async {
    if(text.isEmpty && fileInfo.isEmpty || sequence<1) throw QqApiException('invalid_message');
    final result=await authenticated('POST','${_target(group,target)}/messages',sending:true,body:{
      'msg_type':fileInfo.isEmpty?0:7,if(text.isNotEmpty)'content':text,if(fileInfo.isNotEmpty)'media':{'file_info':fileInfo},
      if(messageId.isNotEmpty)'msg_id':messageId,'msg_seq':sequence});
    if(result['id'] is! String || (result['id'] as String).isEmpty) throw QqApiException('send_receipt_missing',uncertain:true);
  }
  /// Official local media flow, no external image hosting. Uploading itself
  /// does not send a QQ message; only the later media message can do that.
  Future<String> uploadImage({required bool group,required String target,required Uint8List bytes,
    required String filename,required Future<bool> Function() current}) async =>
    (await uploadMedia(group:group,target:target,bytes:bytes,filename:filename,current:current,fileType:1)).fileInfo;

  Future<QqMediaUpload> uploadVoice({required bool group,required String target,required Uint8List bytes,
    required Future<bool> Function() current}) =>
    uploadMedia(group:group,target:target,bytes:bytes,filename:'voice.wav',current:current,fileType:3);

  Future<QqMediaUpload> uploadMedia({required bool group,required String target,required Uint8List bytes,
    required String filename,required Future<bool> Function() current,required int fileType}) async {
    if(fileType!=1 && fileType!=3)throw QqApiException('media_type');
    if(bytes.isEmpty || bytes.length>10*1024*1024) throw QqApiException('image_too_large');
    Future<void> check() async {if(_closed || !await current()) throw QqApiException('stopped');}
    await check(); final root=_target(group,target);
    final prepare=await authenticated('POST','$root/upload_prepare',body:{'file_type':fileType,'file_name':filename,
      'file_size':bytes.length,'md5':md5.convert(bytes).toString(),'sha1':sha1.convert(bytes).toString(),
      'md5_10m':md5.convert(bytes.sublist(0,bytes.length<10002432?bytes.length:10002432)).toString()});
    final upload=prepare['upload_id']; final block=int.tryParse('${prepare['block_size']}')??0; final rawParts=prepare['parts'];
    if(upload is! String || upload.isEmpty || block<=0 || rawParts is! List || rawParts.isEmpty || rawParts.length>32) throw QqApiException('upload_invalid');
    final parts=rawParts.map((p){if(p is! Map) throw QqApiException('upload_invalid');return p;}).toList()
      ..sort((a,b)=>(int.tryParse('${a['index']}')??0).compareTo(int.tryParse('${b['index']}')??0));
    var offset=0;
    for(var i=0;i<parts.length;i++) {
      await check(); final part=parts[i]; final index=int.tryParse('${part['index']}')??0;
      final partBlock=int.tryParse('${part['block_size']}')??0;
      if(index!=i+1 || offset!=i*block || offset>=bytes.length) throw QqApiException('upload_invalid');
      final remaining=bytes.length-offset; final declared=partBlock>0?partBlock:block;
      final length=declared<remaining?declared:remaining;
      if(length<=0 || i<parts.length-1 && length!=block) throw QqApiException('upload_invalid');
      final uri=Uri.tryParse('${part['presigned_url']}');
      if(uri==null || uri.scheme!='https' || uri.userInfo.isNotEmpty ||
        !(uri.host.endsWith('.myqcloud.com') || uri.host.endsWith('.qq.com'))) throw QqApiException('upload_url_invalid');
      final chunk=bytes.sublist(offset,offset+length); HttpClientRequest? put;
      try {
        await (() async {
          put=await _client.putUrl(uri);put!.followRedirects=false;put!.contentLength=length;put!.add(chunk);
          final response=await put!.close();await response.drain<void>();
          if(response.statusCode<200 || response.statusCode>=300) throw QqApiException('upload_failed');
        })().timeout(const Duration(seconds:30),onTimeout:(){put?.abort();throw QqApiException('upload_timeout');});
      } catch(_) {put?.abort();rethrow;}
      await check();
      await authenticated('POST','$root/upload_part_finish',body:{'upload_id':upload,'part_index':index,
        'block_size':length,'md5':md5.convert(chunk).toString()});
      offset+=length;
    }
    if(offset!=bytes.length) throw QqApiException('upload_incomplete');
    await check(); final result=await authenticated('POST','$root/files',body:{'upload_id':upload});
    final info=result['file_info'];
    if(info is! String || info.isEmpty || info.length>48000) throw QqApiException('upload_token_missing');
    final rawTtl=result['ttl'];
    final ttl=rawTtl is int && rawTtl>0 && rawTtl<=31536000?rawTtl:null;
    return QqMediaUpload(info,ttl:ttl);
  }

  Future<Map<String, dynamic>> request(String method, String url,
      {Map<String, Object?>? body, String? accessToken, bool sending = false}) async {
    if (_closed) throw QqApiException('stopped');
    HttpClientRequest? outgoing;
    try {
      return await (() async {
        outgoing = await _client.openUrl(method, Uri.parse(url));
        outgoing!.headers.set(HttpHeaders.userAgentHeader, 'AICompanion-QQPrivate/0.1');
        outgoing!.headers.contentType = ContentType.json;
        if (accessToken != null) {
          outgoing!.headers.set(HttpHeaders.authorizationHeader, 'QQBot $accessToken');
          outgoing!.headers.set('X-Union-Appid', appId);
        }
        if (body != null) outgoing!.write(jsonEncode(body));
        final response = await outgoing!.close();
        final bytes = <int>[];
        await for (final part in response) {
          bytes.addAll(part);
          if (bytes.length > 256 * 1024) throw QqApiException('response_too_large', uncertain: sending);
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw QqApiException('http_${response.statusCode}', uncertain: sending && response.statusCode >= 500);
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map<String, dynamic>) throw QqApiException('response_invalid', uncertain: sending);
        final businessCode=data['code']??data['biz_code'];
        if (businessCode != null && businessCode != 0) {
          final code = '$businessCode';
          throw QqApiException(RegExp(r'^\d{1,12}$').hasMatch(code) ? 'api_$code' : 'api_error');
        }
        return data;
      })().timeout(const Duration(seconds: 20), onTimeout: () {
        outgoing?.abort();
        throw QqApiException('timeout', uncertain: sending);
      });
    } on QqApiException { rethrow;
    } catch (_) { throw QqApiException(_closed ? 'stopped' : 'network', uncertain: sending); }
  }

  void close() { _closed = true; _client.close(force: true); }
}
