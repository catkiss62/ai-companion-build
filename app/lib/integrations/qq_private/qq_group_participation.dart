/// Only direct conversation and continuing that conversation share a direction.
/// Ambiguity is not permission to invent a low-probability watching answer.
abstract final class QqGroupParticipation {
  static const options = <String,String>{
    'direct':'群成员正在对她说话、问她、叫她，或当前话题就在讨论她本人、她刚说/做的事，适合她参与回应。',
    'continuing':'正在接她最近的话、回应她的问题或继续与她玩笑；包括有人接住她刚插的一句话聊起来，适合连续回应。',
    'join':'大家主要在彼此聊其他话题，此刻她确实想偶尔插一两句、接梗、复读或发表情包；能回答这个话题不等于需要加入。',
    'watch':'群友彼此聊与她无关的话题，没有接她的话或期待她回应，通常自然旁听；话题已转开时也可旁听。',
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
