import '../grounding/information_seeking_question_guard.dart';
import '../models/thought.dart';
import 'conversation_initiative_policy.dart';

class ConversationExpressionVerification {
  const ConversationExpressionVerification({
    required this.plannedSpeechAct,
    required this.expressedSpeechAct,
    required this.informationRequestExpressed,
    required this.plannedActExpressed,
    required this.sourceThoughtExpressed,
    required this.hadAiBid,
    required this.allowed,
    required this.reason,
  });

  final String plannedSpeechAct;
  final String expressedSpeechAct;
  final bool informationRequestExpressed;
  final bool plannedActExpressed;
  final bool sourceThoughtExpressed;
  final bool hadAiBid;
  final bool allowed;
  final String reason;

  bool get shouldMarkThoughtActed => hadAiBid && sourceThoughtExpressed;
}

/// Converts a generation-time intention into a conservative, content-free
/// statement about what the final answer actually did.
///
/// The verifier does not persist or return message/Thought text. It deliberately
/// prefers a false negative over marking an unspoken Thought as acted and then
/// applying satisfaction to it on the next user turn.
class ConversationOutcomeVerifier {
  const ConversationOutcomeVerifier._();

  static const _teaseMarkers = <String>{
    '难道',
    '该不会',
    '不会吧',
    '莫非',
    '笑死',
    '活该',
    '有本事',
    '小笨蛋',
    '笨蛋',
    '傻瓜',
    '蠢货',
    '啧',
    '哼',
  };
  static const _attentionMarkers = <String>{
    '陪我',
    '理我',
    '看我',
    '听我的',
    '叫我',
    '哄我',
    '抱我',
    '亲我',
    '别走',
    '不许跑',
    '给我回来',
    '来找我',
    '找我聊',
  };
  static const _inviteMarkers = <String>{
    '一起',
    '我们来',
    '陪我玩',
    '跟我去',
    '来陪我',
    '咱们',
  };
  static const _needMarkers = <String>{
    '我想要',
    '我需要',
    '我好累',
    '我累了',
    '我烦了',
    '我不想',
    '想被',
    '要你',
    '需要你',
    '我困',
    '我累',
    '我饿',
    '我疼',
    '我难受',
    '我不舒服',
    '我紧张',
    '我烦',
    '我委屈',
    '我生气',
    '我害怕',
    '我想睡',
    '我得睡',
    '我要睡',
    '我也睡',
    '让我睡',
    '别吵我',
    '折腾我',
    '放过我',
    '哄哄我',
    '想休息',
    '要休息',
    '困意',
    '打哈欠',
    '睁不开眼',
    '声音发飘',
  };
  static const _selfMarkers = <String>{
    '我觉得',
    '我想到',
    '我想起',
    '我发现',
    '我更喜欢',
    '我不喜欢',
    '对我来说',
    '我的看法',
  };
  static ConversationExpressionVerification verify({
    required String finalText,
    required ConversationInitiativePlan plan,
    CompanionThought? sourceThought,
    bool sourceExpressionConfirmed = false,
  }) {
    final question = InformationSeekingQuestionGuard.evaluate(
      text: finalText,
      askAuthorized: plan.askAuthorized,
    );
    // Only a semantic check of this final visible reply can settle a Thought.
    // A proposed topic, generic source text or character overlap is not proof.
    final sourceMatched = sourceThought != null && sourceExpressionConfirmed;
    final plannedActExpressed = switch (plan.speechAct) {
      ConversationSpeechAct.ask => question.hasInformationRequest,
      ConversationSpeechAct.selfShare => sourceThought == null
          ? _containsAny(finalText, _selfMarkers)
          : sourceMatched,
      ConversationSpeechAct.tease =>
        question.hasRhetoricalQuestion || _containsAny(finalText, _teaseMarkers),
      ConversationSpeechAct.seekAttention =>
        _containsAny(finalText, _attentionMarkers),
      ConversationSpeechAct.invite => _containsAny(finalText, _inviteMarkers),
      ConversationSpeechAct.showNeed => _containsAny(finalText, _needMarkers),
      ConversationSpeechAct.answer ||
      ConversationSpeechAct.react ||
      ConversationSpeechAct.pauseOrClose => false,
    };
    final hadAiBid = plan.hadAiBid && plannedActExpressed;
    final sourceThoughtExpressed =
        sourceThought != null && hadAiBid && sourceMatched;
    final askSourceMismatch = plan.speechAct == ConversationSpeechAct.ask &&
        question.hasInformationRequest &&
        !sourceThoughtExpressed;
    final expressedSpeechAct = plannedActExpressed
        ? plan.speechAct.key
        : question.hasRhetoricalQuestion
            ? ConversationSpeechAct.tease.key
            : ConversationSpeechAct.react.key;
    final reason = askSourceMismatch
        ? 'ask_source_mismatch'
        : plan.hadAiBid && !plannedActExpressed
            ? 'planned_bid_not_expressed'
            : sourceThought != null && hadAiBid && !sourceThoughtExpressed
                ? 'source_thought_not_expressed'
                : hadAiBid
                    ? 'expressed_match'
                    : 'no_expressed_bid';
    return ConversationExpressionVerification(
      plannedSpeechAct: plan.speechAct.key,
      expressedSpeechAct: expressedSpeechAct,
      informationRequestExpressed: question.hasInformationRequest,
      plannedActExpressed: plannedActExpressed,
      sourceThoughtExpressed: sourceThoughtExpressed,
      hadAiBid: hadAiBid,
      allowed: !askSourceMismatch,
      reason: reason,
    );
  }

  static bool _containsAny(String text, Set<String> markers) =>
      markers.any(text.contains);

}
