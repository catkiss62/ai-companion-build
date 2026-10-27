import 'dart:convert';
import '../../core/qq/qq_message_material.dart';

/// Normalizes the official push fields once. No inner sender/group claim is
/// promoted into the trusted outer account, receive clock, or group binding.
class QqIncoming {
  QqIncoming._(this.text, this.replyTo, this.urls, this.material);
  final String text, replyTo;
  final List<String> urls;
  final QqMessageMaterial material;

  static QqIncoming parse(Map<String, dynamic> event) {
    String index(Object? v) => v is String || v is int
        ? QqMessageMaterial.bound('$v', 128) : '';
    var partial = false, unsupported = false;
    final urls = <String>[], origins = <String>[];
    List<int> attachments(Object? raw, String origin) {
      final result = <int>[];
      if (raw is! List) return result;
      if (raw.length > 8) partial = true;
      for (final item in raw.take(8)) {
        if (item is! Map || item['content_type'] is! String ||
            !(item['content_type'] as String).startsWith('image/') || item['url'] is! String) {
          unsupported = true;
          continue;
        }
        final url = item['url'] as String;
        if (url.isEmpty || url.length > 8192 || urls.length >= 8) {partial = true; continue;}
        result.add(urls.length); urls.add(url); origins.add(origin);
      }
      return result;
    }
    attachments(event['attachments'], 'outer');
    var original = event['content'] is String ? (event['content'] as String).trim() : '';
    if (original.length > 15000) partial = true;
    final elements = event['msg_elements'];
    final parts = <Map<String, Object?>>[];
    // Some official events flatten a forwarded card into a text transcript.
    // Its visible labels describe unverified material, never a live speaker.
    final flat=RegExp(r'^\[(?:群聊的聊天记录|聊天记录|转发聊天记录)\]\s*\n=== 消息 \d+ ===').hasMatch(original);
    if(flat) {
      final safe=original.replaceAll(RegExp(r'https?://[^\s<>]+',caseSensitive:false),'[附件地址已省略]');
      parts.add({'text':QqMessageMaterial.bound(safe,2000),'index':'','image_ordinals':<int>[]});
      partial=partial || safe.length>2000;original='';
    }
    if (elements is List) {
      final available=4-parts.length;
      if (elements.length > available) partial = true;
      for (final element in elements.take(available)) {
        if (element is! Map) {partial = true; continue;}
        final text = element['content'] is String ? element['content'] as String : '';
        if (text.length > 2000) partial = true;
        parts.add({'text': QqMessageMaterial.bound(text, 2000),
          'index': index(element['msg_idx']),
          'image_ordinals': attachments(element['attachments'], 'material')});
      }
    }
    var reference = index(event['ref_msg_idx']);
    final scene = event['message_scene'];
    // Accept an explicit reference extension when supplied. Unknown strings
    // remain unknown; never evaluate an ext payload or guess its encoding.
    if (reference.isEmpty && scene is Map && scene['ext'] is List) {
      for (final ext in (scene['ext'] as List).take(8)) {
        if (ext is! String || ext.length > 2048) continue;
        try {
          final value = jsonDecode(ext);
          if (value is Map) reference = index(value['ref_msg_idx']);
        } catch (_) { /* Unrecognized extension is not executable data. */ }
        if (reference.isNotEmpty) break;
      }
    }
    final legacy = event['message_reference'];
    final legacyId=legacy is Map?legacy['message_id']:null;
    final replyTo=legacyId is String || legacyId is int?QqMessageMaterial.bound('$legacyId',1024):'';
    final quoted = event['message_type'] == 103 || '${event['message_type']}' == '103' ||
        reference.isNotEmpty || replyTo.isNotEmpty;
    if (reference.isEmpty && quoted && parts.isNotEmpty) reference = parts.first['index'] as String;
    var material = QqMessageMaterial(kind: quoted ? 'quote' : parts.isNotEmpty ? 'embedded' : 'message',
      index: index(event['msg_idx']), reference: reference, parts: parts,
      imageOrigins: origins, partial: partial || unsupported || quoted && parts.isEmpty);
    // JSON escaping can expand control characters beyond the raw text budget.
    for(var limit=1000;material.encode().length>12000 && limit>=0;limit=limit==0?-1:limit~/2) {
      for(final part in parts) {part['text']=QqMessageMaterial.bound(part['text'] as String,limit);}
      material=QqMessageMaterial(kind:material.kind,index:material.index,reference:material.reference,
        parts:parts,imageOrigins:origins,partial:true);
    }
    // Keep top-level comments separate from the nested material in storage.
    final text = QqMessageMaterial.bound(original, 15000);
    return QqIncoming._(text, replyTo, urls, material);
  }
}
