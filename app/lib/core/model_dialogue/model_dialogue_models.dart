import 'dart:convert';

const modelDialogueSpeakers = ['deepseek', 'gemini'];
String modelDialogueLabel(String speaker) => switch (speaker) {
  'deepseek' => 'DeepSeek', 'gemini' => 'Gemini', _ => '你',
};
String otherModelDialogueSpeaker(String speaker) => speaker == 'deepseek' ? 'gemini' : 'deepseek';

class ModelDialogueRoom {
  const ModelDialogueRoom(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get topic => data['topic'] as String? ?? '';
  String get status => data['status'] as String? ?? 'paused';
  bool get ended => status == 'ended';
  bool get deleted => status == 'deleted';
  String get nextSpeaker => data['next_speaker'] as String? ?? 'deepseek';
  String get closingSpeaker => data['closing_speaker'] as String? ?? '';
  String get requestId => data['request_id'] as String? ?? '';
  int get revision => (data['revision'] as num?)?.toInt() ?? 0;
  int get sequence => (data['sequence'] as num?)?.toInt() ?? 0;
  int get updatedAt => (data['updated_at'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> participant(String speaker) =>
      Map<String, dynamic>.from((data['participants'] as Map?)?[speaker] as Map? ?? const {});
  String modelName(String speaker) => participant(speaker)['model'] as String? ?? '';
  static ModelDialogueRoom? decode(String? raw) {
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw ?? '') as Map);
      if (m['version'] != 1 || m['id'] is! String || m['title'] is! String ||
          !const {'paused', 'active', 'ended', 'deleted'}.contains(m['status'])) return null;
      return ModelDialogueRoom(m);
    } catch (_) { return null; }
  }
}

class ModelDialogueMessage {
  const ModelDialogueMessage({required this.id, required this.roomId,
    required this.sequence, required this.speaker, required this.text,
    required this.model, required this.createdAt,this.action='continue'});
  final String id, roomId, speaker, text, model, action;
  final int sequence, createdAt;
  Map<String, Object?> toJson() => {'id':id,'room_id':roomId,'sequence':sequence,
    'speaker':speaker,'text':text,'model':model,'created_at':createdAt,'action':action};
  static ModelDialogueMessage? decode(String? raw) {
    try {
      final m = jsonDecode(raw ?? '') as Map;
      if (!const {'user','deepseek','gemini'}.contains(m['speaker'])) return null;
      return ModelDialogueMessage(id:m['id'] as String,roomId:m['room_id'] as String,
        sequence:(m['sequence'] as num).toInt(),speaker:m['speaker'] as String,
        text:m['text'] as String,model:m['model'] as String,
        createdAt:(m['created_at'] as num).toInt(),action:m['action'] as String? ?? 'continue');
    } catch (_) { return null; }
  }
}

class ModelDialogueOutput {
  const ModelDialogueOutput(this.text, this.action);
  final String text, action;
  static ModelDialogueOutput parse(String raw) {
    var value=raw.trim();
    if(value.startsWith('```') && value.endsWith('```')) {
      final start=value.indexOf('\n');
      if(start>=0)value=value.substring(start+1,value.length-3).trim();
    }
    final decoded=jsonDecode(value);
    if(decoded is! Map || decoded['text'] is! String ||
        !const {'continue','close','end'}.contains(decoded['action'])) {
      throw const FormatException('invalid_dialogue_envelope');
    }
    final text=(decoded['text'] as String).trim();
    if(text.length>100000 || (text.isEmpty && decoded['action']!='end')) {
      throw const FormatException('empty_or_oversized_dialogue_text');
    }
    return ModelDialogueOutput(text,decoded['action'] as String);
  }

  /// Shows only the first JSON text field, including escaped Unicode. Control
  /// fields and incomplete escapes never become visible dialogue or history.
  static String preview(String raw) {
    final match=RegExp(r'^\s*(?:```(?:json)?\s*)?\{\s*"text"\s*:\s*"').firstMatch(raw);
    if(match==null)return '';
    final out=StringBuffer();
    var i=match.end;
    while(i<raw.length) {
      final ch=raw[i++];
      if(ch=='"')break;
      if(ch!='\\') {out.write(ch);continue;}
      if(i>=raw.length)break;
      final escaped=raw[i++];
      if(escaped=='u') {
        if(i+4>raw.length)break;
        final code=int.tryParse(raw.substring(i,i+4),radix:16);
        if(code==null)break;
        i+=4;
        if(code>=0xd800&&code<=0xdbff) {
          if(i+6>raw.length||raw.substring(i,i+2)!='\\u')break;
          final low=int.tryParse(raw.substring(i+2,i+6),radix:16);
          if(low==null||low<0xdc00||low>0xdfff)break;
          out.writeCharCode(0x10000+((code-0xd800)<<10)+(low-0xdc00));i+=6;
        } else {out.writeCharCode(code);}
      } else {
        const escapes={'n':'\n','r':'\r','t':'\t','b':'\b','f':'\f','"':'"','\\':'\\','/':'/'};
        if(!escapes.containsKey(escaped))break;
        out.write(escapes[escaped]);
      }
    }
    return out.toString();
  }
}
