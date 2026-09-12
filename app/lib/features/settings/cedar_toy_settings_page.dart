import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/mcp/cedar_toy_client.dart';
import '../../core/storage/secure_config.dart';

class CedarToySettingsPage extends StatefulWidget {
  const CedarToySettingsPage({super.key});

  @override
  State<CedarToySettingsPage> createState() => _CedarToySettingsPageState();
}

class _CedarToySettingsPageState extends State<CedarToySettingsPage> {
  final _db = AppDatabase.instance;
  final _secure = SecureConfig.instance;
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _token = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  bool _busy = false;
  bool _hasToken = false;
  String _status = '尚未测试连接';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _enabled = (await _db.getSetting('cedar_toy_enabled')) != '0';
    _hasToken = (await _secure.readCedarToyToken())?.trim().isNotEmpty ?? false;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } catch (error) {
      if (mounted) setState(() => _status = '失败：${_safeError(error)}');
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _account(bool loginOnly) => _run(() async {
        final username = _username.text.trim();
        final password = _password.text;
        if (username.isEmpty || password.isEmpty) {
          throw const FormatException('请输入小机用户名和密码');
        }
        final token = await CedarToyClient.loginOrRegister(
          username: username,
          password: password,
          loginOnly: loginOnly,
        );
        await _secure.writeCedarToyToken(token);
        if (!mounted) return;
        setState(() {
          _hasToken = true;
          _status = loginOnly ? '已恢复并安全保存连接' : '已注册/登录并安全保存连接';
        });
      });

  Future<void> _saveToken() => _run(() async {
        await _secure.writeCedarToyToken(_token.text);
        _token.clear();
        _hasToken = (await _secure.readCedarToyToken())?.trim().isNotEmpty ?? false;
        if (mounted) setState(() => _status = _hasToken ? 'Token 已安全保存' : 'Token 已清除');
      });

  Future<CedarToyClient> _client() async {
    final token = (await _secure.readCedarToyToken())?.trim() ?? '';
    if (token.isEmpty) throw const FormatException('请先连接小机或保存 Token');
    return CedarToyClient(token: token);
  }

  Future<void> _test() => _run(() async {
        final outcome = await (await _client()).listGames();
        if (outcome.isError) throw StateError('远端返回错误');
        await _db.setSetting(
          'cedar_toy_last_success_at',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        if (mounted) {
          setState(() => _status = outcome.text.trim().isEmpty
              ? '连接成功，但当前列表为空'
              : '连接成功：${_preview(outcome.text)}');
        }
      });

  Future<void> _bindingCode() => _run(() async {
        final outcome = await (await _client()).generateBindingToken();
        if (outcome.isError || outcome.text.trim().isEmpty) {
          throw StateError('远端没有返回绑定码');
        }
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('10 分钟绑定码'),
            content: SelectableText(CedarToyClient.redactSecrets(outcome.text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      });

  Future<void> _clear() => _run(() async {
        await _secure.clearCedarToyToken();
        if (mounted) setState(() {
          _hasToken = false;
          _status = '本机连接已清除；远端账号没有删除';
        });
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cedar Toy 游戏厅')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用 Cedar Toy'),
                    subtitle: const Text('所有远端游戏都会动态开放；一次游玩不会自动变成永久爱好。'),
                    value: _enabled,
                    onChanged: _busy
                        ? null
                        : (value) async {
                            setState(() => _enabled = value);
                            await _db.setSetting('cedar_toy_enabled', value ? '1' : '0');
                          },
                  ),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: '小机用户名'),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: '小机密码'),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton(
                      onPressed: _busy ? null : () => _account(false),
                      child: const Text('注册 / 登录小机'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _account(true),
                      child: const Text('恢复现有小机'),
                    ),
                  ]),
                  const Divider(height: 32),
                  TextField(
                    controller: _token,
                    decoration: InputDecoration(
                      labelText: 'Cedar Toy MCP Token',
                      helperText: _hasToken ? '本机已有安全保存的 Token' : 'Token 只进入系统安全存储',
                    ),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: _busy ? null : _saveToken,
                    child: const Text('安全保存 Token'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton(
                      onPressed: _busy ? null : _test,
                      child: const Text('测试连接与游戏列表'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _bindingCode,
                      child: const Text('生成 10 分钟绑定码'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _clear,
                      child: const Text('清除本机连接'),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text(_busy ? '正在连接 Cedar Toy…' : _status),
                  const SizedBox(height: 10),
                  const Text('密码仅用于本次 HTTPS 登录；成功后立即清空。Token、密码和绑定码不会进入模型 Prompt。'),
                ],
              ),
      );

  static String _preview(String value) {
    final clean = CedarToyClient.redactSecrets(value).replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= 180 ? clean : '${clean.substring(0, 180)}…';
  }

  static String _safeError(Object error) {
    final clean = CedarToyClient.redactSecrets(error.toString());
    return clean.length <= 160 ? clean : clean.substring(0, 160);
  }
}
