import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/diagnostics/provider_health.dart';
import '../../core/illustration/illustration_client.dart';
import '../../core/illustration/illustration_job.dart';
import '../../core/illustration/illustration_prompt.dart';
import '../../core/storage/secure_config.dart';

class IllustrationSettingsPage extends StatefulWidget {
  const IllustrationSettingsPage({super.key});

  @override
  State<IllustrationSettingsPage> createState() =>
      _IllustrationSettingsPageState();
}

class _IllustrationSettingsPageState extends State<IllustrationSettingsPage> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _enabled = false;
  bool _autonomous = false;
  bool _diary = false;
  bool _busy = true;
  String _notice = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final connection = await SecureConfig.instance.readIllustration();
    if (!mounted) return;
    setState(() {
      _url.text = connection.baseUrl;
      _key.text = connection.apiKey;
      _enabled = connection.enabled;
      _autonomous = connection.autonomous;
      _diary = connection.diary;
      _busy = false;
    });
  }

  IllustrationConnection get _connection => IllustrationConnection(
    baseUrl: _url.text.trim(),
    apiKey: _key.text.trim(),
    enabled: _enabled,
    autonomous: _autonomous,
    diary: _diary,
  );

  Future<void> _save() async {
    final value = _connection;
    if (value.enabled && !value.configured) {
      setState(() => _notice = '启用前请填入 HTTPS 服务地址和 API Key。');
      return;
    }
    setState(() => _busy = true);
    try {
      await SecureConfig.instance.writeIllustration(value);
      await AppDatabase.instance.setSetting(
        IllustrationJob.configRevisionKey,
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
      if (mounted) setState(() => _notice = '生图设置已保存。');
    } catch (_) {
      if (mounted) setState(() => _notice = '生图设置保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final value = _connection;
    if (!value.configured) {
      setState(() => _notice = '试生成需要有效的 HTTPS 地址和 API Key。');
      return;
    }
    setState(() {
      _busy = true;
      _notice = '正在试生成一张图片…';
    });
    try {
      final result = await _generateTest(value);
      if (!mounted) return;
      setState(() => _notice = '连接成功，已收到一张测试图片。');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('试生成结果'),
          content: Image.memory(
            result.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('服务返回的图片无法解码。'),
          ),
        ),
      );
    } on IllustrationFailure catch (error) {
      if (mounted) setState(() => _notice = error.label);
    } catch (_) {
      if (mounted) setState(() => _notice = '试生成失败，请检查连接。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<IllustrationBytes> _generateTest(
    IllustrationConnection connection,
  ) async {
    final clock = Stopwatch()..start();
    String category = 'none';
    try {
      return await IllustrationClient().generate(
        connection,
        const IllustrationPrompt(
          'watercolor, quiet blue ocean, one small white cloud, wide shot, best quality',
          'nsfw, lowres, watermark',
        ),
        seed: IllustrationClient.newSeed(),
      );
    } on IllustrationFailure catch (error) {
      category = switch (error.code) {
        'authorization' || 'timeout' || 'network' => error.code,
        'quota' => 'quota_exhausted',
        'configuration' => 'missing_key',
        'invalid_image' => 'invalid_response',
        _ when (error.httpStatus ?? 0) >= 500 => 'server_http',
        _ when (error.httpStatus ?? 0) >= 400 => 'client_http',
        _ when error.httpStatus != null => 'invalid_response',
        _ => 'other',
      };
      rethrow;
    } catch (_) {
      category = 'other';
      rethrow;
    } finally {
      final success = category == 'none';
      await AppDatabase.instance.recordProviderHealthEvent(
        ProviderHealthEvent(
          lane: 'illustration',
          context: 'settings_test',
          primaryProvider: 'illustration_relay',
          primaryOutcome: success ? 'success' : 'failed',
          primaryErrorCategory: category,
          finalProvider: 'illustration_relay',
          finalOutcome: success ? 'success' : 'failed',
          resultCount: success ? 1 : 0,
          latencyBucket: ProviderHealth.latencyBucket(clock.elapsed),
        ),
      );
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('生图')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _url,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '生图服务地址',
            hintText: 'https://…',
          ),
        ),
        TextField(
          controller: _key,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '生图 API Key'),
        ),
        const SizedBox(height: 12),
        const Text('使用兼容 NovelAI V4.5 Full 的出图服务。内置可爱、成熟和 Q 版插画，由她选择画风和镜头。'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('启用生图'),
          subtitle: const Text('允许在聊天里请她画一张图'),
          value: _enabled,
          onChanged: _busy ? null : (value) => setState(() => _enabled = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('允许她主动生图'),
          subtitle: const Text('在聊天回复和原有主动消息中按情境附图'),
          value: _autonomous,
          onChanged: _busy || !_enabled
              ? null
              : (value) => setState(() => _autonomous = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('日记配图'),
          subtitle: const Text('每篇新日记最多配一张图，图片也会进入相册'),
          value: _diary,
          onChanged: _busy || !_enabled
              ? null
              : (value) => setState(() => _diary = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('保存设置'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _test,
              child: const Text('试生成一张'),
            ),
          ],
        ),
        const Text('试生成会调用服务一次，最多等待两分钟，可能产生费用。'),
        if (_notice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_notice),
          ),
      ],
    ),
  );
}
