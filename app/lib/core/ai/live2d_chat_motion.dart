import '../../widgets/caicai_live2d_stage.dart';
import 'caicai_chat_motion.dart';
import 'deepseek_chat_motion.dart';

/// Stage dispatch only; each avatar retains its own planner and playback owner.
class Live2dChatMotion {
  final _caicai = CaicaiChatMotion();
  final _deepseek = DeepseekChatMotion();
  bool get _isDeepseek => CaicaiLive2DService.activeProfile == 'deepseek-avatar';
  Future<void> stop() async { await Future.wait([_caicai.stop(), _deepseek.stop()]); }
  void playbackChanged({required String? ownerId, required bool running}) {
    _caicai.playbackChanged(ownerId: ownerId, running: running);
    _deepseek.playbackChanged(ownerId: ownerId, running: running);
  }
  Future<void> present({required String id, required String user, required String reply,
      required String emotion, int revision = 0, bool Function()? canContinue}) async {
    if (_isDeepseek) {
      await _caicai.stop();
      if (!_isDeepseek) return;
      await _deepseek.present(id: id, user: user, reply: reply, emotion: emotion,
        revision: revision, canContinue: canContinue);
    } else {
      await _deepseek.stop();
      if (_isDeepseek) return;
      await _caicai.present(id: id, user: user, reply: reply, emotion: emotion,
        revision: revision, canContinue: canContinue);
    }
  }
  Future<void> resume({required String id, required String reply, required int revision,
      bool Function()? canContinue}) => _isDeepseek
      ? _deepseek.resume(id: id, reply: reply, revision: revision, canContinue: canContinue)
      : _caicai.resume(id: id, reply: reply, revision: revision, canContinue: canContinue);
}
