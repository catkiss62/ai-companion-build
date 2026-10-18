import 'model_dialogue_models.dart';

/// The cursor counts original text, never generated summaries. A single long
/// message can span batches without dropping its beginning or ending.
class ModelDialogueArchiveBatch {
  ModelDialogueArchiveBatch(List<ModelDialogueMessage> history,this.start,{int budget=18000}) {
    total=history.fold<int>(0,(n,m)=>n+m.text.length);
    if(start<0||start>=total||budget<2)throw const FormatException('invalid_archive_cursor');
    var position=0;
    var remaining=budget;
    final selected=<ModelDialogueMessage>[];
    for(final m in history) {
      final next=position+m.text.length;
      if(next<=start){position=next;continue;}
      final from=(start-position).clamp(0,m.text.length).toInt();
      var to=(from+remaining).clamp(from,m.text.length).toInt();
      if(to<m.text.length&&to>from&&_high(m.text.codeUnitAt(to-1))&&_low(m.text.codeUnitAt(to)))to--;
      if(to==from)break;
      selected.add(ModelDialogueMessage(id:m.id,roomId:m.roomId,sequence:m.sequence,
        speaker:m.speaker,text:m.text.substring(from,to),model:m.model,createdAt:m.createdAt,action:m.action));
      remaining-=to-from;
      position=next;
      if(remaining<2||selected.length>=64)break;
    }
    messages=selected;
    end=start+selected.fold<int>(0,(n,m)=>n+m.text.length);
    if(end<=start)throw const FormatException('empty_archive_batch');
  }
  final int start;
  late final int end,total;
  late final List<ModelDialogueMessage> messages;
  bool get complete=>end==total;
  Map<String,Object?> get coverage=>{'start':start,'end':end,'total':total,'complete':complete};
  Map<String,Object?> get cumulativeCoverage=>{...coverage,'start':0};

  static List<ModelDialogueMessage> prefix(List<ModelDialogueMessage> history,int end) {
    var remaining=end;
    final result=<ModelDialogueMessage>[];
    for(final m in history) {
      if(remaining<=0)break;
      final length=remaining.clamp(0,m.text.length).toInt();
      result.add(ModelDialogueMessage(id:m.id,roomId:m.roomId,sequence:m.sequence,
        speaker:m.speaker,text:m.text.substring(0,length),model:m.model,createdAt:m.createdAt,action:m.action));
      remaining-=length;
    }
    return result;
  }
  static bool _high(int c)=>c>=0xd800&&c<=0xdbff;
  static bool _low(int c)=>c>=0xdc00&&c<=0xdfff;
}
