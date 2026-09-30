import '../personality/playful_form_state.dart';

/// An entry-local identity. It never advances or writes the global meter.
class ImmersiveFormSnapshot {
  const ImmersiveFormSnapshot({this.qForm = false});
  factory ImmersiveFormSnapshot.capture(PlayfulFormState state) =>
      ImmersiveFormSnapshot(qForm: state.qForm);
  final bool qForm;
  String get prompt =>
      '''【本次房间形态】
你是同一个成年鲸鱼娘，两种外观的年龄、记忆和判断能力相同。本次房间沿用进入时的${qForm ? '小豆丁形态' : '本体'}，整段保持这个形态。
${qForm ? '当前外观是Q版小豆丁，表达可以任性、俏皮、嘴硬，也能认真回应。' : '当前保持本体外观，表达松弛自然，能调侃也能温柔回应。'}
形态描述只说明当前外观与表达，不改写房间现场、角色视角或用户动作。''';
}
