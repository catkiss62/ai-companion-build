/// A control event saved in the room transcript, never user dialogue.
abstract final class ImmersiveSceneAdvance {
  static const marker = '【房间操作：推进剧情】';
  static const instruction = '''【房间操作：推进剧情】
这是界面的操作指令，不是用户说的话，也不代表用户行动或同意。沿用房间当前场景、关系、前文与未解决的细节，让她及环境自然推进一个叙事节拍；可由她主动说话或行动，在需要用户选择时停下。不要替用户编造台词、主动动作、态度、决定或同意，也不要突然跳时空或重复上一段。直接写沉浸正文。''';

  static bool isMarker(String content) => content == marker;
}
