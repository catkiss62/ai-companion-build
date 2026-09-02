import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/desire_state.dart';
import '../../core/models/proactive_frequency.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/models/proactive_notification_settings.dart';
import '../../core/moe/domain/moe_models.dart';
import '../../core/moe/infrastructure/sqlite_moe_repository.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/tts/tts_policy.dart';
import '../../core/tts/tts_text_processor.dart';
import '../../widgets/action_tint_text.dart';

class CompanionStateOverviewPage extends StatefulWidget {
  const CompanionStateOverviewPage({super.key});

  @override
  State<CompanionStateOverviewPage> createState() =>
      _CompanionStateOverviewPageState();
}

class _CompanionStateOverviewPageState
    extends State<CompanionStateOverviewPage> {
  DesireSnapshot? _desire;
  MoeStateSnapshot? _moe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final results = await Future.wait<Object>([
      db.loadDesire(),
      SqliteMoeRepository(() => db.database).loadState(),
    ]);
    if (!mounted) return;
    setState(() {
      _desire = results[0] as DesireSnapshot;
      _moe = results[1] as MoeStateSnapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final desire = _desire;
    final moe = _moe;
    return Scaffold(
      appBar: AppBar(title: const Text('她现在的状态')),
      body: desire == null || moe == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const _SectionIntro(
                    title: '欲望数值',
                    body: '只读显示“当前值 / 长期基线”；打开本页不会推进心跳或改变她的状态。',
                  ),
                  ...DriveKey.values.map((drive) {
                    final current = desire.drives[drive] ?? 0;
                    final baseline = desire.baselines[drive] ?? 0;
                    return _StateProgressRow(
                      label: drive.zhLabel,
                      progress: current,
                      value:
                          '${current.toStringAsFixed(2)} / ${baseline.toStringAsFixed(2)}',
                    );
                  }),
                  const SizedBox(height: 22),
                  const _SectionIntro(
                    title: '萌属性数字',
                    body: '显示 D2 的九项当前值与长期基线；不包含候选、内部诊断或强制动作。',
                  ),
                  ...MoeAxis.values.map((axis) {
                    final current =
                        moe.current[axis] ?? axis.defaultBaseline;
                    final baseline =
                        moe.baselines[axis] ?? axis.defaultBaseline;
                    return _StateProgressRow(
                      label: axis.label,
                      progress: current / 100,
                      value:
                          '${current.toStringAsFixed(0)} / ${baseline.toStringAsFixed(0)}',
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class ProactiveContactSettingsPage extends StatefulWidget {
  const ProactiveContactSettingsPage({super.key});

  @override
  State<ProactiveContactSettingsPage> createState() =>
      _ProactiveContactSettingsPageState();
}

class _ProactiveContactSettingsPageState
    extends State<ProactiveContactSettingsPage> {
  final _db = AppDatabase.instance;
  ProactiveFrequencyMode _frequency = ProactiveFrequencyMode.natural;
  ProactivePopupMode _popup = ProactivePopupMode.alwaysPopup;
  ProactiveNotificationPrivacy _privacy =
      ProactiveNotificationPrivacy.smart;
  ProactiveNotificationSound _sound = ProactiveNotificationSound.chime;
  ProactiveTtsPolicy _tts = ProactiveTtsPolicy.silent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _frequency = ProactiveFrequencyMode.fromSetting(
      await _db.getSetting(ProactiveFrequencyPolicy.settingKey),
    );
    _popup = ProactivePopupMode.fromSetting(
      await _db.getSetting('proactive_popup_mode'),
    );
    _privacy = ProactiveNotificationPrivacy.fromKey(
      await _db.getSetting('proactive_notification_privacy'),
    );
    _sound = ProactiveNotificationSound.fromSetting(
      await _db.getSetting('proactive_notification_sound'),
    );
    _tts = ProactiveTtsPolicy.fromSetting(
      await _db.getSetting('proactive_tts_policy'),
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String key, String value) => _db.setSetting(key, value);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('主动联系')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  DropdownButtonFormField<ProactiveFrequencyMode>(
                    value: _frequency,
                    decoration: const InputDecoration(
                      labelText: '主动频率',
                      border: OutlineInputBorder(),
                      helperText: '这是成功送达上限；她仍会按欲望、疲劳、内容和时机决定。',
                      helperMaxLines: 2,
                    ),
                    items: ProactiveFrequencyMode.values
                        .map((mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(
                                '${mode.zhLabel} · ${mode.dayLimit}次/24小时',
                              ),
                            ))
                        .toList(growable: false),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _frequency = value);
                      await _set(
                        ProactiveFrequencyPolicy.settingKey,
                        value.key,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ProactivePopupMode>(
                    value: _popup,
                    decoration: const InputDecoration(
                      labelText: '系统弹窗方式',
                      border: OutlineInputBorder(),
                    ),
                    items: ProactivePopupMode.values
                        .map((mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(mode.zhLabel),
                            ))
                        .toList(growable: false),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _popup = value);
                      await _set('proactive_popup_mode', value.key);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 14),
                    child: Text(_popup.description),
                  ),
                  DropdownButtonFormField<ProactiveNotificationPrivacy>(
                    value: _privacy,
                    decoration: const InputDecoration(
                      labelText: '通知隐私',
                      border: OutlineInputBorder(),
                    ),
                    items: ProactiveNotificationPrivacy.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.zhLabel),
                            ))
                        .toList(growable: false),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _privacy = value);
                      await _set('proactive_notification_privacy', value.key);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 14),
                    child: Text(_privacy.description),
                  ),
                  DropdownButtonFormField<ProactiveNotificationSound>(
                    value: _sound,
                    decoration: const InputDecoration(
                      labelText: '主动消息提示音',
                      border: OutlineInputBorder(),
                    ),
                    items: ProactiveNotificationSound.values
                        .map((sound) => DropdownMenuItem(
                              value: sound,
                              child: Text(sound.zhLabel),
                            ))
                        .toList(growable: false),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _sound = value);
                      await _set('proactive_notification_sound', value.key);
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ProactiveTtsPolicy>(
                    value: _tts,
                    decoration: const InputDecoration(
                      labelText: '主动消息语音',
                      border: OutlineInputBorder(),
                    ),
                    items: ProactiveTtsPolicy.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ))
                        .toList(growable: false),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _tts = value);
                      await _set('proactive_tts_policy', value.settingValue);
                    },
                  ),
                  const SizedBox(height: 18),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('打开系统通知管理'),
                    subtitle: const Text('声音与横幅还需要系统通知频道允许。'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => AndroidBridge.instance
                        .openCompanionNotificationSettings(soundKey: _sound.key),
                  ),
                ],
              ),
      );
}

