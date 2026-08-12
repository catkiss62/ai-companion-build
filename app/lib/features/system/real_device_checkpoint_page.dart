import 'package:flutter/material.dart';

import '../../core/diagnostics/preflight_diagnostics.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/tts/tts_service.dart';

/// Guided first-hardware checkpoint.
///
/// This page deliberately does not mutate relationship state or simulate model
/// replies. It only invokes existing Android/TTS diagnostics and links to the
/// real feature surfaces that must be exercised on hardware.
class RealDeviceCheckpointPage extends StatefulWidget {
  const RealDeviceCheckpointPage({super.key});

  @override
  State<RealDeviceCheckpointPage> createState() => _RealDeviceCheckpointPageState();
}

class _RealDeviceCheckpointPageState extends State<RealDeviceCheckpointPage> {
  static const _ttsProbeText =
      '晚上好，我在这里。Yuki，今天也一起慢慢来。现在开始测试本地语音。';

  final preflight = PreflightDiagnosticsService();
  final tts = TtsService();
  final android = AndroidBridge.instance;

  PreflightSnapshot? quick;
  PreflightSnapshot? deep;
  bool busy = false;
  String note = '建议先只在手机上完成 1～6，再使用手机和平板完成第 7 项。';

  Future<void> _runPreflight({required bool deepMode}) async {
    if (busy) return;
    setState(() {
      busy = true;
      note = deepMode
          ? '正在执行深度自检：校验 37 项 TTS 黄金负载并初始化 JNI/MNN…'
          : '正在执行快速自检…';
    });
    try {
      final result = await preflight.run(deep: deepMode);
      if (!mounted) return;
      setState(() {
        if (deepMode) {
          deep = result;
        } else {
          quick = result;
        }
        note = result.failures == 0
            ? result.warnings == 0
                ? '自检通过，没有发现阻断项。'
                : '没有阻断项，但有 ${result.warnings} 项运行条件需要留意。'
            : '发现 ${result.failures} 个阻断项；先处理后再继续后面的真机项目。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => note = '自检没有完成：${e.runtimeType}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _diagnoseTtsBridge() async {
    if (busy) return;
    setState(() {
      busy = true;
      note = '正在执行 TTS 分阶段诊断：会真正初始化并生成一段 WAV，但不会播放声音…';
    });
    try {
      final result = await tts.diagnose();
      if (!mounted) return;
      final labels = result.diagnosticTrace.map(_ttsStageLabel).join(' → ');
      setState(() {
        if (result.diagnosticOk) {
          note = 'TTS 分阶段诊断通过。$labels\n生成 WAV：${result.wavBytes} bytes。下一步再做实际发声。';
        } else {
          final stage = result.diagnosticStage.isEmpty
              ? '尚未进入可识别阶段'
              : _ttsStageLabel(result.diagnosticStage);
          final detail = result.detail.isEmpty ? '没有返回额外错误文本' : result.detail;
          note = 'TTS 分阶段诊断失败。最后通过：$stage\n$detail'
              '${labels.isEmpty ? '' : '\n阶段：$labels'}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => note = 'TTS 分阶段诊断没有完成：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _ttsStageLabel(String stage) => switch (stage) {
        'artifact_integrity' => '黄金资源',
        'legacy_classloader' => 'Legacy ClassLoader',
        'engine_class' => 'LocalTTSEngine 类',
        'engine_instance' => 'Engine 实例',
        'initialize_signature' => 'initialize 签名',
        'coroutine_context' => 'CoroutineContext',
        'continuation_proxy' => 'Continuation 代理',
        'initialize_invoked' => 'initialize 调用',
        'initialize_completed' => 'initialize 完成',
        'engine_ready' => 'JNI/MNN Ready',
        'generate_signature' => 'generateTTS 签名',
        'generateTTS_invoked' => 'generateTTS 调用',
        'generateTTS_completed' => 'generateTTS 完成',
        'wav_base64' => 'Base64 WAV',
        'wav_header' => 'RIFF/WAVE 校验',
        _ => stage,
      };

  Future<void> _playTtsProbe() async {
    if (busy) return;
    setState(() {
      busy = true;
      note = '正在初始化并播放固定测试语音…';
    });
    try {
      // preview() intentionally bypasses the user's automatic-TTS switch while
      // still applying the exact same pronunciation replacements and engine.
      final ok = await tts.preview(_ttsProbeText);
      if (!mounted) return;
      setState(() {
        note = ok
            ? '测试语音已提交播放。请确认音色、Yuki→有希读音、首句等待和是否有爆音/断句异常。'
            : '测试语音未能播放。请先运行深度自检，再导出脱敏诊断报告。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => note = '测试语音失败：${e.runtimeType}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _stopTts() async {
    try {
      await tts.stop();
      if (mounted) setState(() => note = '已发送停止语音命令。');
    } catch (e) {
      if (mounted) setState(() => note = '停止语音失败：${e.runtimeType}');
    }
  }

  Future<void> _refreshPerception() async {
    if (busy) return;
    setState(() {
      busy = true;
      note = '正在读取当前 Android 感知状态…';
    });
    try {
      final state = await android.getPerceptionState();
      if (!mounted) return;
      setState(() {
        note = '感知读取成功：使用情况访问=${state.usageAccess ? '有' : '无'}，'
            '亮屏=${state.screenInteractive ? '是' : '否'}，锁屏=${state.deviceLocked ? '是' : '否'}，'
            '通知监听=${state.notificationListenerConnected ? '已连接' : '未连接'}，'
            'Accessibility=${state.accessibilityConnected ? '已连接' : '未连接'}。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => note = '读取感知状态失败：${e.runtimeType}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickReady = quick?.readyForDeviceCheckpoint == true;
    final deepReady = deep?.readyForDeviceCheckpoint == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('第一次综合真机验收', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          '这不是新的功能页面，而是 v0.30.2 Checkpoint 的测试顺序。先确认单机底层，再测试双设备顶号；任何一项失败都优先保存脱敏诊断报告，不需要盲试多个 APK。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (note.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(note),
            ),
          ),
        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 10),
        _StepCard(
          number: 1,
          title: '快速自检',
          detail: '先检查数据库、Active Brain、权限、后台、Nearby 条件、音频路由和 TTS 文件是否可见。',
          status: quick == null
              ? '未执行'
              : quickReady
                  ? '无阻断项'
                  : '存在阻断项',
          actionLabel: '运行快速自检',
          onPressed: busy ? null : () => _runPreflight(deepMode: false),
        ),
        _StepCard(
          number: 2,
          title: '深度 TTS 自检',
          detail: '逐项核对 MejuTTS 黄金资源，并真正初始化 JNI/MNN；此步骤仍不会发声。',
          status: deep == null
              ? '未执行'
              : deepReady
                  ? '无阻断项'
                  : '存在阻断项',
          actionLabel: '运行深度自检',
          onPressed: busy ? null : () => _runPreflight(deepMode: true),
        ),
        _StepCard(
          number: 3,
          title: 'TTS 分阶段桥接诊断',
          detail: '真实走 Legacy ClassLoader → CoroutineContext/Continuation → initialize → JNI/MNN → generateTTS → WAV 校验，但不播放声音。失败时会直接显示最后通过的阶段。',
          status: '建议先执行',
          actionLabel: '运行分阶段诊断',
          onPressed: busy ? null : _diagnoseTtsBridge,
        ),
        _StepCard(
          number: 4,
          title: '本地 TTS 真正发声',
          detail: '固定测试句会经过和聊天完全相同的朗读预处理；重点听音色、首句等待、断句，以及 Yuki 是否读作“有希”。',
          status: '需要人工听感',
          actionLabel: '播放测试语音',
          secondaryLabel: '停止',
          onPressed: busy ? null : _playTtsProbe,
          onSecondary: busy ? null : _stopTts,
        ),
        _StepCard(
          number: 5,
          title: '权限、感知与后台',
          detail: '授权使用情况、通知访问、Accessibility、悬浮窗和通知后，切换 App / 锁屏 / 解锁，确认她能读到真实设备状态。',
          status: '需要真机',
          actionLabel: '读取当前感知',
          secondaryLabel: '打开权限页',
          onPressed: busy ? null : _refreshPerception,
          onSecondary: () => Navigator.of(context).pushNamed('/system'),
        ),
        _StepCard(
          number: 6,
          title: '悬浮窗、通知与后台存活',
          detail: '从权限与系统状态页开启悬浮陪伴，验证前后台切换、熄屏后恢复、通知展示和正常聊天入口。',
          status: '需要真机',
          actionLabel: '打开系统状态',
          onPressed: () => Navigator.of(context).pushNamed('/system'),
        ),
        _StepCard(
          number: 7,
          title: '手机 ↔ 平板顶号接管',
          detail: '只有前六项在手机上稳定后再做。验证 Nearby 发现、状态传输、旧设备先 standby、新设备再 Active，以及断线/迟到 ACK 不产生双 Active Brain。',
          status: '需要两台 Android',
          actionLabel: '打开设备接管',
          onPressed: () => Navigator.of(context).pushNamed('/transfer'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('失败时怎么做', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text(
                  '不要反复改权限或重装猜原因。进入“真机测试前自检”，运行一次对应级别的自检并保存脱敏报告。报告不含聊天正文、长期记忆、Reference、通知/Accessibility 原文或 API Key。',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).pushNamed('/preflight'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('打开自检与诊断报告'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.detail,
    required this.status,
    required this.actionLabel,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
  });

  final int number;
  final String title;
  final String detail;
  final String status;
  final String actionLabel;
  final VoidCallback? onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  child: Text('$number'),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                Text(status, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onPressed,
                    child: Text(actionLabel),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
