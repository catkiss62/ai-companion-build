import 'dart:convert';
import '../../core/ai/deepseek_motion_planner.dart';
import '../../core/emotion/emotion_contract.dart';
import 'package:flutter/material.dart';
import '../../widgets/caicai_live2d_stage.dart';

/// First-stage controls use the actual Core parameter bounds, not CDI guesses.
class DeepseekCalibrationControls extends StatefulWidget {
  const DeepseekCalibrationControls({super.key, required this.status,
    required this.busy, required this.run, required this.preview});
  final Map<String, Object?> status;
  final bool busy;
  final Future<void> Function(Future<void> Function()) run;
  final Future<void> Function(String, [Object?]) preview;
  @override
  State<DeepseekCalibrationControls> createState() => _DeepseekCalibrationControlsState();
}

class _DeepseekCalibrationControlsState extends State<DeepseekCalibrationControls> {
  double? _smallPreview;
  static const labels = {
    'AngleX':'左右转头', 'AngleY':'低头／仰头', 'AngleZ':'左右歪头',
    'PositionX':'左右侧身', 'PositionY':'身体起伏', 'PositionZ':'身体侧摆',
    'LeanInput':'前倾', 'EyeSmile':'眼睛微笑', 'ParamEyeBallX':'视线左右',
    'ParamEyeBallY':'视线上下', 'BrowInnerUp':'眉心上抬',
    'ParamEyeROpen':'角色右眼开闭', 'ParamEyeLOpen':'角色左眼开闭',
    'ParamBrowRY':'角色右眉上下', 'ParamBrowLY':'角色左眉上下',
    'REyeSquint':'角色右眼眯笑', 'LEyeSquint':'角色左眼眯笑',
    'ParamMouthForm':'嘴变形', 'ParamMouthOpenY':'嘴张合', 'JawOpen':'下巴开闭',
    'TongueOut':'伸舌头', 'MouthX':'歪嘴', 'Mouthpucker':'撅嘴',
    'MouthFunnel':'微张露齿', 'MouthPuckerWiden':'嘴宽窄', 'CheeckPuff':'鼓脸',
  };
  Map<String, Object?> get appearance => Map<String, Object?>.from(
    widget.status['deepseek_appearance'] as Map? ?? const {});
  Map<String, Object?> get stage => Map<String, Object?>.from(
    widget.status['deepseek_stage'] as Map? ?? const {});
  Future<void> _save(Map<String, Object?> values) => widget.run(() async {
    final ok = await CaicaiLive2DService.command('setDeepseekAppearance', values);
    if (ok != true) throw StateError('请先启用DeepSeek并返回聊天加载模型');
  });
  Future<void> _parameter() => widget.run(() async {
    final raw = await CaicaiLive2DService.command('parameters');
    final data = raw is String ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : <String, dynamic>{};
    final ids = labels.keys.where(data.containsKey).toList();
    if (ids.isEmpty) throw StateError('请先启用DeepSeek并返回聊天加载模型');
    if (!mounted) return;
    var selected = ids.first;
    double value = (data[selected]['default'] as num).toDouble();
    final values = <String, double>{};
    final accepted = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final bounds = data[selected] as Map;
        final min = (bounds['min'] as num).toDouble(), max = (bounds['max'] as num).toDouble();
        return AlertDialog(title: const Text('单轴预览'), content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButton<String>(isExpanded: true, value: selected,
            items: ids.map((id) => DropdownMenuItem(value: id, child: Text(labels[id]!))).toList(),
            onChanged: (id) { if (id != null) update(() {
              selected = id; value = values[id] ?? (data[id]['default'] as num).toDouble();
            }); }),
          Text('${value.toStringAsFixed(2)}  范围 $min～$max'),
          if (max > min) Slider(value: value.clamp(min,max).toDouble(), min:min, max:max,
            onChanged:(v) => update(() { value=v; values[selected]=v; })),
          const Text('可组合多个参数。这里只预览，不保存为默认表情。'),
        ]), actions: [
          TextButton(onPressed:() => Navigator.pop(context,false),child:const Text('取消')),
          FilledButton(onPressed:() { values[selected]=value; Navigator.pop(context,true); },child:const Text('预览')),
        ]);
      }));
    if (accepted == true) await widget.preview('previewParameters', values);
  });
  Future<void> _anchor() => widget.run(() async {
    var x=(stage['anchorX'] as num?)?.toDouble() ?? .5;
    var y=(stage['anchorY'] as num?)?.toDouble() ?? .21504237;
    if (!mounted) return;
    final accepted=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
      title:const Text('变身中心'),content:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('选择颈部／领口附近的位置。横向从左向右，纵向从模型顶部向下。'),
        Text('横向 ${(x*100).round()}%'),Slider(value:x,min:0,max:1,onChanged:(v)=>update(()=>x=v)),
        Text('纵向 ${(y*100).round()}%'),Slider(value:y,min:0,max:1,onChanged:(v)=>update(()=>y=v)),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('取消')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('保存'))])));
    if(accepted==true) {
      final ok=await CaicaiLive2DService.command('setMorphAnchor',{'x':x,'y':y});
      if(ok!=true) throw StateError('请先返回聊天加载DeepSeek模型');
    }
  });
  Future<void> _combination() async {
    var face='',wink='',comic='';
    final effects=<String>{};
    if(!mounted) return;
    final accepted=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(
      builder:(context,update)=>AlertDialog(title:const Text('表情叠加预览'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('眼型保留眨眼、眉毛与嘴形。附加效果可多选；兔牙与吐舌wink冲突时保留wink。'),
          Wrap(spacing:6,children:[for(final name in DeepseekMotionPlanner.eyes.keys)
            FilterChip(label:Text(name),selected:face==name,onSelected:(v)=>update(()=>face=v?name:''))]),
          Wrap(spacing:6,children:[for(final name in DeepseekMotionPlanner.winks.keys)
            FilterChip(label:Text(name),selected:wink==name,onSelected:(v)=>update(()=>wink=v?name:''))]),
          Wrap(spacing:6,children:[for(final name in DeepseekMotionPlanner.effects.keys)
            FilterChip(label:Text(name),selected:effects.contains(name),onSelected:(v)=>update(() {if(v) {effects.add(name);} else {effects.remove(name);}}))]),
          FilterChip(label:const Text('装懂小老师（眼镜＋兔牙）'),selected:comic.isNotEmpty,
            onSelected:(v)=>update(()=>comic=v?'装懂小老师':'')),
        ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('取消')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('预览'))])));
    if(accepted==true) await widget.preview('previewDeepseekPerformance',
      {'face':face,'wink':wink,'effects':effects.toList(),'comic':comic});
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('DeepSeek独立表情与手势：临时预览不会保存成装扮。手势自动完成抬臂、保持和放下。'),
    const Text('原分辨率 · 目标60FPS · 高精度蒙版512px'),
    const Text('本机待机含呼吸、眨眼和随机头身动作，偶尔拿起狗尾草；触摸或鼠标可引导眼睛、头部和身体。'),
    Wrap(spacing:8,children:[
      ActionChip(label:const Text('前倾贴近预览'),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',
        DeepseekMotionPlanner.buildPlan({'lean_use':'yes','lean_moment':'f0'},
          {'LeanInput':{'min':-30,'max':30}}))),
      ActionChip(label:const Text('自主待机'),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekIdle',false)),
      ActionChip(label:const Text('狗尾草待机预览'),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekIdle',true)),
      ActionChip(label:const Text('完全静止'),onPressed:widget.busy?null:()=>widget.preview('static',true)),
      ActionChip(label:const Text('摸头'),onPressed:widget.busy?null:()=>widget.preview('deepseekHeadPat')),
      ActionChip(label:const Text('摸头彩蛋预览'),onPressed:widget.busy?null:()=>widget.preview('deepseekHeadPatRare')),
    ]),
    const Text('在摸头区域连续滑动后可按住，松开淡出；偶尔会歪头露出疑惑表情。摸头区域和其他设置分别保存。'),
    SwitchListTile(title:const Text('DeepSeek Jev 对话动作'),
      subtitle:const Text('独立四拍与真实语音分段表演；不影响菜菜开关'),
      value:(widget.status['deepseek_motion'] as Map?)?['jevEnabled'] != false,
      onChanged:widget.busy?null:(value)=>widget.run(() async {
        final ok=await CaicaiLive2DService.command('setDeepseekJev',value);
        if(ok!=true) throw StateError('无法保存DeepSeek动作设置');
      })),
    ExpansionTile(title:const Text('表情与手势预览'),children:[
      const Text('角色左右眼与屏幕相反。不同眼型互斥，眨眼、眉嘴和附加效果可组合；语音接管嘴巴张合。'),
      Wrap(spacing:8,children:[
        ActionChip(label:const Text('表情叠加预览'),onPressed:widget.busy?null:_combination),
        ActionChip(label:const Text('装懂小老师'),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',{'comic':'装懂小老师'})),
        for(final name in [...DeepseekMotionPlanner.eyes.keys,...DeepseekMotionPlanner.effects.keys])
          ActionChip(label:Text(name),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',{'face':name})),
        for(final name in DeepseekMotionPlanner.winks.keys)
          ActionChip(label:Text(name),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',{'wink':name})),
        for(final name in DeepseekMotionPlanner.actions.keys.where((x)=>x!='无'))
          ActionChip(label:Text(name),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',{'action':name})),
        ActionChip(label:const Text('清除临时表演'),onPressed:widget.busy?null:()=>widget.preview('resetPresets')),
      ]),
      Wrap(spacing:8,children:[for(final e in DeepseekMotionPlanner.mouthPreviews.entries)
        ActionChip(label:Text(e.key),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',
          {'frames':[{'time':0,'duration':.5,'parameters':e.value},
            {'time':3.3,'duration':.6,'parameters':<String,double>{}}]}))]),
    ]),
    ExpansionTile(title:const Text('19种情绪预览'),children:[Wrap(spacing:8,children:[
      for(final e in {'normal':'正常',...EmotionCatalog.labelsByKey}.entries)
        ActionChip(label:Text(e.value),onPressed:widget.busy?null:()=>widget.preview('previewDeepseekPerformance',
          {'emotion':CaicaiLive2DService.nativeEmotionId(e.key)})),
    ])]),
    for(final item in const {'key11':'黑框眼镜','key12':'单片眼镜','Clothes4':'脱鞋'}.entries)
      SwitchListTile(title:Text(item.value),value:((appearance[item.key] as num?)?.toDouble()??0)>=.5,
        onChanged:widget.busy?null:(v)=>_save({item.key:v?1.0:0.0})),
    SwitchListTile(title:const Text('长裙'),subtitle:const Text('关闭为短裙'),
      value:((appearance['Clothes1'] as num?)?.toDouble()??1)<.75,
      onChanged:widget.busy?null:(v)=>_save({'Clothes1':v ? 0.5 : 1.0})),
    ListTile(title:const Text('嘴型风格'),subtitle:Text(((appearance['MouthPressLipOpen'] as num?)?.toDouble()??-1)<=0?'猫嘴':'弧线嘴'),
      trailing:PopupMenuButton<double>(enabled:!widget.busy,onSelected:(v)=>_save({'MouthPressLipOpen':v}),
        itemBuilder:(_)=>const [PopupMenuItem(value:-1.0,child:Text('猫嘴')),PopupMenuItem(value:1.0,child:Text('弧线嘴'))])),
    const Text('小豆丁大小参数'),
    Text((_smallPreview ?? (appearance['smallForm'] as num?)?.toDouble() ?? .55).toStringAsFixed(2)),
    Slider(value:(_smallPreview ?? (appearance['smallForm'] as num?)?.toDouble() ?? .55).clamp(0,1).toDouble(),
      min:0,max:1,divisions:100,
      onChanged:widget.busy?null:(v)=>setState(()=>_smallPreview=v),
      onChangeEnd:widget.busy?null:(v)=>_save({'smallForm':v})),
    const Text('0为原大小；先预览小豆丁再调整，数值单独保存。'),
    Wrap(spacing:8,children:[
      ActionChip(label:const Text('单轴与组合预览'),onPressed:widget.busy?null:_parameter),
      ActionChip(label:const Text('清除参数预览'),onPressed:widget.busy?null:()=>widget.preview('previewParameters',<String,double>{})),
      ActionChip(label:const Text('变身中心'),onPressed:widget.busy?null:_anchor),
      ActionChip(label:const Text('预览小豆丁'),onPressed:widget.busy?null:()=>widget.preview('setForm',true)),
      ActionChip(label:const Text('恢复正常大小'),onPressed:widget.busy?null:()=>widget.preview('setForm',false)),
      ActionChip(label:const Text('小腿轴左倾'),onPressed:widget.busy?null:()=>widget.preview('previewParameters',{'rootTilt':3.0})),
      ActionChip(label:const Text('小腿轴右倾'),onPressed:widget.busy?null:()=>widget.preview('previewParameters',{'rootTilt':-3.0})),
      ActionChip(label:const Text('向左轻移'),onPressed:widget.busy?null:()=>widget.preview('previewParameters',{'rootX':-.03})),
      ActionChip(label:const Text('向右轻移'),onPressed:widget.busy?null:()=>widget.preview('previewParameters',{'rootX':.03})),
    ]),
  ]);
}
