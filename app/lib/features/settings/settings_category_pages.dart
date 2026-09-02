import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ai/deepseek_client.dart';
import '../../core/ai/model_profile.dart';
import '../../core/autonomy/layered_public_web_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/diagnostics/conversation_initiative_telemetry.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/storage/secure_config.dart';
import '../../widgets/chat_portrait_stage.dart';
import '../chat/chat_quick_settings_pages.dart';

class ModelNetworkSettingsPage extends StatefulWidget {
  const ModelNetworkSettingsPage({super.key});

  @override
  State<ModelNetworkSettingsPage> createState() =>
      _ModelNetworkSettingsPageState();
}

class _ModelNetworkSettingsPageState
    extends State<ModelNetworkSettingsPage> {
  final _db = AppDatabase.instance;
  final _secure = SecureConfig.instance;
  final _android = AndroidBridge.instance;
  final _deepSeekKey = TextEditingController();
  final _deepSeekEndpoint = TextEditingController();
  final _visionKey = TextEditingController();
  final _visionEndpoint = TextEditingController();
  final _visionModel = TextEditingController();
  final _tavilyKey = TextEditingController();
  final _extraSources = TextEditingController();
  final _agnesKey = TextEditingController();
  final _agnesEndpoint = TextEditingController();
  final _agnesModel = TextEditingController();

  DeepSeekModelProfile _model = DeepSeekModelProfile.pro;
  ReasoningEffort _effort = ReasoningEffort.high;
  bool _publicWeb = true;
  bool _agnesCompaction = true;
  bool _loading = true;
  bool _testingDeepSeek = false;
  bool _testingAgnes = false;
  bool _revealDeepSeek = false;
  bool _revealVision = false;
  bool _revealTavily = false;
  bool _revealAgnes = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _db.ensureReady();
    _deepSeekKey.text = await _secure.readApiKey() ?? '';
    _deepSeekEndpoint.text = await _secure.readEndpoint();
    _visionKey.text = await _secure.readVisionApiKey() ?? '';
    _visionEndpoint.text = await _secure.readVisionEndpoint();
    _visionModel.text = await _secure.readVisionModel();
    _tavilyKey.text = await _secure.readTavilyApiKey() ?? '';
    _extraSources.text = await _db.getSetting('public_web_extra_sources') ?? '';
    _agnesKey.text = await _secure.readAgnesApiKey() ?? '';
    _agnesEndpoint.text = await _secure.readAgnesEndpoint();
    _agnesModel.text = await _secure.readAgnesModel();
    _model = DeepSeekModelProfile.fromApiName(await _db.getSetting('model'));
    _effort = ReasoningEffort.fromApiName(
      await _db.getSetting('reasoning_effort'),
    );
    _publicWeb =
        (await _db.getSetting('public_web_discovery_enabled')) != '0';
    _agnesCompaction =
        (await _db.getSetting('agnes_web_compaction_enabled')) != '0';
    if (mounted) setState(() => _loading = false);
  }

  bool _validHttpEndpoint(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _saveDeepSeek() async {
    if (!_validHttpEndpoint(_deepSeekEndpoint.text)) {
      setState(() => _status = 'DeepSeek 地址不是有效的 http(s) URL。');
      return;
    }
    try {
      await _secure.writeEndpoint(_deepSeekEndpoint.text);
      await _secure.writeApiKey(_deepSeekKey.text);
      await _db.setSetting('model', _model.apiName);
      await _db.setSetting('reasoning_effort', _effort.apiName);
      if (_deepSeekKey.text.trim().isNotEmpty) {
        await _db.wakeRetryableGenerationJobs();
        await _db.wakeRetryablePostTurnJobs();
      }
      try {
        await _android.wakeBackgroundBrain(reason: 'api_config_saved');
      } catch (_) {}
      if (mounted) setState(() => _status = 'DeepSeek 配置已保存。');
    } catch (error) {
      if (mounted) setState(() => _status = 'DeepSeek 保存失败：$error');
    }
  }

  Future<void> _saveVision() async {
    if (!_validHttpEndpoint(_visionEndpoint.text)) {
      setState(() => _status = '千问视觉地址不是有效的 http(s) URL。');
      return;
    }
    try {
      await _secure.writeVisionEndpoint(_visionEndpoint.text);
      await _secure.writeVisionModel(_visionModel.text);
      await _secure.writeVisionApiKey(_visionKey.text);
      if (mounted) setState(() => _status = '千问视觉配置已保存。');
    } catch (error) {
      if (mounted) setState(() => _status = '千问视觉保存失败：$error');
    }
  }

  Future<void> _savePublicWeb() async {
    try {
      await _secure.writeTavilyApiKey(_tavilyKey.text);
      await _db.setSetting(
        'public_web_extra_sources',
        _extraSources.text.trim(),
      );
      if (mounted) setState(() => _status = '公开网页来源配置已保存。');
    } catch (error) {
      if (mounted) setState(() => _status = '网页来源保存失败：$error');
    }
  }

  Future<void> _saveAgnes() async {
    if (!_validHttpEndpoint(_agnesEndpoint.text)) {
      setState(() => _status = 'Agnes 地址不是有效的 http(s) URL。');
      return;
    }
    try {
      await _secure.writeAgnesEndpoint(_agnesEndpoint.text);
      await _secure.writeAgnesModel(_agnesModel.text);
      await _secure.writeAgnesApiKey(_agnesKey.text);
      if (mounted) setState(() => _status = 'Agnes 配置已保存。');
    } catch (error) {
      if (mounted) setState(() => _status = 'Agnes 保存失败：$error');
    }
  }

  Future<void> _testDeepSeek() async {
    final apiKey = _deepSeekKey.text.trim();
    final endpoint = _deepSeekEndpoint.text.trim();
    if (apiKey.isEmpty || !_validHttpEndpoint(endpoint)) {
      setState(() => _status = '请先填写有效的 DeepSeek Key 与地址。');
      return;
    }
    setState(() {
      _testingDeepSeek = true;
      _status = '正在测试当前输入；不会写入聊天或记忆…';
    });
    final client = DeepSeekClient();
    try {
      var sawResponse = false;
      final stream = client
          .streamChat(
            apiKey: apiKey,
            endpoint: endpoint,
            model: _model,
            effort: _effort,
            thinking: true,
            messages: const [
              {'role': 'user', 'content': 'Reply with OK only.'},
            ],
            maxTokens: 16,
          )
          .timeout(const Duration(seconds: 30));
      await for (final delta in stream) {
        if (delta.content.isNotEmpty ||
            delta.reasoning.isNotEmpty ||
            delta.finishReason != null ||
            delta.done) {
          sawResponse = true;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _status = sawResponse
              ? 'DeepSeek 连接通过；测试使用了少量 API 额度。'
              : 'API 已连接，但没有收到有效响应。';
        });
      }
    } on TimeoutException {
      if (mounted) setState(() => _status = 'DeepSeek 测试超时（30 秒）。');
    } catch (error) {
      if (mounted) setState(() => _status = 'DeepSeek 测试失败：$error');
    } finally {
      client.close();
      if (mounted) setState(() => _testingDeepSeek = false);
    }
  }

  Future<void> _testAgnes() async {
    if (_agnesKey.text.trim().isEmpty ||
        !_validHttpEndpoint(_agnesEndpoint.text)) {
      setState(() => _status = '请先填写有效的 Agnes Key 与地址。');
      return;
    }
    setState(() {
      _testingAgnes = true;
      _status = '正在用固定公开样本文字测试 Agnes…';
    });
    try {
      final result = await AgnesWebCompactor(
        apiKey: _agnesKey.text.trim(),
        endpoint: _agnesEndpoint.text.trim(),
        model: _agnesModel.text.trim(),
      ).testConnection();
      if (mounted) {
        setState(() {
          _status = result == null
              ? 'Agnes 未返回有效回复。'
              : 'Agnes 连接通过；测试使用了少量 API 额度。';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Agnes 测试失败：$error');
    } finally {
      if (mounted) setState(() => _testingAgnes = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('模型与联网')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SettingsSectionCard(
                    title: 'DeepSeek 聊天',
                    subtitle: '保存只影响本小节；连接测试使用当前输入，不会写聊天或记忆。',
                    children: [
                      _SecretField(
                        controller: _deepSeekKey,
                        label: 'DeepSeek API Key',
                        revealed: _revealDeepSeek,
                        onToggle: () => setState(
                          () => _revealDeepSeek = !_revealDeepSeek,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _deepSeekEndpoint,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Chat Completions API 地址',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DeepSeekModelProfile>(
                        value: _model,
                        decoration: const InputDecoration(
                          labelText: '默认聊天模型',
                          border: OutlineInputBorder(),
                        ),
                        items: DeepSeekModelProfile.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setState(() => _model = value ?? _model),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ReasoningEffort>(
                        value: _effort,
                        decoration: const InputDecoration(
                          labelText: '思考强度',
                          border: OutlineInputBorder(),
                        ),
                        items: ReasoningEffort.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setState(() => _effort = value ?? _effort),
                      ),
                      const SizedBox(height: 12),
                      _SaveTestButtons(
                        onSave: _saveDeepSeek,
                        onTest: _testingDeepSeek ? null : _testDeepSeek,
                        testing: _testingDeepSeek,
                      ),
                    ],
                  ),
                  _SettingsSectionCard(
                    title: '千问视觉',
                    subtitle: '用于用户发送图片和已授权的一次性视觉请求。',
                    children: [
                      _SecretField(
                        controller: _visionKey,
                        label: '千问视觉 API Key',
                        revealed: _revealVision,
                        onToggle: () =>
                            setState(() => _revealVision = !_revealVision),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _visionEndpoint,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '千问视觉 API 地址',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _visionModel,
                        decoration: const InputDecoration(
                          labelText: '千问视觉模型',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saveVision,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('保存视觉配置'),
                        ),
                      ),
                    ],
                  ),
                  _SettingsSectionCard(
                    title: '公开网页发现',
                    subtitle: '默认先做 Tavily 全网搜索；额外来源只用于补充，不会把搜索限制在这些站点。联网成功不等于自动分享。',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('欲望驱动的公开网页发现'),
                        subtitle: const Text('独立使用 4 次/24 小时预算。'),
                        value: _publicWeb,
                        onChanged: (value) async {
                          setState(() => _publicWeb = value);
                          await _db.setSetting(
                            'public_web_discovery_enabled',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      _SecretField(
                        controller: _tavilyKey,
                        label: 'Tavily API Key（可选）',
                        revealed: _revealTavily,
                        onToggle: () =>
                            setState(() => _revealTavily = !_revealTavily),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _extraSources,
                        minLines: 3,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: '额外公开来源（可选，每行一个网址或域名）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _savePublicWeb,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('保存网页来源'),
                        ),
                      ),
                    ],
                  ),
                  _SettingsSectionCard(
                    title: 'Agnes 网页整理',
                    subtitle: '只发送公开标题和片段，不发送聊天、记忆、Thought、关系或屏幕内容。',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('用 Agnes 整理网页片段'),
                        value: _agnesCompaction,
                        onChanged: (value) async {
                          setState(() => _agnesCompaction = value);
                          await _db.setSetting(
                            'agnes_web_compaction_enabled',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      _SecretField(
                        controller: _agnesKey,
                        label: 'Agnes API Key（可选）',
                        revealed: _revealAgnes,
                        onToggle: () =>
                            setState(() => _revealAgnes = !_revealAgnes),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _agnesEndpoint,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Agnes API 地址',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _agnesModel,
                        decoration: const InputDecoration(
                          labelText: 'Agnes 整理模型',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SaveTestButtons(
                        onSave: _saveAgnes,
                        onTest: _testingAgnes ? null : _testAgnes,
                        testing: _testingAgnes,
                        testLabel: '测试 Agnes 整理效果',
                      ),
                    ],
                  ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_status!, textAlign: TextAlign.center),
                    ),
                ],
              ),
      );

  @override
  void dispose() {
    _deepSeekKey.dispose();
    _deepSeekEndpoint.dispose();
    _visionKey.dispose();
    _visionEndpoint.dispose();
    _visionModel.dispose();
    _tavilyKey.dispose();
    _extraSources.dispose();
    _agnesKey.dispose();
    _agnesEndpoint.dispose();
    _agnesModel.dispose();
    super.dispose();
  }
}

class MemoryGrowthSettingsPage extends StatefulWidget {
  const MemoryGrowthSettingsPage({super.key});

  @override
  State<MemoryGrowthSettingsPage> createState() =>
      _MemoryGrowthSettingsPageState();
}

class _MemoryGrowthSettingsPageState extends State<MemoryGrowthSettingsPage> {
  final _db = AppDatabase.instance;
  final Map<String, bool> _values = {};
  bool _loading = true;

  static const _groups = <_GrowthGroup>[
    _GrowthGroup('记忆', [
      _GrowthSetting('auto_memory', '自动长期记忆抽取', '聊天后抽取少量长期记忆。'),
      _GrowthSetting(
        'memory_consolidation_enabled',
        '阶段记忆整理',
        '累积后形成阶段摘要，原始聊天仍保留。',
      ),
      _GrowthSetting(
        'memory_fading_enabled',
        '自然记忆淡化',
        '低价值旧记忆缓慢变淡；锁定记忆不会自动淡化。',
      ),
      _GrowthSetting(
        'reference_library_enabled',
        '参考资料',
        '按话题检索导入资料，但不覆盖 AI 本体身份。',
      ),
      _GrowthSetting(
        'rule_layers_enabled',
        '七大规则路由',
        '按日常、亲密和沉浸场景加载规则。',
      ),
    ]),
    _GrowthGroup('内在成长', [
      _GrowthSetting(
        'thought_lifecycle_enabled',
        'Thought 生命周期',
        '让念头经历产生、行动、余韵、沉下去与再次想起。',
      ),
      _GrowthSetting(
        'self_drive_enabled',
        'AI 自我驱动',
        '允许她从有依据的话题和记忆形成真实自我体验。',
      ),
      _GrowthSetting(
        'ai_self_reflection_enabled',
        'AI Self 自我整理',
        '低频从真实长期互动形成稳定自我认识。',
      ),
    ]),
    _GrowthGroup('关系与场景', [
      _GrowthSetting(
        'relationship_continuity_enabled',
        '关系连续性事件',
        '保存真正影响长期关系的约定、冲突和修复。',
      ),
      _GrowthSetting(
        'session_tracking_enabled',
        '临时互动 Session',
        '记录角色扮演或亲密场景的当前前提与边界。',
      ),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final group in _groups) {
      for (final setting in group.settings) {
        _values[setting.key] = (await _db.getSetting(setting.key)) != '0';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('记忆与成长')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const _BoundaryNotice(
                    text: '这些开关立即保存；关闭只停止对应自动流程，不删除已有聊天、记忆、Thought 或关系资料。',
                  ),
                  for (final group in _groups)
                    _SettingsSectionCard(
                      title: group.title,
                      children: [
                        for (final setting in group.settings)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(setting.title),
                            subtitle: Text(setting.subtitle),
                            value: _values[setting.key] ?? true,
                            onChanged: (value) async {
                              setState(() => _values[setting.key] = value);
                              await _db.setSetting(
                                setting.key,
                                value ? '1' : '0',
                              );
                            },
                          ),
                      ],
                    ),
                ],
              ),
      );
}

class ProactivePerceptionSettingsPage extends StatefulWidget {
  const ProactivePerceptionSettingsPage({super.key});

  @override
  State<ProactivePerceptionSettingsPage> createState() =>
      _ProactivePerceptionSettingsPageState();
}

class _ProactivePerceptionSettingsPageState
    extends State<ProactivePerceptionSettingsPage> {
  final _db = AppDatabase.instance;
  bool _perception = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _perception = (await _db.getSetting('perception_enabled')) != '0';
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('主动联系与感知')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SettingsRouteCard(
                    icon: Icons.notifications_active_outlined,
                    title: '主动联系',
                    subtitle: '频率、节奏学习、系统弹窗、隐私、提示音与主动语音',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProactiveContactSettingsPage(),
                      ),
                    ),
                  ),
                  _SettingsSectionCard(
                    title: '环境感知',
                    subtitle: '原始手机事件先在本地压缩，只形成低强度内在输入。',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('现实环境感知进入内在状态'),
                        subtitle: const Text(
                          '使用 Usage、通知和 Accessibility 的本地摘要；不等于持续看见屏幕。',
                        ),
                        value: _perception,
                        onChanged: (value) async {
                          setState(() => _perception = value);
                          await _db.setSetting(
                            'perception_enabled',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.security_outlined),
                        title: const Text('权限与连接状态'),
                        subtitle: const Text('查看轻视觉、通知、Usage 与悬浮陪伴是否真正连接。'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pushNamed('/system'),
                      ),
                    ],
                  ),
                ],
              ),
      );
}

class PresentationSettingsPage extends StatelessWidget {
  const PresentationSettingsPage({super.key});

  Future<void> _openPortraitEditor(BuildContext context) async {
    final db = AppDatabase.instance;
    final set = chatPortraitSetFromKey(
      await db.getSetting('chat_portrait_set'),
    );
    String key(String field) => 'chat_portrait_${field}_${set.key}';
    final defaults = ChatPortraitTransform.defaultsFor(set);
    final legacyScale = set == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_scale')
        : null;
    final legacyX = set == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_offset_x')
        : null;
    final legacyY = set == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_offset_y')
        : null;
    final initial = ChatPortraitTransform(
      scale: (double.tryParse(
                await db.getSetting(key('scale')) ?? legacyScale ?? '',
              ) ??
              defaults.scale)
          .clamp(0.85, 1.80)
          .toDouble(),
      offset: Offset(
        (double.tryParse(
                  await db.getSetting(key('offset_x')) ?? legacyX ?? '',
                ) ??
                defaults.offset.dx)
            .clamp(-0.45, 0.45)
            .toDouble(),
        (double.tryParse(
                  await db.getSetting(key('offset_y')) ?? legacyY ?? '',
                ) ??
                defaults.offset.dy)
            .clamp(-0.35, 0.35)
            .toDouble(),
      ),
    );
    final backgroundMode =
        await db.getSetting('chat_background_mode') ?? 'auto';
    final hour = DateTime.now().hour;
    final night = backgroundMode == 'night' ||
        (backgroundMode == 'auto' && (hour < 6 || hour >= 18));
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<ChatPortraitTransform>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatPortraitTransformEditor(
          emotion: ChatVisualResolver.normal,
          portraitSet: set,
          initial: initial,
          backgroundAsset: night
              ? 'assets/lingchat/background/night.webp'
              : 'assets/lingchat/background/day.webp',
        ),
      ),
    );
    if (result == null) return;
    await Future.wait([
      db.setSetting(key('scale'), result.scale.toStringAsFixed(4)),
      db.setSetting(key('offset_x'), result.offset.dx.toStringAsFixed(4)),
      db.setSetting(key('offset_y'), result.offset.dy.toStringAsFixed(4)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('语音与聊天呈现')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _BoundaryNotice(
              text: '这里与头像侧栏共用同一份设置；切换任一入口后重新打开另一页即可看到最新值。',
            ),
            _SettingsRouteCard(
              icon: Icons.record_voice_over_outlined,
              title: '语音与情绪',
              subtitle: '本地 TTS、朗读策略、语速、音量、情绪标签与短音效',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VoiceEmotionSettingsPage(),
                ),
              ),
            ),
            _SettingsRouteCard(
              icon: Icons.wallpaper_outlined,
              title: '聊天画面',
              subtitle: '立绘、位置、背景和聊天框透明度',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatVisualSettingsPage(
                    onEditPortrait: () => _openPortraitEditor(context),
                  ),
                ),
              ),
            ),
            _SettingsRouteCard(
              icon: Icons.text_fields_rounded,
              title: '文字演出',
              subtitle: '逐段打字、速度与普通/沉浸/悬浮共享对白颜色',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TextPerformanceSettingsPage(),
                ),
              ),
            ),
          ],
        ),
      );
}