class ChatVisualSettingsPage extends StatefulWidget {
  const ChatVisualSettingsPage({required this.onEditPortrait, super.key});

  final Future<void> Function() onEditPortrait;

  @override
  State<ChatVisualSettingsPage> createState() =>
      _ChatVisualSettingsPageState();
}

class _ChatVisualSettingsPageState extends State<ChatVisualSettingsPage> {
  final _db = AppDatabase.instance;
  bool _enabled = true;
  ChatPortraitSet _portrait = ChatPortraitSet.largeWhale;
  String _background = 'auto';
  double _opacity = 0.75;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _enabled = (await _db.getSetting('chat_visual_stage_enabled')) != '0';
    _portrait = chatPortraitSetFromKey(
      await _db.getSetting('chat_portrait_set'),
    );
    _background = await _db.getSetting('chat_background_mode') ?? 'auto';
    _opacity = (double.tryParse(
              await _db.getSetting('chat_panel_opacity') ?? '',
            ) ??
            0.75)
        .clamp(0.45, 0.95)
        .toDouble();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('聊天画面')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('角色聊天舞台'),
                    subtitle: const Text('只影响 App 内普通与沉浸聊天，不改变悬浮窗结构。'),
                    value: _enabled,
                    onChanged: (value) async {
                      setState(() => _enabled = value);
                      await _db.setSetting(
                        'chat_visual_stage_enabled',
                        value ? '1' : '0',
                      );
                    },
                  ),
                  if (_enabled) ...[
                    DropdownButtonFormField<ChatPortraitSet>(
                      value: _portrait,
                      decoration: const InputDecoration(
                        labelText: '立绘套装',
                        border: OutlineInputBorder(),
                      ),
                      items: ChatPortraitSet.values
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ))
                          .toList(growable: false),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _portrait = value);
                        await _db.setSetting('chat_portrait_set', value.key);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.zoom_out_map_rounded),
                      title: const Text('自定义立绘位置与大小'),
                      subtitle: Text('${_portrait.label} · 每套立绘独立保存'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await widget.onEditPortrait();
                        await _load();
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _background,
                      decoration: const InputDecoration(
                        labelText: '聊天背景',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('跟随昼夜')),
                        DropdownMenuItem(value: 'day', child: Text('固定白天')),
                        DropdownMenuItem(value: 'night', child: Text('固定夜晚')),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _background = value);
                        await _db.setSetting('chat_background_mode', value);
                      },
                    ),
                    const SizedBox(height: 18),
                    Text('聊天框透明度 ${(_opacity * 100).round()}%'),
                    Slider(
                      value: _opacity,
                      min: 0.45,
                      max: 0.95,
                      divisions: 10,
                      label: '${(_opacity * 100).round()}%',
                      onChanged: (value) => setState(() => _opacity = value),
                      onChangeEnd: (value) => _db.setSetting(
                        'chat_panel_opacity',
                        value.toStringAsFixed(2),
                      ),
                    ),
                  ],
                ],
              ),
      );
}

