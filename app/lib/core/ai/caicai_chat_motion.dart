import 'dart:convert';
import '../database/app_database.dart';
import '../../widgets/caicai_live2d_stage.dart';
import 'caicai_motion_planner.dart';
import 'generation_cancellation.dart';

/// One presentation owner; a late plan cannot animate a newer reply or a closed stage.
class CaicaiChatMotion {
  GenerationCancellationToken? _token;
  String? _lastMessage;
  Map<String, Object?>? _owner;
  Future<void> stop() async {
    _token?.cancel();
    _token = null;
    final owner = _owner;
    _owner = null;
    if (owner != null) {
      try { await CaicaiLive2DService.command('stopMotion', {'_motion_owner': owner}); } catch (_) { }
    }
  }
  Future<void> present({required String id, required String user, required String reply, required String emotion}) async {
    if (_lastMessage == id) return;
    _lastMessage = id;
    _token?.cancel();
    final token = GenerationCancellationToken();
    _token = token;
    try {
      final claimed = await CaicaiLive2DService.command('claimMotion');
      if (claimed is! Map) return;
      final owner = Map<String, Object?>.from(claimed);
      if (token.isCancelled) {
        await CaicaiLive2DService.command('stopMotion', {'_motion_owner': owner});
        return;
      }
      _owner = owner;
      token.throwIfCancelled();
      await CaicaiLive2DService.command('setEmotion', {'event':id,'emotion':CaicaiLive2DService.nativeEmotionId(emotion), '_motion_owner': owner});
      token.throwIfCancelled();
      if (await AppDatabase.instance.getSetting('caicai_jev_motion') == '0') return;
      token.throwIfCancelled();
      final raw = await CaicaiLive2DService.command('parameters');
      token.throwIfCancelled();
      if (raw is! String) return;
      final parameters = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final plan = await const CaicaiMotionPlanner().plan(user: user, reply: reply, emotion: emotion,
        parameters: parameters, cancellationToken: token);
      token.throwIfCancelled();
      if (plan != null) {
        final chosenEmotion = plan['emotion']?.toString() ?? '';
        if (chosenEmotion.isNotEmpty) {
          await CaicaiLive2DService.command('setEmotion', {'event':id,'emotion':chosenEmotion, '_motion_owner': owner});
        }
        token.throwIfCancelled();
        await CaicaiLive2DService.command('motionPlan', {...plan, '_motion_owner': owner});
      }
    } on GenerationCancelledByUserException {
      return;
    } catch (_) {
      // Cosmetic planning never blocks conversation or purchases a second model call.
    }
  }
}
