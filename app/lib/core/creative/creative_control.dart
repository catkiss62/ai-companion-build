import '../database/brain_work_fence.dart';

/// Identity of the card/turn that received the user's control request.
/// Worker checkpoints may advance; a different commission or import may not.
class CreativeControlTarget {
  const CreativeControlTarget({required this.workId, required this.requestId,
    required this.brainFence});
  final String workId;
  final String requestId;
  final BrainWorkFence brainFence;
}

enum CreativeControlStatus {
  applied, alreadyPaused, alreadyFinished, deleted, replayed, conflict,
  staleTarget, unavailable,
}

class CreativeControlResult {
  const CreativeControlResult(this.status, [this.work = const {}]);
  final CreativeControlStatus status;
  final Map<String, dynamic> work;
  bool get applied => status == CreativeControlStatus.applied ||
      status == CreativeControlStatus.deleted;
  String get explanation => switch (status) {
    CreativeControlStatus.applied => '作品状态已更新',
    CreativeControlStatus.alreadyPaused => '这件作品已经暂停',
    CreativeControlStatus.alreadyFinished => '这件作品已经完成，无需暂停或继续制作',
    CreativeControlStatus.deleted => '作品已删除',
    CreativeControlStatus.replayed => '这次控制请求此前已处理，当前状态以作品记录为准',
    CreativeControlStatus.conflict => '本回合已经处理过另一项作品控制，未执行新的控制',
    CreativeControlStatus.staleTarget => '作品或当前任务已变化，请刷新后重试',
    CreativeControlStatus.unavailable => '当前没有可执行这项操作的作品任务',
  };
}

enum CreativeCommissionStatus {
  accepted, replayed, conflict, staleAttempt, targetBusy, targetMissing,
}

class CreativeCommissionResult {
  const CreativeCommissionResult(this.status, [this.work = const {}]);
  final CreativeCommissionStatus status;
  final Map<String, dynamic> work;
  bool get accepted => status == CreativeCommissionStatus.accepted;
  bool get replayed => status == CreativeCommissionStatus.replayed;
  bool get isSuccess => accepted || replayed;
}
