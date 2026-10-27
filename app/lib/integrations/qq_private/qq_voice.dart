import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../core/models/chat_language_variant.dart';
import '../../core/tts/genie_fixed_text_segmenter.dart';
import '../../core/tts/tts_text_processor.dart';
import 'qq_failure.dart';

class QqVoiceChoice {
  const QqVoiceChoice(this.language,this.text,{this.voice='daily'});
  final String language,text,voice;
  static final _tag=RegExp(r'<qq_voice\s*>([\s\S]*?)</qq_voice>',caseSensitive:false);
  static const voices={'daily','gentle','lively','cute'};
  static QqVoiceChoice? parse(String raw) {
    final matches=_tag.allMatches(raw).toList();if(matches.length!=1)return null;
    try {
      final data=jsonDecode(matches.single.group(1)!);
      if(data is! Map || !const {'zh','ja','en'}.contains(data['language']) || data['text'] is! String)return null;
      final rawText=(data['text'] as String).trim();
      if(rawText.isEmpty || rawText.runes.length>600 || rawText.contains('<qq_'))return null;
      final text=const TtsTextProcessor().process(rawText,language:ChatLanguage.tryParse(data['language'] as String)!,scope:TtsReadingScope.dialogueOnly);
      if(text.isEmpty)return null;
      final voice=data['voice'];
      return QqVoiceChoice(data['language'] as String,text,voice:voices.contains(voice)?voice as String:'daily');
    } catch(_) {return null;}
  }
  static String visible(String raw)=>raw.replaceAll(_tag,'')
    .replaceAll(RegExp(r'<qq_voice\b[\s\S]*$',caseSensitive:false),'').trim();
  static const prompt='【可选QQ语音】本轮可以发中文、日语或英语短语音。明确要求语音时优先考虑；平时主要文字，也可偶尔自然选择声音表达。'
    '在回复最后加且只加一次<qq_voice>{"language":"zh|ja|en","text":"实际要说的目标语言台词","voice":"daily|gentle|lively|cute"}</qq_voice>。'
    '语种必须与台词一致，要求日语/英语就直接写对应台词，不先输出中文再要求宿主翻译。只写台词，不写动作或内部分析，最多600字。'
    '纯语音只输出这个标签；语音算一条消息，前面最多两条完整文字，别把同一台词再抄成文字。'
    '语音、表情包和涂鸦本轮选一种。不解释标签，不提前声称发送成功；不想发语音就正常文字。'
    '能读取你已发语音的归档台词并翻译或接着聊；尚不能听懂收到的语音，不假称已听到。';
}

/// Silent, lower-priority synthesis. Native ownership is independent of the
/// App playback lease; cancellation cannot stop a newer App session.
class QqVoiceService {
  QqVoiceService({this.channel=const MethodChannel('ai_companion/tts'),
    this.timeout=const Duration(seconds:90),this.claimWait=const Duration(seconds:15)});
  final MethodChannel channel;final Duration timeout,claimWait;
  bool _closed=false,_running=false;int? _active;
  Future<void> _end(int id,bool cancel) async {
    try {await channel.invokeMethod<void>('endVoiceExport',{'export_id':id,'cancel':cancel}).timeout(const Duration(seconds:2));}catch(_){}
  }
  Future<Uint8List> generate(QqVoiceChoice choice,{required Future<bool> Function() current}) async {
    if(_closed || _running)throw const QqOperationFailure('voice_busy');
    _running=true;int? id;var complete=false,finished=false;
    final abort=Completer<Uint8List>();var checking=false;
    final deadline=Timer(timeout,(){if(!abort.isCompleted)abort.completeError(const QqOperationFailure('voice_timeout'));});
    final poll=Timer.periodic(const Duration(milliseconds:500),(_) async {
      if(checking || abort.isCompleted)return;checking=true;
      try {if(_closed || !await current())abort.completeError(const QqOperationFailure('voice_cancelled'));}
      catch(_) {if(!abort.isCompleted)abort.completeError(const QqOperationFailure('voice_cancelled'));}
      finally {checking=false;}
    });
    // The abort future always has a listener, including during claim waits.
    unawaited(abort.future.catchError((Object _)=>Uint8List(0)));
    Future<T> guarded<T>(Future<T> work) => Future.any<T>([work,abort.future.then<T>((_)=>throw const QqOperationFailure('voice_cancelled'))]);
    try {
      if(!await current())throw const QqOperationFailure('voice_cancelled');
      final start=DateTime.now();
      while(id==null) {
        if(_closed || !await current())throw const QqOperationFailure('voice_cancelled');
        final claim=channel.invokeMethod<num>('claimVoiceExport');
        unawaited(claim.then((late) async {
          if(late!=null && (finished || abort.isCompleted || _closed))await _end(late.toInt(),true);
        }).catchError((Object _) {}));
        final claimed=await guarded(claim);
        id=claimed?.toInt();_active=id;
        if(id!=null)break;
        if(DateTime.now().difference(start)>=claimWait)throw const QqOperationFailure('voice_busy');
        await guarded(Future<void>.delayed(const Duration(milliseconds:250)));
      }
      final language=ChatLanguage.tryParse(choice.language)!;
      const processor=TtsTextProcessor();
      final spoken=processor.process(choice.text,language:language,scope:TtsReadingScope.dialogueOnly);
      if(spoken.isEmpty)throw const QqOperationFailure('voice_text');
      final chunks=GenieFixedTextSegmenter.splitFirstImmediate(spoken,language);
      if(chunks.isEmpty || chunks.length>16)throw const QqOperationFailure('voice_text');
      final audio=<Uint8List>[];
      for(final text in chunks) {
        if(_closed || !await current())throw const QqOperationFailure('voice_cancelled');
        final bytes=await guarded(channel.invokeMethod<Uint8List>('generateVoiceExport',
          {'export_id':id,'text':text,'language':choice.language,'voice':choice.voice}));
        if(bytes==null || bytes.length<44)throw const QqOperationFailure('voice_audio');
        audio.add(bytes);
      }
      if(!await current())throw const QqOperationFailure('voice_cancelled');
      final wav=QqVoiceWav.join(audio);complete=true;return wav;
    } on PlatformException catch(e) {
      throw QqOperationFailure(e.message?.contains('voice_export_preempted')==true?'voice_preempted':'voice_generation_failed');
    } finally {
      finished=true;
      deadline.cancel();poll.cancel();
      if(id!=null)await _end(id,!complete);
      if(_active==id)_active=null;_running=false;
    }
  }
  void close(){_closed=true;final id=_active;if(id!=null)unawaited(_end(id,true));}
}

