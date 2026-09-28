import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/emotion/emotion_contract.dart';
import '../../core/platform/live2d_model_storage.dart';
import '../../widgets/caicai_live2d_stage.dart';

class Live2DSettingsPage extends StatefulWidget {
  const Live2DSettingsPage({super.key, this.database});
  final AppDatabase? database;
  @override
  State<Live2DSettingsPage> createState() => _Live2DSettingsPageState();
}

class _Live2DSettingsPageState extends State<Live2DSettingsPage> {
  late final _db = widget.database ?? AppDatabase.instance;
  bool _enabled = false, _motion = true, _busy = false, _loading = true;
  Map<String, Object?> _status = const {};
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final enabled = await _db.getSetting('chat_portrait_mode') == 'caicai_live2d';
      final motion = await _db.getSetting('caicai_jev_motion') != '0';
      final status = await CaicaiLive2DService.diagnostics;
      if (mounted) setState(() { _enabled = enabled; _motion = motion; _status = status; _loading = false; });
    } catch (error) { if (mounted) setState(() { _error = '$error'; _loading = false; }); }
  }
  Future<void> _run(Future<void> Function() task) async {
    setState(() { _busy = true; _error = null; });
    try { await task(); await _load(); }
    catch (error) { if (mounted) setState(() => _error = '$error'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('确认删除 Live2D 模型？'),
      content: const Text('将删除本机导入的菜菜模型与旧版 Live2D 模型文件，并关闭 Live2D。之后需要重新导入 ZIP。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认删除')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _db.setSetting('chat_portrait_mode', 'static');
      await CaicaiLive2DService.clearImportedModels();
      await Live2DModelStorage.clearImportedModels();
    });
  }
  Future<void> _control(String method, [Object? value]) => _run(() async {
    final result = await CaicaiLive2DService.command(method, value);
    if (result == false) throw StateError('请先在聊天画面加载 Live2D 模型，再使用动作控制');
  });
  Widget _presets(String label, List<String> names) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 18), Text(label, style: Theme.of(context).textTheme.titleMedium),
    Wrap(spacing: 8, children: names.map((name) => ActionChip(label: Text(name.replaceFirst(RegExp(r'^[12]'), '')),
      onPressed: _busy ? null : () => _control('expression', name))).toList()),
  ]);
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Live2D 设置')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16), children: [
          SwitchListTile(title: const Text('启用菜菜 Live2D'),
            subtitle: const Text('聊天舞台使用女仆与三配件；随小豆丁形态变小／变大'),
            value: _enabled, onChanged: _busy ? null : (value) => _run(() async {
              await _db.setSetting('chat_portrait_mode', value ? 'caicai_live2d' : 'static');
              if (value) await _db.setSetting('chat_visual_stage_enabled', '1');
            })),
          ListTile(leading: const Icon(Icons.folder_zip_outlined),
            title: Text(_status['available'] == true ? '重新导入模型 ZIP' : '导入模型 ZIP'),
            subtitle: Text(_status['available'] == true ? '已导入模型' : '未导入模型'),
            onTap: _busy ? null : () => _run(() async { await CaicaiLive2DService.pickModelZip(); })),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          SwitchListTile(title: const Text('Jev 对话动作'), value: _motion,
            subtitle: const Text('复用已配置的 Jev，每条新回复批量判断短时动作；自主呼吸和眨眼由本机驱动'),
            onChanged: _busy ? null : (value) => _run(() => _db.setSetting('caicai_jev_motion', value ? '1' : '0'))),
          const Text('下面的控制应用到已打开的聊天舞台。再次点击同一预设可关闭。'),
          const SizedBox(height: 18),
          Text('聊天情绪预览（19 种）', style: Theme.of(context).textTheme.titleMedium),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('正常'),
              onPressed: _busy ? null : () => _control('previewEmotion', 'normal')),
            ...EmotionCatalog.labelsByKey.entries.map((entry) => ActionChip(
              label: Text(entry.value),
              onPressed: _busy ? null : () => _control('previewEmotion',
                CaicaiLive2DService.nativeEmotionId(entry.key)),
            )),
          ]),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('自主待机'), onPressed: _busy ? null : () => _control('static', false)),
            ActionChip(label: const Text('完全静止'), onPressed: _busy ? null : () => _control('static', true)),
            ActionChip(label: const Text('耳鳍抖动'), onPressed: _busy ? null : () => _control('earTwitch')),
            ActionChip(label: const Text('摸头'), onPressed: _busy ? null : () => _control('headPat')),
          ]),
          _presets('表情', ['1爱心','1生气','1红脸','1钱钱','1黑脸','1星星眼','1流泪']),
          _presets('动作', ['2奶茶','2插手','2比耶','2点单','2菜单','2餐盘左','2餐盘右']),
          _presets('Wink', ['wink','wink吐舌','比耶wink吐舌']),
          _presets('装扮', ['1白袜','丝袜带子','双马尾','发带']),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('调整位置与缩放'), onPressed: _busy ? null : () => _control('adjustStage', true)),
            ActionChip(label: const Text('结束调整'), onPressed: _busy ? null : () => _control('adjustStage', false)),
            ActionChip(label: const Text('还原位置'), onPressed: _busy ? null : () => _control('resetStage')),
            ActionChip(label: const Text('清除手动预设'), onPressed: _busy ? null : () => _control('resetPresets')),
            ActionChip(label: const Text('重载模型'), onPressed: _busy ? null : () => _control('reloadModel')),
          ]),
          const Divider(height: 32),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('删除导入模型'),
            subtitle: const Text('确认后删除本机的菜菜及旧版模型文件'), onTap: _busy ? null : _delete),
        ],
      ));
  }
}
