import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ai/deepseek_client.dart';
import '../../core/ai/model_profile.dart';
import '../../core/database/app_database.dart';
import '../../core/storage/secure_config.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/tts/tts_policy.dart';
import '../../core/tts/tts_provider.dart';
import '../../core/tts/tts_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final db = AppDatabase.instance;
  final secure = SecureConfig.instance;
  final android = AndroidBridge.instance;
  final tts = TtsService();
  final keyController = TextEditingController();
  final endpointController = TextEditingController();
  final ttsReplacementController = TextEditingController();

  bool loading = true;
  bool revealKey = false;
  bool testingApi = false;
  bool autoMemory = true;
  bool memoryConsolidation = true;
  bool memoryFading = true;
  bool referenceLibrary = true;
  bool ruleLayersEnabled = true;
  bool thoughtLifecycleEnabled = true;
  bool proactiveAdaptationEnabled = true;
  bool selfDrive = true;
  bool selfReflection = true;
  bool perceptionEnabled = true;
  bool relationshipContinuity = true;
  bool sessionTracking = true;
  bool activeBrain = true;
  bool ttsEnabled = false;
  bool autoTts = false;
  bool streamingTts = false;
  ProactiveTtsPolicy proactiveTtsPolicy = ProactiveTtsPolicy.silent;
  ProactiveNotificationPrivacy proactiveNotificationPrivacy =
      ProactiveNotificationPrivacy.smart;
  double ttsSpeed = 1.0;
  double ttsVolume = 1.0;
  DeepSeekModelProfile model = DeepSeekModelProfile.pro;
  ReasoningEffort effort = ReasoningEffort.high;
  TtsStatus? ttsStatus;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await db.ensureReady();
    keyController.text = await secure.readApiKey() ?? '';
    endpointController.text = await secure.readEndpoint();
    autoMemory = (await db.getSetting('auto_memory')) != '0';
    memoryConsolidation = (await db.getSetting('memory_consolidation_enabled')) != '0';
    memoryFading = (await db.getSetting('memory_fading_enabled')) != '0';
    referenceLibrary = (await db.getSetting('reference_library_enabled')) != '0';
    ruleLayersEnabled = (await db.getSetting('rule_layers_enabled')) != '0';
    thoughtLifecycleEnabled = (await db.getSetting('thought_lifecycle_enabled')) != '0';
    proactiveAdaptationEnabled = (await db.getSetting('proactive_adaptation_enabled')) != '0';
    selfDrive = (await db.getSetting('self_drive_enabled')) != '0';
    selfReflection = (await db.getSetting('ai_self_reflection_enabled')) != '0';
    perceptionEnabled = (await db.getSetting('perception_enabled')) != '0';
    relationshipContinuity = (await db.getSetting('relationship_continuity_enabled')) != '0';
    sessionTracking = (await db.getSetting('session_tracking_enabled')) != '0';
    activeBrain = (await db.getSetting('active_brain')) != '0';
    ttsEnabled = (await db.getSetting('tts_enabled')) != '0';
    autoTts = (await db.getSetting('auto_tts')) != '0';
    streamingTts = (await db.getSetting('tts_streaming_enabled')) != '0';
    proactiveTtsPolicy = ProactiveTtsPolicy.fromSetting(
      await db.getSetting('proactive_tts_policy'),
    );
    proactiveNotificationPrivacy = ProactiveNotificationPrivacy.fromKey(
      await db.getSetting('proactive_notification_privacy'),
    );
    ttsSpeed = double.tryParse(await db.getSetting('tts_speed') ?? '') ?? 1.0;
    ttsVolume = double.tryParse(await db.getSetting('tts_volume') ?? '') ?? 1.0;
    ttsReplacementController.text =
        await db.getSetting('tts_replacements_json') ?? '{"Yuki":"有希"}';
    model = DeepSeekModelProfile.fromApiName(await db.getSetting('model'));
    effort = ReasoningEffort.fromApiName(await db.getSetting('reasoning_effort'));
    try {
      ttsStatus = await tts.status();
    } catch (_) {
      ttsStatus = null;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    try {
      // Validate/store the endpoint before changing the API key so a malformed
      // URL cannot leave a half-saved credential configuration.
      await secure.writeEndpoint(endpointController.text);
      await secure.writeApiKey(keyController.text);
      await db.setSetting('auto_memory', autoMemory ? '1' : '0');
      await db.setSetting('memory_consolidation_enabled', memoryConsolidation ? '1' : '0');
      await db.setSetting('memory_fading_enabled', memoryFading ? '1' : '0');
      await db.setSetting('reference_library_enabled', referenceLibrary ? '1' : '0');
      await db.setSetting('rule_layers_enabled', ruleLayersEnabled ? '1' : '0');
      await db.setSetting('thought_lifecycle_enabled', thoughtLifecycleEnabled ? '1' : '0');
      await db.setSetting('proactive_adaptation_enabled', proactiveAdaptationEnabled ? '1' : '0');
      await db.setSetting('self_drive_enabled', selfDrive ? '1' : '0');
      await db.setSetting('ai_self_reflection_enabled', selfReflection ? '1' : '0');
      await db.setSetting('perception_enabled', perceptionEnabled ? '1' : '0');
      await db.setSetting('relationship_continuity_enabled', relationshipContinuity ? '1' : '0');
      await db.setSetting('session_tracking_enabled', sessionTracking ? '1' : '0');
      // Active Brain is intentionally NOT written by the generic Save button.
      // Device ownership changes are immediate, explicit operations so a stale
      // settings screen cannot accidentally re-activate a standby device.
      await db.setSetting('tts_enabled', ttsEnabled ? '1' : '0');
      await db.setSetting('auto_tts', autoTts ? '1' : '0');
      await db.setSetting('tts_streaming_enabled', streamingTts ? '1' : '0');
      await db.setSetting('proactive_tts_policy', proactiveTtsPolicy.settingValue);
      await db.setSetting(
        'proactive_notification_privacy',
        proactiveNotificationPrivacy.key,
      );
      await db.setSetting('tts_speed', ttsSpeed.toStringAsFixed(2));
      await db.setSetting('tts_volume', ttsVolume.toStringAsFixed(2));
      await db.setSetting('tts_replacements_json', ttsReplacementController.text.trim());
      await db.setSetting('model', model.apiName);
      await db.setSetting('reasoning_effort', effort.apiName);
      if (keyController.text.trim().isNotEmpty) {
        // API credentials are intentionally device-local. If a transferred or
        // crash-recovered turn was waiting on credentials/configuration, make
        // it immediately eligible instead of waiting for its retry timer.
        await db.wakeRetryableGenerationJobs();
        await db.wakeRetryablePostTurnJobs();
      }
      try {
        await android.wakeBackgroundBrain(reason: 'api_config_saved');
      } catch (_) {}
      if (mounted) setState(() => status = '已保存到本机');
    } catch (e) {
      if (mounted) setState(() => status = '保存失败：$e');
    }
  }



  Future<void> _testApiConnection() async {
    final apiKey = keyController.text.trim();
    final endpoint = endpointController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => status = 'API 测试失败：请先填写 DeepSeek API Key。');
      return;
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => status = 'API 测试失败：API 地址不是有效的 http(s) URL。');
      return;
    }

    setState(() {
      testingApi = true;
      status = '正在测试当前 API 地址、Key 与模型…';
    });
    final client = DeepSeekClient();
    try {
      var sawResponse = false;
      final stream = client
          .streamChat(
            apiKey: apiKey,
            endpoint: endpoint,
            model: model,
            effort: effort,
            thinking: false,
            messages: const <Map<String, Object?>>[
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
      if (!mounted) return;
      setState(() {
        status = sawResponse
            ? 'API 连接通过：当前地址、Key 与 ${model.label} 可以返回响应。'
            : 'API 已连接，但没有收到有效响应。';
      });
    } on TimeoutException {
      if (mounted) {
        setState(() => status = 'API 测试超时（30 秒）：请检查网络、API 地址或代理可达性。');
      }
    } catch (e) {
      if (mounted) setState(() => status = 'API 测试失败：$e');
    } finally {
      client.close();
      if (mounted) setState(() => testingApi = false);
    }
  }

  Future<void> _changeActiveBrain(bool next) async {
    if (next == activeBrain) return;

    if (!next) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('主动下线这台设备？'),
              content: const Text(
                '下线后，本机停止作为 AI 的 Active Brain，不再主动联系或生成新回复。'
                '本地聊天和记忆不会删除，之后可以通过设备接管或手动重新上线。',
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

      await db.setSetting('active_brain', '0');
      try {
        await android.stopOverlay();
      } catch (_) {
        // Overlay shutdown is best-effort. active_brain=0 is authoritative.
      }
      if (!mounted) return;
      setState(() {
        activeBrain = false;
        status = '本机已主动下线；本地数据仍保留。';
      });
      return;
    }

    if ((await db.getSetting('transfer_lock')) == '1') {
      if (!mounted) return;
      setState(() {
        status = '设备转移尚未完成，不能从普通设置里强行上线。请先完成或取消设备转移。';
      });
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('在本机手动上线？'),
            content: const Text(
              '这是一条故障兜底入口。只有确认另一台设备已经下线、关机或不再运行 Active Brain 时才应继续。'
              '正常手机/平板切换请优先使用“设备接管”，它会自动完成旧设备下线。',
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

    await db.setSetting('active_brain', '1');
    if (!mounted) return;
    setState(() {
      activeBrain = true;
      status = '本机已手动上线为 Active Brain。';
    });
  }

  Future<void> _checkTts() async {
    setState(() => status = '正在核对本地 TTS 与 MejuTTS v2.7 黄金资源…');
    try {
      final next = await tts.verifyArtifacts();
      if (mounted) {
        setState(() {
          ttsStatus = next;
          status = next.integrityVerified
              ? '本地 TTS 黄金资源校验通过（${next.artifactCount} 项）'
              : '本地 TTS 校验失败：${next.detail}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = 'TTS 黄金资源检查失败：$e');
    }
  }

  Future<void> _initializeTts() async {
    setState(() => status = '正在初始化本地 TTS；首次会把模型复制到应用私有目录…');
    try {
      await db.setSetting('tts_speed', ttsSpeed.toStringAsFixed(2));
      await db.setSetting('tts_volume', ttsVolume.toStringAsFixed(2));
      final next = await tts.initialize();
      if (!mounted) return;
      setState(() {
        ttsStatus = next;
        status = next.initialized ? '本地 TTS 初始化完成' : '本地 TTS 初始化失败：${next.detail}';
      });
    } catch (e) {
      if (mounted) setState(() => status = 'TTS 初始化失败：$e');
    }
  }

  Future<void> _testTts() async {
    setState(() => status = '正在生成本地测试语音…');
    await db.setSetting('tts_speed', ttsSpeed.toStringAsFixed(2));
    await db.setSetting('tts_volume', ttsVolume.toStringAsFixed(2));
    await db.setSetting('tts_replacements_json', ttsReplacementController.text.trim());
    final ok = await tts.preview('这是本地语音测试。以后我会直接在你的设备上说话。');
    if (!mounted) return;
    final next = await tts.status();
    setState(() {
      ttsStatus = next;
      status = ok ? '测试语音播放完成' : '测试失败：${next.detail}';
    });
  }

  @override
  void dispose() {
    keyController.dispose();
    endpointController.dispose();
    ttsReplacementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('模型与本机设置', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        TextField(
          controller: keyController,
          obscureText: !revealKey,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'DeepSeek API Key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => revealKey = !revealKey),
              icon: Icon(revealKey ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: endpointController,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Chat Completions API 地址',
            hintText: 'https://api.deepseek.com/chat/completions',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<DeepSeekModelProfile>(
          value: model,
          decoration: const InputDecoration(
            labelText: '默认聊天模型',
            border: OutlineInputBorder(),
          ),
          items: DeepSeekModelProfile.values
              .map((e) => DropdownMenuItem(value: e, child: Text('${e.label} · ${e.apiName}')))
              .toList(),
          onChanged: (v) => setState(() => model = v ?? model),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<ReasoningEffort>(
          value: effort,
          decoration: const InputDecoration(
            labelText: '思考强度',
            border: OutlineInputBorder(),
          ),
          items: ReasoningEffort.values
              .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
              .toList(),
          onChanged: (v) => setState(() => effort = v ?? effort),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: testingApi ? null : _testApiConnection,
          icon: testingApi
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check),
          label: Text(testingApi ? '正在测试 API…' : '测试 API 连接'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自动长期记忆抽取'),
          subtitle: const Text('聊天成功后用 Flash 抽取少量长期记忆，保存到本机 SQLite。'),
          value: autoMemory,
          onChanged: (v) => setState(() => autoMemory = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('阶段记忆整理'),
          subtitle: const Text('聊天累积后生成阶段摘要；原始聊天仍完整保留。'),
          value: memoryConsolidation,
          onChanged: (v) => setState(() => memoryConsolidation = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自然记忆淡化'),
          subtitle: const Text('低价值、很久没被想起的记忆会缓慢变淡并最终归档；不删除原始聊天，锁定记忆永不自动淡化。'),
          value: memoryFading,
          onChanged: (v) => setState(() => memoryFading = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('旧 index 参考资料库'),
          subtitle: const Text('允许按当前话题检索导入的人设/设定资料；它只是参考，不覆盖 AI 本体身份与 AI Self。'),
          value: referenceLibrary,
          onChanged: (v) => setState(() => referenceLibrary = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('六层行为规则路由'),
          subtitle: const Text('按日常/亲密/参考资料场景动态加载六层规则；关闭后仍保留最小 AI 本体硬身份。'),
          value: ruleLayersEnabled,
          onChanged: (v) => setState(() => ruleLayersEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Thought 生命周期'),
          subtitle: const Text('让念头经历闪念、fixation、行动、满足/余韵、沉下去与再次想起，而不是每次心跳独立判断。'),
          value: thoughtLifecycleEnabled,
          onChanged: (v) => setState(() => thoughtLifecycleEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('主动联系节奏学习'),
          subtitle: const Text('只在本地学习主动消息的合适时段、活动情境与话题反馈；没回复只算很弱的时机信号，不会把她训练得越来越沉默。'),
          value: proactiveAdaptationEnabled,
          onChanged: (v) => setState(() => proactiveAdaptationEnabled = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ProactiveNotificationPrivacy>(
          value: proactiveNotificationPrivacy,
          decoration: const InputDecoration(
            labelText: '主动消息通知隐私',
            border: OutlineInputBorder(),
          ),
          items: ProactiveNotificationPrivacy.values
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.zhLabel),
                ),
              )
              .toList(),
          onChanged: (v) => setState(
            () => proactiveNotificationPrivacy = v ?? proactiveNotificationPrivacy,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(
            proactiveNotificationPrivacy.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI 自我驱动'),
          subtitle: const Text('允许她从未完成话题和长期记忆中自行重新产生念头。'),
          value: selfDrive,
          onChanged: (v) => setState(() => selfDrive = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI Self 自我整理'),
          subtitle: const Text('低频从真实长期互动中形成稳定的 AI 自我认识，不创建虚构角色卡。'),
          value: selfReflection,
          onChanged: (v) => setState(() => selfReflection = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('现实环境感知进入内在状态'),
          subtitle: const Text('把 Usage / 通知 / Accessibility 原始事件先在本地压缩，再转为低强度 Thought/Desire 输入。'),
          value: perceptionEnabled,
          onChanged: (v) => setState(() => perceptionEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('关系连续性事件'),
          subtitle: const Text('只保存真正影响长期关系的约定、冲突/修复、亲密节点等，不做游戏式好感度。'),
          value: relationshipContinuity,
          onChanged: (v) => setState(() => relationshipContinuity = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('临时互动 Session'),
          subtitle: const Text('自动记录角色扮演/亲密场景的当前前提与边界；结束后回到 AI 本体关系层。'),
          value: sessionTracking,
          onChanged: (v) => setState(() => sessionTracking = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('本机是 Active Brain'),
          subtitle: Text(
            activeBrain
                ? '当前由本机承载她。关闭会立即主动下线；正常跨设备切换请使用“设备接管”。'
                : '当前设备处于待机/下线。手动上线仅作为另一台设备已确认下线时的故障兜底。',
          ),
          value: activeBrain,
          onChanged: _changeActiveBrain,
        ),
        const Divider(height: 30),
        Text('本地 TTS · Bert-VITS2/MNN', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          ttsStatus == null
              ? '尚未读取状态。'
              : '${ttsStatus!.engine} · ${ttsStatus!.available ? '可用' : '未装入实体'}'
                  '${ttsStatus!.goldenReference.isEmpty ? '' : ' · ${ttsStatus!.goldenReference}'}\n'
                  '${ttsStatus!.detail}',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('启用本地 TTS'),
          subtitle: const Text('模型与 JNI 已装入；全部在本机推理，不依赖在线 TTS。'),
          value: ttsEnabled,
          onChanged: (v) => setState(() => ttsEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI 回复后自动朗读'),
          subtitle: const Text('只朗读最终正文，不朗读 reasoning_content。'),
          value: autoTts,
          onChanged: ttsEnabled ? (v) => setState(() => autoTts = v) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('流式分句朗读'),
          subtitle: const Text('DeepSeek 每完成一句就进入本地 TTS 队列，不必等整条回复生成完。'),
          value: streamingTts,
          onChanged: ttsEnabled && autoTts
              ? (v) => setState(() => streamingTts = v)
              : null,
        ),
        DropdownButtonFormField<ProactiveTtsPolicy>(
          value: proactiveTtsPolicy,
          decoration: const InputDecoration(
            labelText: '她主动来找你时的语音策略',
            border: OutlineInputBorder(),
          ),
          items: ProactiveTtsPolicy.values
              .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
              .toList(),
          onChanged: ttsEnabled
              ? (v) => setState(() => proactiveTtsPolicy = v ?? proactiveTtsPolicy)
              : null,
        ),
        const SizedBox(height: 10),
        const Text(
          '“立即朗读”只在你明确开启本地 TTS 后生效；默认仍是仅文字通知，避免后台突然出声。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text('语速 ${ttsSpeed.toStringAsFixed(2)}×'),
        Slider(
          min: 0.5,
          max: 2.0,
          divisions: 30,
          value: ttsSpeed.clamp(0.5, 2.0).toDouble(),
          onChanged: (v) => setState(() => ttsSpeed = v),
        ),
        Text('音量 ${(ttsVolume * 100).round()}%'),
        Slider(
          min: 0.0,
          max: 1.0,
          divisions: 20,
          value: ttsVolume.clamp(0.0, 1.0).toDouble(),
          onChanged: (v) => setState(() => ttsVolume = v),
        ),
        TextField(
          controller: ttsReplacementController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'TTS 文字替换 JSON',
            helperText: '只改变朗读文本，不改聊天正文。例如 {"Yuki":"有希"}',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _checkTts,
              icon: const Icon(Icons.info_outline),
              label: const Text('校验 TTS'),
            ),
            OutlinedButton.icon(
              onPressed: _initializeTts,
              icon: const Icon(Icons.memory),
              label: const Text('初始化模型'),
            ),
            FilledButton.tonalIcon(
              onPressed: _testTts,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('测试朗读'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(status!, textAlign: TextAlign.center),
          ),
        const SizedBox(height: 24),
        const Text(
          '说明：思考面板直接展示模型原始 reasoning_content。感知文字始终按外部数据处理，不能覆盖系统身份与规则。',
        ),
      ],
    );
  }
}