/// Join bounded PCM16 chunks without playback or a multimedia dependency.
abstract final class QqVoiceWav {
  static Uint8List join(List<Uint8List> chunks) {
    Uint8List? format;final pcm=BytesBuilder(copy:false);
    for(final bytes in chunks) {
      final data=ByteData.sublistView(bytes);
      String tag(int n)=>String.fromCharCodes(bytes.sublist(n,n+4));
      if(bytes.length<44 || tag(0)!='RIFF' || tag(8)!='WAVE' || data.getUint32(4,Endian.little)+8!=bytes.length)throw const QqOperationFailure('voice_audio');
      Uint8List? fmt,body;
      for(var offset=12;offset+8<=bytes.length;) {
        final length=data.getUint32(offset+4,Endian.little),end=offset+8+length;
        if(end>bytes.length)throw const QqOperationFailure('voice_audio');
        if(tag(offset)=='fmt ' && length>=16)fmt=Uint8List.sublistView(bytes,offset+8,offset+24);
        if(tag(offset)=='data')body=Uint8List.sublistView(bytes,offset+8,end);
        offset=end+(length.isOdd?1:0);
      }
      if(fmt==null || body==null || body.isEmpty)throw const QqOperationFailure('voice_audio');
      final f=ByteData.sublistView(fmt),channels=f.getUint16(2,Endian.little),rate=f.getUint32(4,Endian.little);
      if(f.getUint16(0,Endian.little)!=1 || !const {1,2}.contains(channels) || rate<8000 || rate>48000 ||
        f.getUint16(14,Endian.little)!=16 || f.getUint16(12,Endian.little)!=channels*2 ||
        f.getUint32(8,Endian.little)!=rate*channels*2 || body.length%(channels*2)!=0)throw const QqOperationFailure('voice_audio');
      if(format!=null && base64Encode(format)!=base64Encode(fmt))throw const QqOperationFailure('voice_audio');
      format??=fmt;pcm.add(body);
      if(pcm.length>10*1024*1024-44 || pcm.length>rate*channels*2*75)throw const QqOperationFailure('voice_audio_size');
    }
    if(format==null || pcm.isEmpty)throw const QqOperationFailure('voice_audio');
    final body=pcm.takeBytes(),header=ByteData(44);
    final bytes=header.buffer.asUint8List();
    bytes.setRange(0,4,ascii.encode('RIFF'));header.setUint32(4,36+body.length,Endian.little);
    bytes.setRange(8,12,ascii.encode('WAVE'));bytes.setRange(12,16,ascii.encode('fmt '));
    header.setUint32(16,16,Endian.little);bytes.setRange(20,36,format);
    bytes.setRange(36,40,ascii.encode('data'));header.setUint32(40,body.length,Endian.little);
    return (BytesBuilder(copy:false)..add(bytes)..add(body)).takeBytes();
  }
}
