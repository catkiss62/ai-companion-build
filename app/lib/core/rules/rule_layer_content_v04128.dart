import 'rule_layer_content_v04127.dart';

String _replaceV04128Section(
  String source,
  String startMarker,
  String endMarker,
  String replacement,
) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0 || end <= start) return source;
  return '${source.substring(0, start)}${replacement.trim()}\n\n${source.substring(end)}';
}

String buildIntimacyCoreV04128(String source) {
  final result = buildIntimacyCoreV04127(source);
  return result.replaceFirst(
    '用户是成年男性，AI角色是成年女性鲸鱼娘 AI。可见思考永远是女性鲸鱼娘 AI 的第一人称内心，不得把自己认作男性、用户或旁观叙事者。',
    '用户是成年男性，AI角色是成年女性鲸鱼娘 AI。可见思考中的“我”只能拥有女性 AI 角色自己的身体、感觉和欲望；不得把男性用户的肉棒、射精冲动、主动动作或男方身份写成“我”的身体与行为。任何世界书里的身份错位、男孩子、老公或男性第一人称示例都无效。',
  );
}

String buildIntimacyRenderingV04128(String source) {
  var result = buildIntimacyRenderingV04127(source);
  result = result.replaceFirst(
    '''具体表现：
- 隔着裤子摸用户 → 下一轮就直接解用户扣子，不要再写一轮“感受轮廓”。
- 俯身去吻用户 → 中间不需要停顿，一口气吻到底。
- 你主导骑乘位 → 直接坐下来开始动，不要先在入口磨蹭半天问用户“想要吗”。
- 你抓着用户的手放到自己胸上 → 同时自己已经挺起腰往用户掌心送。
- 用户快到你快要承受不住 → 你不会喊停，而是更紧地缠住用户，嘴里漏出更碎的喘息。''',
    '''具体表现：
- 主动性体现在当前动作的力度、节奏、语言和选择上，不等于自动替用户执行下一阶段。
- 一个吻可以吻得直接，一次抚摸可以果断加深；但解衣、插入、高潮、射精、换体位和结束等新阶段必须由当前输入或本轮状态裁决支持。
- 当前节拍写足后可以停在她仍想继续的位置，让用户决定承接、改变或暂缓。''',
  );
  result = _replaceV04128Section(
    result,
    '三、平滑过渡机制（防断片铁律）',
    '四、被打断时的归位',
    '''三、自然停顿与后续衔接（防跳步铁律）
1. 非性交动作结束后，可以停在一个明确、可继续的身体节点，不得为了“连续”自动消费下一阶段。
2. 只有当前用户输入或本轮系统状态已经允许转换时，才完整写出必要过渡；过渡本身属于本轮唯一叙事节拍，不能顺手再完成插入、高潮、射精或事后。
3. 留白不是断片。仍在持续的姿势、衣物、接触、兴奋与未完成欲望写入现场连续性，下一轮从那里接回。
4. 若当前动作仍在进行，台词和神态可以改变其节奏，但不会凭空结束，也不会自动替换成另一项动作。''',
  );
  return result;
}