class VoiceEmotionSettingsPage extends StatefulWidget {
  const VoiceEmotionSettingsPage({super.key});

  @override
  State<VoiceEmotionSettingsPage> createState() =>
      _VoiceEmotionSettingsPageState();
}

class _VoiceEmotionSettingsPageState
    extends State<VoiceEmotionSettingsPage> {
  final _db = AppDatabase.instance;
  bool _ttsEnabled = false;
  TtsReadingScope _scope = TtsReadingScope.dialogueOnly;
  bool _showEmotion = true;
  bool _emotionSound = false;
  double _emotionVolume = 0.15;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _ttsEnabled = (await _db.getSetting('tts_enabled')) == '1';
    _scope = TtsReadingScope.fromSetting(
      await _db.getSetting('tts_reading_scope'),
    );
    _showEmotion = (await _db.getSetting('show_emotion_label')) != '0';
    _emotionSound = (await _db.getSetting('emotion_sound_enabled')) == '1';
    _emotionVolume = (double.tryParse(
              await _db.getSetting('emotion_sound_volume') ?? '',
            ) ??
            0.15)
        .clamp(0.0, 1.0)
        .toDouble();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('语音与情绪')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('本地 TTS'),
                    subtitle: const Text('与全部设置使用同一开关。'),
                    value: _ttsEnabled,
                    onChanged: (value) async {
                      setState(() => _ttsEnabled = value);
                      await _db.setSetting('tts_enabled', value ? '1' : '0');
                    },
                  ),
                  if (_ttsEnabled)
                    DropdownButtonFormField<TtsReadingScope>(
                      value: _scope,
                      decoration: const InputDecoration(
                        labelText: 'TTS 朗读内容',
                        border: OutlineInputBorder(),
                      ),
                      items: TtsReadingScope.values
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ))
                          .toList(growable: false),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _scope = value);
                        await _db.setSetting('tts_reading_scope', value.key);
                      },
                    ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示当前情绪'),
                    subtitle: const Text('在聊天头像旁显示本轮情绪标签。'),
                    value: _showEmotion,
                    onChanged: (value) async {
                      setState(() => _showEmotion = value);
                      await _db.setSetting(
                        'show_emotion_label',
                        value ? '1' : '0',
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('情绪短音效'),
                    subtitle: const Text('默认关闭；自动 TTS 开启时不会叠音。'),
                    value: _emotionSound,
                    onChanged: (value) async {
                      setState(() => _emotionSound = value);
                      await _db.setSetting(
                        'emotion_sound_enabled',
                        value ? '1' : '0',
                      );
                    },
                  ),
                  if (_emotionSound) ...[
                    Text('情绪音效音量 ${(_emotionVolume * 100).round()}%'),
                    Slider(
                      value: _emotionVolume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(_emotionVolume * 100).round()}%',
                      onChanged: (value) =>
                          setState(() => _emotionVolume = value),
                      onChangeEnd: (value) => _db.setSetting(
                        'emotion_sound_volume',
                        value.toStringAsFixed(2),
                      ),
                    ),
                  ],
                ],
              ),
      );
}