class DeviceDataSettingsPage extends StatefulWidget {
  const DeviceDataSettingsPage({super.key});

  @override
  State<DeviceDataSettingsPage> createState() =>
      _DeviceDataSettingsPageState();
}

class _DeviceDataSettingsPageState extends State<DeviceDataSettingsPage> {
  final _db = AppDatabase.instance;
  final _android = AndroidBridge.instance;
  bool _activeBrain = true;
  bool _loading = true;
  bool _resetting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _activeBrain = (await _db.getSetting('active_brain')) != '0';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changeActiveBrain(bool next) async {
    if (next == _activeBrain) return;
    if (!next) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('主动下线这台设备？'),
              content: const Text(
                '本机会停止生成回复和主动联系；聊天、记忆和关系数据不会删除。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('主动下线'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      await _db.setSetting('active_brain', '0');
      try {
        await _android.stopOverlay();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _activeBrain = false;
          _status = '本机已主动下线；本地数据仍保留。';
        });
      }
      return;
    }
    if ((await _db.getSetting('transfer_lock')) == '1') {
      if (mounted) setState(() => _status = '设备转移尚未完成，不能强行上线。');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('在本机手动上线？'),
            content: const Text(
              '仅在确认另一台设备已经下线、关机或不再运行 Active Brain 时使用。正常切换请使用“手机 / 平板接管”。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认另一台已下线'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _db.setSetting('active_brain', '1');
    if (mounted) {
      setState(() {
        _activeBrain = true;
        _status = '本机已手动上线为 Active Brain。';
      });
    }
  }

  Future<void> _resetConversationContext() async {
    if (_resetting) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('开始新的对话上下文？'),
            content: const Text(
              '下一轮不再把当前边界以前的原始台词作为近场续写。聊天记录、长期记忆、关系进度、AI Self、相册、Desire 和 Thought 不会删除；当前临时 Session 会结束。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始新上下文'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _resetting = true;
      _status = '正在建立新的对话上下文…';
    });
    try {
      final result = await _db.beginFreshConversationContext();
      if (!result.applied) {
        if (mounted) {
          setState(() {
            _status = result.reason == 'pending_generation'
                ? '仍有回复任务待处理，请先回聊天重试或放弃。'
                : '暂时无法开始新的对话上下文。';
          });
        }
        return;
      }
      await ConversationInitiativeTelemetry.recordReset(
        _db,
        at: result.resetAt!,
      );
      try {
        await _android.wakeBackgroundBrain(reason: 'conversation_context_reset');
      } catch (_) {}
      if (mounted) setState(() => _status = '新的对话上下文已建立。');
    } catch (error) {
      if (mounted) setState(() => _status = '建立新上下文失败：$error');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('设备与数据')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SettingsSectionCard(
                    title: '当前主设备',
                    subtitle: 'Active Brain 是立即执行的设备所有权操作，不属于普通保存。',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('本机是 Active Brain'),
                        subtitle: Text(
                          _activeBrain
                              ? '当前由本机承载她。正常换设备请使用接管流程。'
                              : '本机当前处于待机/下线状态。',
                        ),
                        value: _activeBrain,
                        onChanged: _changeActiveBrain,
                      ),
                    ],
                  ),
                  _SettingsRouteCard(
                    icon: Icons.swap_horiz_rounded,
                    title: '手机 / 平板接管与备份',
                    subtitle: '正常换设备、保存备份或恢复单个 .aibackup 文件',
                    onTap: () => Navigator.of(context).pushNamed('/transfer'),
                  ),
                  _SettingsRouteCard(
                    icon: Icons.security_outlined,
                    title: '权限、悬浮与系统状态',
                    subtitle: '轻视觉、通知、Usage、桌宠/悬浮球和后台连接',
                    onTap: () => Navigator.of(context).pushNamed('/system'),
                  ),
                  _SettingsSectionCard(
                    title: '对话边界',
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _resetting ? null : _resetConversationContext,
                          icon: _resetting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restart_alt_rounded),
                          label: Text(
                            _resetting ? '正在开始新上下文…' : '开始新的对话上下文',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '保留聊天、记忆、关系、相册和内在状态，只结束旧近场续写与临时 Session。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  if (_status != null)
                    Text(_status!, textAlign: TextAlign.center),
                ],
              ),
      );
}

