import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../integrations/qq_private/qq_private_config.dart';

class QqPrivateSettingsPage extends StatefulWidget {
  const QqPrivateSettingsPage({super.key});
  @override
  State<QqPrivateSettingsPage> createState() => _QqPrivateSettingsPageState();
}

class _QqPrivateSettingsPageState extends State<QqPrivateSettingsPage> {
  static const _channel = MethodChannel('ai_companion/qq_private_control');
  final _appId = TextEditingController();
  final _secret = TextEditingController();
  QqPrivateConfig _config = const QqPrivateConfig();
  Map<Object?, Object?> _state = const {};
  bool _loading = true, _busy = false, _hideSecret = true;
  String _notice = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) { if (!_busy) unawaited(_refresh()); });
  }

  Future<void> _load() async {
    try {
      final config = await QqPrivateConfig.read();
      if (!mounted) return;
      _config = config; _appId.text = config.appId; _secret.text = config.secret;
      await _refresh();
    } catch (_) { if (mounted) setState(() => _notice = '配置读取失败，请退出后重试。');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _refresh() async {
    try {
      final state = await _channel.invokeMapMethod<Object?, Object?>('snapshot') ?? const {};
      final config = await QqPrivateConfig.read();
      if (mounted) setState(() { _state = state; _config = config; });
    } catch (_) { if (mounted) setState(() => _notice = '暂时无法读取后台连接状态。'); }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _notice = ''; });
    try { await action(); await _refresh();
    } catch (_) { if (mounted) setState(() => _notice = '操作失败，请检查配置或稍后重试。');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _start() => _run(() async {
    final id = _appId.text.trim(), secret = _secret.text.trim();
    if (!RegExp(r'^\d{3,32}$').hasMatch(id) || secret.isEmpty || secret.length > 4096) {
      setState(() => _notice = '请填写机器人 AppID 和 AppSecret。'); return;
    }
    await _channel.invokeMethod<void>('stop');
    var config = await QqPrivateConfig.read();
    if (config.appId != id || config.secret != secret || config.namespace.isEmpty) {
      config = QqPrivateConfig(appId: id, secret: secret, namespace: QqPrivateConfig.randomId());
    }
    if (config.owner.isEmpty) {
      config = QqPrivateConfig(appId: id, secret: secret, namespace: config.namespace,
        pairCode: QqPrivateConfig.randomId(8),
        pairUntil: DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch);
    }
    await config.save();
    await _channel.invokeMethod<void>('start');
  });

  Future<void> _unbind() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('重新绑定 QQ？'),
      content: const Text('连接将关闭。再次启动后需要新的绑定码，旧 QQ 短期会话不会带给新绑定用户。App 的记忆和聊天不受此操作影响。'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('重新绑定'))]));
    if (accepted != true || !mounted) return;
    await _run(() async {
      await _channel.invokeMethod<void>('stop');
      final current = await QqPrivateConfig.read();
      await QqPrivateConfig(appId: current.appId, secret: current.secret,
        namespace: QqPrivateConfig.randomId()).save();
    });
  }

  static const _labels = {
    'stopped': '已关闭', 'starting': '正在启动', 'connecting': '连接中', 'online': '已连接',
    'reconnecting': '断线重连中', 'permission_error': '机器人权限不足，请检查腾讯平台配置',
    'credentials_error': '机器人凭据或访问权限无效，请关闭连接后检查',
    'not_running': '后台服务未运行，请关闭连接后重新启动',
    'startup_failed': '启动失败，请检查配置后重新启动', 'idle': '等待消息', 'bound': '已完成绑定',
    'generating': '正在生成回复', 'reply_sent': 'QQ 已接收回复', 'reply_failed': '本轮失败，请检查配置后重新发消息',
    'send_uncertain': '投递结果不确定；请先在 QQ 确认，系统不会自动重发',
    'generation_interrupted': '生成被中断；本轮不会自动重复请求',
    'message_expired': '消息超过测试版处理时限，请重新发送', 'queue_full': '待处理消息较多，请稍后发送',
    'waiting_app_chat': '等 App 当前聊天完成后再处理', 'brain_paused': '本机未启用或正在迁移，已暂停',
    'journal_error': 'QQ 本地投递记录异常，请关闭连接后重试',
  };

  @override
  void dispose() { _timer?.cancel(); _appId.dispose(); _secret.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final connected = _state['enabled'] == true;
    final paired = _config.owner.isNotEmpty;
    final codeValid = _config.pairCode.isNotEmpty && DateTime.now().millisecondsSinceEpoch < _config.pairUntil;
    return Scaffold(appBar: AppBar(title: const Text('QQ 私聊 · 测试版')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16), children: [
          const Text('先与你在 QQ 上聊起来', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          const Text('仅接收你绑定的私聊文字，跟随当前聊天正文模型。可以读取她已有的记忆；QQ 对话暂不写回 App 聊天、长期记忆或成长。群聊、其他用户和多媒体暂未接入。'),
          const SizedBox(height: 16),
          TextField(controller: _appId, enabled: !_busy && !connected,
            keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '机器人 AppID')),
          const SizedBox(height: 12),
          TextField(controller: _secret, enabled: !_busy && !connected, obscureText: _hideSecret,
            autocorrect: false, enableSuggestions: false,
            decoration: InputDecoration(labelText: '机器人 AppSecret', suffixIcon: IconButton(
              onPressed: () => setState(() => _hideSecret = !_hideSecret),
              icon: Icon(_hideSecret ? Icons.visibility_off : Icons.visibility)))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton(onPressed: _busy ? null : connected ? () => _run(() => _channel.invokeMethod<void>('stop')) : _start,
              child: Text(connected ? '关闭连接' : '保存并启动')),
            OutlinedButton(onPressed: _busy ? null : _unbind, child: const Text('重新绑定')),
          ]),
          const SizedBox(height: 12),
          Text('连接：${_labels[_state['connection']] ?? '未连接'}'),
          Text('处理：${_labels[_state['task']] ?? '等待消息'}'),
          Text(paired ? '身份：已绑定你的私聊' : '身份：尚未绑定，当前不会读取私人记忆'),
          if (!paired && codeValid) ...[
            const SizedBox(height: 16),
            const Text('用你的 QQ 私聊机器人，发送下面这条命令完成绑定（十分钟有效）。不要把绑定码发到群里。'),
            SelectableText('/绑定 ${_config.pairCode}', style: const TextStyle(fontSize: 20)),
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: '/绑定 ${_config.pairCode}')),
              icon: const Icon(Icons.copy), label: const Text('复制绑定命令')),
          ],
          if (!paired && connected && !codeValid) const Text('绑定码已过期，请关闭连接后重新启动。'),
          const SizedBox(height: 16),
          const Text('接入步骤：在 QQ 开放平台创建或绑定机器人，选择 WebSocket，并将自己的 QQ 加入允许使用范围；填入上方凭据后启动，再私聊发送绑定命令。'),
          const SizedBox(height: 12),
          const Text('连接独立于悬浮球，可正常使用手机和 QQ。请允许 App 后台运行；关机、断网、强制停止或系统省电限制可能导致延迟。首版没有开机自动启动。'),
          if (_notice.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_notice)),
        ]));
  }
}
