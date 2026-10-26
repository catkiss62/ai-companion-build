/// Only direct conversation and continuing that conversation share a direction.
/// Ambiguity is not permission to invent a low-probability watching answer.
abstract final class QqGroupParticipation {
  static const options = <String,String>{
    'direct':'群成员正在对她说话、问她、叫她，或围绕她期待她本人回应。',
    'continuing':'正在接她最近的话、回应她的问题或继续与她玩笑，适合连续回应。',
    'join':'大家在彼此聊天，但她可以自然加入、接梗、复读或发表情包。',
    'watch':'当前适合旁听，话题与她的参与无关或已经转开。',
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