class TextPerformanceSettingsPage extends StatefulWidget {
  const TextPerformanceSettingsPage({super.key});

  @override
  State<TextPerformanceSettingsPage> createState() =>
      _TextPerformanceSettingsPageState();
}

class _TextPerformanceSettingsPageState
    extends State<TextPerformanceSettingsPage> {
  final _db = AppDatabase.instance;
  bool _enabled = true;
  int _milliseconds = 48;
  ChatDialogueColorOption _dialogueColor = ChatDialogueColorOption.purple;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _enabled = (await _db.getSetting('chat_typewriter_enabled')) != '0';
    _milliseconds = (int.tryParse(
              await _db.getSetting('chat_typewriter_ms') ?? '',
            ) ??
            48)
        .clamp(20, 120)
        .toInt();
    _dialogueColor = ChatDialogueColorOption.fromSetting(
      await _db.getSetting(ChatDialogueColorOption.settingKey),
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('文字演出')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('逐段打字演出'),
                    subtitle: const Text('主动消息仍保持一个完整气泡。'),
                    value: _enabled,
                    onChanged: (value) async {
                      setState(() => _enabled = value);
                      await _db.setSetting(
                        'chat_typewriter_enabled',
                        value ? '1' : '0',
                      );
                    },
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 8),
                    Text('每字 $_milliseconds ms'),
                    Slider(
                      value: _milliseconds.toDouble(),
                      min: 24,
                      max: 104,
                      divisions: 10,
                      label: '$_milliseconds ms',
                      onChanged: (value) =>
                          setState(() => _milliseconds = value.round()),
                      onChangeEnd: (value) => _db.setSetting(
                        'chat_typewriter_ms',
                        value.round().toString(),
                      ),
                    ),
                  ],
                  const Divider(height: 30),
                  Text(
                    '对白「」颜色',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '同一个选项控制普通聊天、沉浸房间和悬浮聊天。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ChatDialogueColorOption>(
                    segments: [
                      for (final option in ChatDialogueColorOption.values)
                        ButtonSegment(
                          value: option,
                          label: Text(
                            option.label,
                            style: TextStyle(color: option.color),
                          ),
                        ),
                    ],
                    selected: {_dialogueColor},
                    onSelectionChanged: (selection) async {
                      final value = selection.first;
                      setState(() => _dialogueColor = value);
                      await _db.setSetting(
                        ChatDialogueColorOption.settingKey,
                        value.key,
                      );
                      await AndroidBridge.instance
                          .setOverlayDialogueColor(value.key);
                    },
                  ),
                ],
              ),
      );
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(body, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _StateProgressRow extends StatelessWidget {
  const _StateProgressRow({
    required this.label,
    required this.progress,
    required this.value,
  });

  final String label;
  final double progress;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 76, child: Text(label)),
            Expanded(
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}
