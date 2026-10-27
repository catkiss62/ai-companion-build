/// Only direct conversation and continuing that conversation share a direction.
/// Ambiguity is not permission to invent a low-probability watching answer.
abstract final class QqGroupParticipation {
  static const options = <String,String>{
    'direct':'群成员正在对她说话、问她、叫她，或当前话题就在讨论她本人、她刚说/做的事，适合她参与回应。',
    'continuing':'正在接她最近的话、回应她的问题或继续与她玩笑；包括有人接住她刚插的一句话聊起来，适合连续回应。',
    'join':'群友主要在彼此聊天，她对当前话题有自然反应、联想、好奇、玩笑或想补一句，可以主动加入；接梗、复读或表情包也算，不要求有用或专业。',
    'watch':'此刻更想听大家说，没有想接的话，或大家正密集互聊而她暂时不想打断；是自然选择，不是所有非直接对话的默认答案。',
  };

  static String resolve(Map<String,double> scores) {
    final direct=scores['direct']??0, continuing=scores['continuing']??0;
    final active=direct+continuing, join=scores['join']??0, watch=scores['watch']??0;
    if(active<=0 && join<=0 && watch<=0) throw const FormatException('Empty participation probabilities');
    if(active>=join && active>=watch && active>0) return direct>=continuing?'direct':'continuing';
    return join>=watch && join>0?'join':'watch';
  }

  static bool addressed(String route,{required bool mentioned})=>
    mentioned || route=='direct' || route=='continuing';
}
