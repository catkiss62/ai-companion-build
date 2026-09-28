import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/ai/caicai_motion_planner.dart';
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
  double _gain=1, _speed=1, _pivot=.88;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final enabled = await _db.getSetting('chat_portrait_mode') == 'caicai_live2d';
      final motion = await _db.getSetting('caicai_jev_motion') != '0';
      final status = await CaicaiLive2DService.diagnostics;
      final tuning = await CaicaiLive2DService.command('getMotionTuning');
      if (tuning is Map) {
        _gain=(tuning['gain'] as num?)?.toDouble() ?? 1;
        _speed=(tuning['speed'] as num?)?.toDouble() ?? 1;
        _pivot=(tuning['pivot'] as num?)?.toDouble() ?? .88;
      }
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
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  });
  Future<void> _edit(String mode) => _run(() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final state = await CaicaiLive2DService.command('beginEdit');
    if (state is! Map) throw StateError('请先在聊天画面加载模型');
    CaicaiLive2DService.editor.value = {'mode': mode, 'state': state};
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  });
  Future<void> _saveTuning() => _run(() async {
    await CaicaiLive2DService.command('setMotionTuning', {'gain':_gain,'speed':_speed,'pivot':_pivot});
  });
  Future<void> _previewRoot(String root, String head) => _run(() async {
    final raw=await CaicaiLive2DService.command('parameters');
    final parameters=raw is String ? (jsonDecode(raw) as Map).cast<String,dynamic>() : <String,dynamic>{};
    if (parameters.isEmpty) throw StateError('请先在聊天画面加载模型');
    final answers=<String,String>{'tempo':'明快',
      'f0_root':root,'f1_root':root,'f0_head':head,'f1_head':head,
      'f0_body':'兴奋踮起','f1_body':'轻轻下压'};
    await CaicaiLive2DService.command('static',false);
    await CaicaiLive2DService.command('motionPlan',CaicaiMotionPlanner.buildPlan(answers,parameters));
    if (mounted) Navigator.of(context).popUntil((route)=>route.isFirst);
  });
  Widget _tuner(String label,double value,double min,double max,ValueChanged<double> change) => Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label),Slider(value:value.clamp(min,max).toDouble(),
      min:min,max:max,onChanged:_busy?null:change,onChangeEnd:(_)=>_saveTuning())]);
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
              if (value) {
                await _db.setSetting('chat_visual_stage_enabled', '1');
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              }
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
          const Text('点击后返回聊天查看。原装临时表情和动作 4.5 秒后结束；装扮及聊天情绪保持。'),
          const SizedBox(height: 16),
          const Text('表演调节：默认鲜明、明快；幅度仍受模型自身范围限制。'),
          _tuner('头身与整模幅度 · ${(_gain*100).round()}%',_gain,.5,1.5,(v)=>setState(()=>_gain=v)),
          _tuner('待机与动作速度 · ${(_speed*100).round()}%',_speed,.65,1.6,(v)=>setState(()=>_speed=v)),
          _tuner('倾斜支点 · 从模型顶部向下 ${(_pivot*100).round()}%',_pivot,.65,.98,(v)=>setState(()=>_pivot=v)),
          Wrap(spacing:8,children:[
            for(final pair in const {'向左探身':'左侧头','向右探身':'右侧头',
              '小腿支点左倾':'右歪头','小腿支点右倾':'左歪头'}.entries)
              ActionChip(label:Text(pair.key),onPressed:_busy?null:()=>_previewRoot(pair.key,pair.value)),
          ]),
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
            ActionChip(label: const Text('调整位置与缩放'), onPressed: _busy ? null : () => _edit('stage')),
            ActionChip(label: const Text('调整摸头区域'), onPressed: _busy ? null : () => _edit('head')),
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
