import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/media_blob.dart';
import '../../core/storage/media_blob_storage.dart';
import '../../core/storage/media_storage_optimizer.dart';

class MediaCachePage extends StatefulWidget {
  const MediaCachePage({super.key});

  @override
  State<MediaCachePage> createState() => _MediaCachePageState();
}

class _MediaCachePageState extends State<MediaCachePage> {
  final AppDatabase _db = AppDatabase.instance;
  final MediaBlobStorage _blobStorage = MediaBlobStorage();
  late final MediaStorageOptimizer _optimizer = MediaStorageOptimizer(
    db: _db,
    blobStorage: _blobStorage,
  );
  List<MediaCacheEntry> _entries = const <MediaCacheEntry>[];
  final Set<String> _selected = <String>{};
  bool _loading = true;
  bool _working = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final entries = await _db.mediaCacheEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _selected.removeWhere(
        (id) => !entries.any((entry) => entry.blob.id == id),
      );
      _loading = false;
    });
  }

  Future<void> _scanAndOptimize() async {
    if (_working) return;
    setState(() {
      _working = true;
      _status = '正在只读扫描旧媒体…';
    });
    try {
      final report = await _optimizer.scan();
      if (!mounted) return;
      if (!report.hasWork) {
        setState(() => _status = report.missingFiles == 0
            ? '没有需要优化的旧媒体；重复执行不会改变现有数据。'
            : '没有可安全优化的旧媒体；发现 ${report.missingFiles} 组缺失文件，未做改动。');
        return;
      }
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认优化当前媒体存储？'),
              content: Text(
                '只读扫描结果：\n'
                '聊天媒体引用 ${report.messageReferences} 条\n'
                '相册引用 ${report.albumReferences} 条\n'
                '归一为 ${report.distinctBlobs} 份原图\n'
                '预计释放 ${_formatBytes(report.reclaimableBytes)}\n\n'
                '只整理当前运行库，原 .aibackup 文件不会被修改。',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('确认优化'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        if (mounted) setState(() => _status = '已取消；没有修改任何媒体。');
        return;
      }
      if (mounted) setState(() => _status = '正在建立共享引用并校验文件…');
      final result = await _optimizer.optimize();
      if (!mounted) return;
      setState(() {
        _status = '已迁移 ${result.migratedMessageReferences} 条聊天引用、'
            '${result.migratedAlbumReferences} 条相册引用；'
            '清理 ${result.deletedLegacyFiles} 个旧副本。';
      });
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _status = '媒体优化失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_working || _selected.isEmpty) return;
    final selectedEntries = _entries
        .where((entry) => _selected.contains(entry.blob.id))
        .toList(growable: false);
    final bytes = selectedEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.reclaimableBytes,
    );
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除所选聊天媒体缓存？'),
            content: Text(
              '将移除 ${selectedEntries.length} 份媒体、约 ${_formatBytes(bytes)}。'
              '相册中永久保存的图片不会出现在这里，也不会被删除；含文字的消息会保留文字。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除缓存'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _working = true);
    try {
      final orphans = await _db.deleteMediaCacheBlobs(Set<String>.from(_selected));
      for (final blob in orphans) {
        await _blobStorage.deleteBlobFiles(blob);
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _status = '已删除 ${orphans.length} 份未被其他位置引用的媒体缓存。';
      });
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _status = '删除缓存失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _entries.isNotEmpty && _selected.length == _entries.length;
    final selectedBytes = _entries
        .where((entry) => _selected.contains(entry.blob.id))
        .fold<int>(0, (sum, entry) => sum + entry.reclaimableBytes);
    return Scaffold(
      appBar: AppBar(title: const Text('媒体存储与缓存')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('旧媒体优化', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(
                          '先只读预览，再确认整理。仅按原图 SHA-256 合并当前运行库，原备份不会改变。',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _scanAndOptimize,
                            icon: _working
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_fix_high_rounded),
                            label: Text(_working ? '处理中…' : '扫描并预览优化'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '聊天媒体缓存',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: _entries.isEmpty || _working
                                  ? null
                                  : () => setState(() {
                                        if (allSelected) {
                                          _selected.clear();
                                        } else {
                                          _selected
                                            ..clear()
                                            ..addAll(_entries.map((entry) => entry.blob.id));
                                        }
                                      }),
                              child: Text(allSelected ? '取消全选' : '全选'),
                            ),
                          ],
                        ),
                        const Text('相册仍在引用的图片不会列入这里。删除一处不会影响其他消息或相册。'),
                        if (_entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: Text('暂无可清理的聊天媒体缓存')),
                          )
                        else
                          for (final entry in _entries)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _selected.contains(entry.blob.id),
                              onChanged: _working
                                  ? null
                                  : (checked) => setState(() {
                                        if (checked == true) {
                                          _selected.add(entry.blob.id);
                                        } else {
                                          _selected.remove(entry.blob.id);
                                        }
                                      }),
                              secondary: FutureBuilder<File>(
                                future: _blobStorage.fileFor(entry.blob.thumbnailPath),
                                builder: (context, snapshot) {
                                  final file = snapshot.data;
                                  if (file == null) {
                                    return const SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Icon(Icons.image_outlined),
                                    );
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      file,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(
                                        width: 52,
                                        height: 52,
                                        child: Icon(Icons.broken_image_outlined),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              title: Text('${entry.messageCount} 条聊天引用'),
                              subtitle: Text(_formatBytes(entry.reclaimableBytes)),
                            ),
                        if (_selected.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _working ? null : _deleteSelected,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: Text(
                                '删除所选 ${_selected.length} 项（${_formatBytes(selectedBytes)}）',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_status!, textAlign: TextAlign.center),
                ],
              ],
            ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}

