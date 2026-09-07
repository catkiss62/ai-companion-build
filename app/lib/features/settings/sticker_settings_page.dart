import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/stickers/sticker_pack.dart';
import '../../core/stickers/sticker_pack_storage.dart';

class StickerSettingsPage extends StatefulWidget {
  const StickerSettingsPage({super.key});

  @override
  State<StickerSettingsPage> createState() => _StickerSettingsPageState();
}

class _StickerSettingsPageState extends State<StickerSettingsPage> {
  final _db = AppDatabase.instance;
  final _android = AndroidBridge.instance;
  late final StickerPackStorage _storage = StickerPackStorage(db: _db);
  List<StickerPackMeta> _packs = const [];
  Set<String> _enabled = <String>{};
  String _mode = 'natural';
  bool _busy = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _db.ensureReady();
    final packs = await _storage.scanPacks();
    final enabled = await _storage.enabledPackIds();
    final mode = await _db.getSetting(StickerPackStorage.modeSetting) ?? 'natural';
    if (!mounted) return;
    setState(() {
      _packs = packs;
      _enabled = enabled;
      _mode = const {'off', 'low', 'natural', 'frequent'}.contains(mode)
          ? mode
          : 'natural';
      _busy = false;
    });
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    String? cachePath;
    try {
      final picked = await _android.openPlainBackup();
      cachePath = picked?['filePath']?.toString();
      if (cachePath == null || cachePath.isEmpty) {
        if (mounted) setState(() => _status = '已取消导入。');
        return;
      }
      final result = await _storage.importZip(cachePath);
      if (mounted) {
        late final String status;
        if (result.packCount == 1) {
          final item = result.imports.single;
          status = item.replaced
              ? '已替换 ${StickerDisplayLabels.packName(item.pack)}（${result.stickerCount} 张）。'
              : '已导入 ${StickerDisplayLabels.packName(item.pack)}（${result.stickerCount} 张）。';
        } else {
          status = '已导入 ${result.packCount} 个图库，共 ${result.stickerCount} 张；'
              '其中 ${result.replacedCount} 个为更新。';
        }
        setState(() => _status = status);
      }
    } catch (error) {
      if (mounted) setState(() => _status = '导入失败：$error');
    } finally {
      if (cachePath != null) {
        try {
          final file = File(cachePath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _remove(StickerPackMeta pack) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除“${StickerDisplayLabels.packName(pack)}”？'),
            content: const Text('只删除本机导入的图库；已发送到聊天里的表情仍保留。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await _storage.deletePack(pack.id);
      if (mounted) {
        setState(() => _status = '已删除 ${StickerDisplayLabels.packName(pack)}。');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '删除失败：$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表情包')),
      body: _busy && _packs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('单聊表达强度', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text('只在轻量闲聊、且已选定言语行动后低频配图。不改欲望、不增加主动消息、不另调模型。'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _mode,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'off', child: Text('关闭')),
                            DropdownMenuItem(value: 'low', child: Text('偶尔')),
                            DropdownMenuItem(value: 'natural', child: Text('自然')),
                            DropdownMenuItem(value: 'frequent', child: Text('较多')),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) async {
                                  if (value == null) return;
                                  setState(() => _mode = value);
                                  await _db.setSetting(StickerPackStorage.modeSetting, value);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本机图库', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(
                          '可导入单个 dsh-meme 图库 ZIP，也可导入组合 ZIP'
                          '（根目录直接放 2～20 个图库 ZIP）。图库只保存在内部目录，'
                          '不进入查手机相册或当前 AI Companion 备份。',
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _import,
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('导入图库 ZIP'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(_status!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
                const SizedBox(height: 12),
                if (_packs.isEmpty)
                  const Card(child: ListTile(title: Text('还没有导入表情包')))
                else
                  for (final pack in _packs)
                    Card(
                      child: ListTile(
                        title: Text(StickerDisplayLabels.packName(pack)),
                        subtitle: Text('${pack.count} 张 · ${pack.license}${pack.description.isEmpty ? '' : '\n${pack.description}'}'),
                        isThreeLine: pack.description.isNotEmpty,
                        leading: Switch(
                          value: _enabled.contains(pack.id),
                          onChanged: _busy
                              ? null
                              : (value) async {
                                  await _storage.setPackEnabled(pack.id, value);
                                  await _load();
                                },
                        ),
                        trailing: IconButton(
                          tooltip: '删除本机图库',
                          onPressed: _busy ? null : () => _remove(pack),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
