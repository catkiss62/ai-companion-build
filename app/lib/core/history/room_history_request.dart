/// Only requests to recall an existing room qualify. Creating/configuring rooms
/// and merely mentioning their feature names remain ordinary conversation.
class RoomHistoryRequest {
  const RoomHistoryRequest(this.kind, this.query, this.view);
  final String kind, query, view;
  Map<String,String> get arguments => {'kind':kind,'query':query,'view':view};
  static RoomHistoryRequest? parse(String input) {
    final text=input.replaceAll(RegExp(r'\s+'),' ').trim();
    if(text.isEmpty || RegExp(r'^(?:请|先|你)?(?:不要|不用|别|无需|不需要)|^(?:如果|假如|假设|比如|举例|他说|她说|[>“「"])').hasMatch(text)) return null;
    final kind=RegExp(r'模型对谈|模型对话室|两个模型|(?:DeepSeek|Gemini).{0,8}(?:当时|上次|之前|说过|聊过)|(?:当时|上次|之前).{0,8}(?:DeepSeek|Gemini)' ).hasMatch(text)?'model_dialogue':
      text.contains('沉浸房间')?'immersive':'';
    if(kind.isEmpty || RegExp(r'(创建|新建|新增|开发|实现|改成|修改|功能|按钮|界面|设置|能不能看到|是否应该)').hasMatch(text)) return null;
    if(!RegExp(r'(回看|回顾|翻看|查阅|查看|查一下|找一下|读一下|原文|记录|摘要|总结|上次|之前|昨天|当时|刚才|记得|聊过|说过|讨论过)').hasMatch(text)) return null;
    if(!RegExp(r'(什么|哪些|为什么|怎么|如何|吗|呢|？|\?|回看|回顾|翻看|查阅|查看|查一下|找一下|读一下|告诉我)').hasMatch(text)) return null;
    final quoted=RegExp(r'[“「"]([^”」"]{1,100})[”」"]').firstMatch(text)?.group(1);
    final topic=RegExp(r'(?:关于|有关)([^，。？！?]{1,100})').firstMatch(text)?.group(1);
    final view=RegExp(r'(原文|原话|具体怎么说|一字不差)').hasMatch(text)?'transcript':
      RegExp(r'(详细|具体|完整|来龙去脉)').hasMatch(text)?'detail':'summary';
    return RoomHistoryRequest(kind,quoted??topic??'',view);
  }
}
