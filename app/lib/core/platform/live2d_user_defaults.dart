import 'dart:convert';
import '../database/app_database.dart';
import '../../widgets/caicai_live2d_stage.dart';

abstract final class Live2DUserDefaults {
  static String key(String profile) => 'live2d_user_defaults_v1:$profile';

  static Future<void> finish(AppDatabase db, String profile, String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['version'] != 1 || data['profile'] != profile ||
        data['settings'] is! Map || (profile == 'caicai' && data['jev'] is! bool)) {
      throw const FormatException('保存状态格式无效');
    }
    if (CaicaiLive2DService.activeProfile != profile ||
        await CaicaiLive2DService.command('restoreAvatarDefaults', data['settings']) != true) {
      throw StateError('当前模型无法恢复，请稍后重试');
    }
    final pending = '${key(profile)}:restoring';
    final committed = await db.setSettingsAtomically({
      pending:'',
      if (profile == 'caicai') 'caicai_jev_motion': data['jev'] == true ? '1' : '0',
    },guardKey:pending,expectedGuardValue:raw);
    if (!committed) throw StateError('恢复期间存档发生变化');
  }

  static Future<void> resumeAtStartup(AppDatabase db) async {
    final pending = <String,String>{};
    for (final profile in ['caicai','deepseek-avatar']) {
      final value = await db.getSetting('${key(profile)}:restoring');
      if (value != null && value.isNotEmpty) pending[profile] = value;
    }
    if (pending.isEmpty) return;
    final status = await CaicaiLive2DService.diagnostics;
    final profile = status['profile'] as String? ?? 'caicai';
    final value = pending[profile];
    if (value != null) await finish(db,profile,value);
  }
}
