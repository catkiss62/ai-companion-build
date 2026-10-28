import 'dart:math';
import 'package:qq_private_bridge/qq_private_bridge.dart';

class QqDeliveryFailure implements Exception {
  const QqDeliveryFailure(this.cause,this.confirmed,{this.archiveFailed=false});
  final Object cause;
  final int confirmed;
  final bool archiveFailed;
  String get state=>archiveFailed?'sent_archive_failed':
    cause is QqApiException && (cause as QqApiException).uncertain?'send_uncertain':'partially_sent';
}

/// One platform message has one local receipt. Unknown delivery never falls
/// back to a second send; only an explicit type rejection permits splitting.
class QqReplyDelivery {
  const QqReplyDelivery(this.api, {this.pause, this.interval});
  final QqApi api;
  final Future<void> Function(Duration)? pause;
  final Duration Function()? interval;
  static final _random = Random();

  static List<String> validate(String text,List<String>? messages) {
    final chunks=(messages??[if(text.isNotEmpty)text]).where((p)=>p.trim().isNotEmpty).toList();
    if(chunks.length>3 || chunks.any((p)=>p.runes.length>1800) || chunks.fold<int>(0,(n,p)=>n+p.runes.length)>5400)throw const FormatException('qq_reply_parts_invalid');
    return chunks;
  }
  Future<void> send({required bool group, required String target, required String messageId,
    required String text, required String fileInfo, List<String>? messages, required Future<bool> Function() current,
    required Future<void> Function() beforeSend,
    required Future<void> Function(int sequence, String text, bool image) sent,
    Future<void> Function()? confirmed,Future<bool> Function()? mediaCurrent,
    void Function(int sequence,QqMessageReceipt receipt)? received,
    String voiceText='',String voiceLanguage='',Future<void> Function(int sequence,String transcript,String language)? sentVoice}) async {
    final chunks=validate(text,messages);
    final voice=voiceText.isNotEmpty && fileInfo.isNotEmpty;
    if(voice && (chunks.length>2 || sentVoice==null || !const {'zh','ja','en'}.contains(voiceLanguage)))throw const FormatException('qq_voice_parts');
    var sequence = 0, delivered = 0;
    Future<void> part(String content, String media,{bool isVoice=false}) async {
      if (!await current()) throw StateError('context_invalidated');
      if(delivered>0) {
        final wait=interval?.call()??Duration(milliseconds:1000+_random.nextInt(1001));
        if(pause!=null) {await pause!(wait);} else {await Future<void>.delayed(wait);}
        if(!await current()) throw StateError('context_invalidated');
      }
      await beforeSend();
      if(!await current()) throw StateError('context_invalidated');
      final seq = ++sequence;
      await api.sendMessage(group: group, target: target, messageId: messageId, sequence: seq, text: content, fileInfo: media,
        current:() async=>await current() && (media.isEmpty || mediaCurrent==null || await mediaCurrent!()));
      delivered++;
      received?.call(seq,api.receiptFor(group:group,target:target,messageId:messageId,sequence:seq));
      // A confirmed platform send cannot become an unsent failure just because
      // its local transaction fails. Retry the local commit only, never QQ.
      try {await confirmed?.call();}catch(_) {}
      for(var attempt=0;;attempt++) {
        try {
          if(isVoice) {await sentVoice!(seq,voiceText,voiceLanguage);}
          else {await sent(seq, content, media.isNotEmpty);}
          break;
        } catch(error) {
          var valid=false;try {valid=await current();}catch(_) {}
          if(attempt>0 || !valid)throw QqDeliveryFailure(error,delivered,archiveFailed:true);
        }
      }
    }
    Future<void> plan() async {
    if(voice) {
      for(final chunk in chunks) {await part(chunk,'');}
      try {await part('',fileInfo,isVoice:true);}
      on QqApiException catch(error) {
        // Explicit rejection is safe to replace with one text transcript.
        // Unknown delivery is never retried as a second message.
        if(error.uncertain || !(error.code.startsWith('api_') || const {'http_400','http_403','http_404','http_415'}.contains(error.code)))rethrow;
        await part(voiceText,'');
      }
      return;
    }
    if (fileInfo.isEmpty) {
      for (final chunk in chunks) { await part(chunk, ''); }
      return;
    }
    for (final chunk in chunks.take(chunks.isEmpty ? 0 : chunks.length - 1)) { await part(chunk, ''); }
    final caption = chunks.isEmpty ? '' : chunks.last;
    if(mediaCurrent!=null && !await mediaCurrent!()) {
      if(caption.isNotEmpty)await part(caption,'');
      return;
    }
    try {
      await part(caption, fileInfo);
    } on QqApiException catch (error) {
      if(error.code=='stopped' && !error.uncertain && await current() && mediaCurrent!=null && !await mediaCurrent!()) {
        if(caption.isNotEmpty)await part(caption,'');
        return;
      }
      if (caption.isEmpty || error.uncertain || !const {'api_22006', 'api_340069'}.contains(error.code)) rethrow;
      await part(caption, '');
      await part('', fileInfo);
    }
    }
    try {await plan();}catch(error) {
      if(error is QqDeliveryFailure)rethrow;
      if(delivered>0)throw QqDeliveryFailure(error,delivered);
      rethrow;
    }
  }
}
