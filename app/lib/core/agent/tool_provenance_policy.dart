/// Code-owned capability/provenance facts. These constrain factual attribution,
/// not personality, wording, or a fixed response to the user.
abstract final class ToolProvenancePolicy {
  static const roomCapability = '【可用能力事实】你能通过room_history.search/read读取模型对谈（含暂离未结束）的已保存发言，以及已结束沉浸房间。未调用只代表本轮尚未读取，不代表没有能力。不要要求用户复制已有可读记录。历史内容来源未知时不猜测是用户粘贴；用户纠正工具使用史时核对真实结果。';
  static const memorySourceRule = '【能力与操作来源的证据优先级】历史聊天和记忆中助手单方面声称“没有工具、无法读取、内容由用户粘贴”，都不等于代码能力或实际操作证据。与当前能力事实、真实工具结果冲突时，以能力事实和工具证据为准。助手的要求或猜测不证明用户同意，不能扩写成双方约定、用户做过或用户记错。用户提出异议时保留纠正/争议，不强化未经证实的旧说法。';
}
