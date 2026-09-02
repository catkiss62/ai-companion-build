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
import '../../core/tts/tts_provider.dart';
import '../../core/tts/tts_service.dart';
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
  bool _adaptation = true;
  String? _status;
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
    _adaptation =
        (await _db.getSetting('proactive_adaptation_enabled')) != '0';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String key, String value) => _db.setSetting(key, value);

  Future<void> _previewSound() async {
    setState(() => _status = '正在试听当前提示音…');
    try {
      final result = await AndroidBridge.instance
          .previewCompanionNotificationSound(soundKey: _sound.key);
      if (!mounted) return;
      setState(() {
        _status = _sound == ProactiveNotificationSound.silent
            ? '当前选择为静音。'
            : result['played'] == true
                ? '提示音试听完成；这一步不经过系统通知频道。'
                : '提示音试听失败：${result['reason'] ?? '无法启动音频'}';
      });
    } catch (error) {
      if (mounted) setState(() => _status = '提示音试听失败：$error');
    }
  }

  Future<void> _testNotification() async {
    setState(() => _status = '正在发送一条不写聊天和记忆的测试通知…');
    try {
      final result = await AndroidBridge.instance
          .testCompanionNotification(soundKey: _sound.key);
      if (!mounted) return;
      setState(() {
        _status = result['posted'] == true
            ? '测试通知已交给 Android。'
            : '测试通知未显示：${result['reason'] ?? '请检查通知权限'}';
      });
    } catch (error) {
      if (mounted) setState(() => _status = '测试通知失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('主动联系')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('主动联系节奏学习'),
                    subtitle: const Text(
                      '只在本地学习更合适的时段、活动情境和话题反馈。',
                    ),
                    value: _adaptation,
                    onChanged: (value) async {
                      setState(() => _adaptation = value);
                      await _set(
                        'proactive_adaptation_enabled',
                        value ? '1' : '0',
                      );
                    },
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _previewSound,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('试听当前声音'),
                      ),
                      TextButton.icon(
                        onPressed: _testNotification,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('测试系统弹窗'),
                      ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('打开该频道的浮动通知设置'),
                    subtitle: const Text('声音与横幅还需要系统通知频道允许。'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => AndroidBridge.instance
                        .openCompanionNotificationSettings(soundKey: _sound.key),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 8),
                    Text(_status!),
                  ],
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
  final _tts = TtsService();
  final _replacementController = TextEditingController();
  bool _ttsEnabled = false;
  bool _autoTts = false;
  bool _streamingTts = false;
  TtsReadingScope _scope = TtsReadingScope.dialogueOnly;
  ProactiveTtsPolicy _proactivePolicy = ProactiveTtsPolicy.silent;
  double _ttsSpeed = 1.0;
  double _ttsVolume = 1.0;
  bool _showEmotion = true;
  bool _emotionSound = false;
  double _emotionVolume = 0.15;
  TtsStatus? _ttsStatus;
  bool _ttsBusy = false;
  String? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _ttsEnabled = (await _db.getSetting('tts_enabled')) == '1';
    _autoTts = (await _db.getSetting('auto_tts')) == '1';
    _streamingTts =
        (await _db.getSetting('tts_streaming_enabled')) == '1';
    _scope = TtsReadingScope.fromSetting(
      await _db.getSetting('tts_reading_scope'),
    );
    _proactivePolicy = ProactiveTtsPolicy.fromSetting(
      await _db.getSetting('proactive_tts_policy'),
    );
    _ttsSpeed = (double.tryParse(await _db.getSetting('tts_speed') ?? '') ?? 1.0)
        .clamp(0.5, 2.0)
        .toDouble();
    _ttsVolume =
        (double.tryParse(await _db.getSetting('tts_volume') ?? '') ?? 1.0)
            .clamp(0.0, 1.0)
            .toDouble();
    _replacementController.text =
        await _db.getSetting('tts_replacements_json') ?? '{"Yuki":"有希"}';
    _showEmotion = (await _db.getSetting('show_emotion_label')) != '0';
    _emotionSound = (await _db.getSetting('emotion_sound_enabled')) == '1';
    _emotionVolume = (double.tryParse(
              await _db.getSetting('emotion_sound_volume') ?? '',
            ) ??
            0.15)
        .clamp(0.0, 1.0)
        .toDouble();
    try {
      _ttsStatus = await _tts.status();
    } catch (_) {
      _ttsStatus = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _runTtsAction(
    String pending,
    Future<String> Function() action,
  ) async {
    if (_ttsBusy) return;
    setState(() {
      _ttsBusy = true;
      _status = pending;
    });
    try {
      final result = await action();
      _ttsStatus = await _tts.status();
      if (mounted) setState(() => _status = result);
    } catch (error) {
      if (mounted) setState(() => _status = 'TTS 操作失败：$error');
    } finally {
      if (mounted) setState(() => _ttsBusy = false);
    }
  }

  Future<void> _saveReplacement() async {
    await _db.setSetting(
      'tts_replacements_json',
      _replacementController.text.trim(),
    );
    if (mounted) setState(() => _status = 'TTS 文字替换已保存。');
  }

  @override
  void dispose() {
    _replacementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTtsStatus = _ttsStatus;
    return Scaffold(
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
                        labelText: '朗读范围',
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
                  if (_ttsEnabled) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('AI 回复后自动朗读'),
                      subtitle: const Text('只朗读最终正文，不朗读 THINKING。'),
                      value: _autoTts,
                      onChanged: (value) async {
                        setState(() => _autoTts = value);
                        await _db.setSetting('auto_tts', value ? '1' : '0');
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('流式分句朗读'),
                      subtitle: const Text('每完成一句就进入本地 TTS 队列。'),
                      value: _streamingTts,
                      onChanged: _autoTts
                          ? (value) async {
                              setState(() => _streamingTts = value);
                              await _db.setSetting(
                                'tts_streaming_enabled',
                                value ? '1' : '0',
                              );
                            }
                          : null,
                    ),
                    DropdownButtonFormField<ProactiveTtsPolicy>(
                      value: _proactivePolicy,
                      decoration: const InputDecoration(
                        labelText: '主动消息语音策略',
                        border: OutlineInputBorder(),
                      ),
                      items: ProactiveTtsPolicy.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _proactivePolicy = value);
                        await _db.setSetting(
                          'proactive_tts_policy',
                          value.settingValue,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('语速 ${_ttsSpeed.toStringAsFixed(2)}×'),
                    Slider(
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      value: _ttsSpeed,
                      onChanged: (value) => setState(() => _ttsSpeed = value),
                      onChangeEnd: (value) => _db.setSetting(
                        'tts_speed',
                        value.toStringAsFixed(2),
                      ),
                    ),
                    Text('TTS 音量 ${(_ttsVolume * 100).round()}%'),
                    Slider(
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      value: _ttsVolume,
                      onChanged: (value) => setState(() => _ttsVolume = value),
                      onChangeEnd: (value) => _db.setSetting(
                        'tts_volume',
                        value.toStringAsFixed(2),
                      ),
                    ),
                    TextField(
                      controller: _replacementController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'TTS 文字替换 JSON',
                        helperText: '只改变朗读文本，不改聊天正文。',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _saveReplacement,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存文字替换'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentTtsStatus == null
                          ? '尚未读取本地 TTS 状态。'
                          : '${currentTtsStatus.engine} · ${currentTtsStatus.available ? '资源可用' : '资源未就绪'}\n${currentTtsStatus.detail}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _ttsBusy
                              ? null
                              : () => _runTtsAction(
                                    '正在校验本地 TTS 资源…',
                                    () async {
                                      final next = await _tts.verifyArtifacts();
                                      return next.integrityVerified
                                          ? 'TTS 资源校验通过（${next.artifactCount} 项）。'
                                          : 'TTS 资源校验失败：${next.detail}';
                                    },
                                  ),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('校验资源'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _ttsBusy
                              ? null
                              : () => _runTtsAction(
                                    '正在初始化本地 TTS；首次可能复制模型…',
                                    () async {
                                      final next = await _tts.initialize();
                                      return next.initialized
                                          ? '本地 TTS 初始化完成。'
                                          : 'TTS 初始化失败：${next.detail}';
                                    },
                                  ),
                          icon: const Icon(Icons.memory),
                          label: const Text('初始化模型'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _ttsBusy
                              ? null
                              : () => _runTtsAction(
                                    '正在生成并播放本地测试语音…',
                                    () async {
                                      final ok = await _tts.preview(
                                        '这是本地语音测试。以后我会直接在你的设备上说话。',
                                      );
                                      return ok ? '测试语音播放完成。' : '测试语音播放失败。';
                                    },
                                  ),
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('测试朗读'),
                        ),
                      ],
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 8),
                      Text(_status!),
                    ],
                    const Divider(height: 28),
                  ],
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