class DiagnosticsDevelopmentSettingsPage extends StatelessWidget {
  const DiagnosticsDevelopmentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('诊断与开发')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _BoundaryNotice(
              text: '日常只需“快速自检”。下方深度验收和开发动作可能初始化模型、安排通知、调用 API 或推进真实内部状态。',
            ),
            _SettingsRouteCard(
              icon: Icons.health_and_safety_outlined,
              title: '快速自检与诊断报告',
              subtitle: '读取权限、后台、Active Brain、存储和 TTS；可保存脱敏报告',
              onTap: () => Navigator.of(context).pushNamed('/preflight'),
            ),
            _SettingsRouteCard(
              icon: Icons.fact_check_outlined,
              title: '深度自检与综合验收',
              subtitle: '开发阶段检查 TTS、感知、悬浮与跨设备；可能初始化本地模型',
              onTap: () => Navigator.of(context).pushNamed('/checkpoint'),
            ),
            _SettingsRouteCard(
              icon: Icons.build_outlined,
              title: '运行维护',
              subtitle: '恢复检查、失败任务处理、五分钟联系和网页分享闭环测试',
              warning: '部分操作会安排通知、调用模型或产生真实主动消息。',
              onTap: () => Navigator.of(context).pushNamed('/system'),
            ),
            _SettingsRouteCard(
              icon: Icons.science_outlined,
              title: '内在状态开发工具',
              subtitle: 'Thought、Desire、Self-Drive、AI Self 与生命周期诊断',
              warning: '按钮会推进真实内部状态，不是只读自检。',
              onTap: () => Navigator.of(context).pushNamed('/inner'),
            ),
          ],
        ),
      );
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

class _SettingsRouteCard extends StatelessWidget {
  const _SettingsRouteCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.warning,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(
            warning == null ? subtitle : '$subtitle\n$warning',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

class _BoundaryNotice extends StatelessWidget {
  const _BoundaryNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text),
        ),
      );
}

class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.controller,
    required this.label,
    required this.revealed,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool revealed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: !revealed,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(revealed ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      );
}

class _SaveTestButtons extends StatelessWidget {
  const _SaveTestButtons({
    required this.onSave,
    required this.onTest,
    required this.testing,
    this.testLabel = '连接测试',
  });

  final VoidCallback onSave;
  final VoidCallback? onTest;
  final bool testing;
  final String testLabel;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: onTest,
            icon: testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(testing ? '正在测试…' : testLabel),
          ),
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存本小节'),
          ),
        ],
      );
}

class _GrowthGroup {
  const _GrowthGroup(this.title, this.settings);
  final String title;
  final List<_GrowthSetting> settings;
}

class _GrowthSetting {
  const _GrowthSetting(this.key, this.title, this.subtitle);
  final String key;
  final String title;
  final String subtitle;
}
