import 'model_dialogue_models.dart';

/// Message time is evidence; room closure and later summarization are not a
/// substitute for when the conversation actually happened.
abstract final class ModelDialogueTime {
  static String format(int milliseconds) {
    if(milliseconds<=0)return '未知';
    final time=DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final offset=time.timeZoneOffset.inMinutes;
    final hours=(offset.abs()~/60).toString().padLeft(2,'0');
    final minutes=(offset.abs()%60).toString().padLeft(2,'0');
    return '${time.toIso8601String()} UTC${offset<0?'-':'+'}$hours:$minutes';
  }

  static Map<String,Object?> range(List<ModelDialogueMessage> messages) {
    return rangeOfTimes(messages.map((m)=>m.createdAt));
  }

  static Map<String,Object?> rangeOfTimes(Iterable<int> values) {
    final times=values.where((t)=>t>0).toList()..sort();
    return {'first_message_at':times.isEmpty?null:times.first,
      'last_message_at':times.isEmpty?null:times.last};
  }

  static String describe(ModelDialogueRoom room,List<ModelDialogueMessage> messages,{DateTime? now}) {
    final times=range(messages);
    return '当前时间：${format((now??DateTime.now()).millisecondsSinceEpoch)}；'
      '本场实际发言时间范围：${format(times['first_message_at'] as int? ?? 0)} 至 '
      '${format(times['last_message_at'] as int? ?? 0)}；'
      '关闭时间：${format((room.data['ended_at'] as num?)?.toInt()??0)}。'
      '历史中的今天/昨天/刚才以各条发言时间为准；关闭、恢复和整理不代表这些内容刚刚发生。';
  }
}
