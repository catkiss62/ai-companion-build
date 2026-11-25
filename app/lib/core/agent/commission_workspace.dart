import 'commission_thread.dart';
import '../creative/creative_contract.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Documents and task records live outside the companion conversation database.
class CommissionWorkspace {
  CommissionWorkspace({this.directory, this.tree});
  final Directory? directory;
  final String? tree;
  static const channel = MethodChannel('ai_companion/system');
  static final Set<String> writingTasks = {};
  static const maxBytes = 256 * 1024;
  static final names = RegExp(
    r'^(任务-[a-f0-9-]{36}\.json|作品-[\u3400-\u9fffA-Za-z0-9 _（）-]{1,75}\.html|截图-[a-f0-9-]{36}\.png|(?:报告|技能|停用技能)-[\u3400-\u9fffA-Za-z0-9 _-]{1,75}\.md)$',
  );
  static void validate(String name) {
    if (!names.hasMatch(name)) throw const FormatException('无效工作文件名');
  }

  static Future<CommissionWorkspace> open() async {
    final tree = Platform.isAndroid
        ? await channel.invokeMethod<String>('workTreeCurrent')
        : null;
    if (tree != null) return CommissionWorkspace(tree: tree);
    return CommissionWorkspace(
      directory: await Directory(
        '${(await getApplicationDocumentsDirectory()).path}/commission_workspace',
      ).create(recursive: true),
    );
  }

  bool sameLocation(CommissionWorkspace other) =>
      tree == other.tree && directory?.path == other.directory?.path;

  String get locationLabel {
    if (tree == 'workspace:downloads') return '下载 / 小鲸鱼工作区';
    if (tree == null) return 'App 内部工作区';
    final uri = Uri.tryParse(tree!);
    final parts = uri?.pathSegments;
    return parts == null || parts.isEmpty ? '自选手机文件夹' : parts.last;
  }

  static Future<bool> hasPrivateFiles() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/commission_workspace');
    if (!await dir.exists()) return false;
    return dir.list(followLinks: false).any(
      (entry) => entry is File && names.hasMatch(entry.uri.pathSegments.last),
    );
  }

  static Future<void> choose() => channel.invokeMethod<void>('workTreeChoose');
  static Future<void> useDefault({bool private = false}) =>
      channel.invokeMethod<void>('workTreeDefault', {'private': private});
  Future<List<String>> list() async {
    final values = directory == null
        ? await channel.invokeListMethod<String>('workTreeList', {
                'tree': tree,
              }) ??
              []
        : await directory!
              .list(followLinks: false)
              .where((e) => e is File)
              .map((e) => e.uri.pathSegments.last)
              .toList();
    return values.where(names.hasMatch).toList()..sort();
  }

  Future<String> read(String name) async {
    validate(name);
    if (directory == null)
      return (await channel.invokeMethod<String>('workTreeRead', {
        'tree': tree,
        'name': name,
      }))!;
    final file = File('${directory!.path}/$name');
    if (await file.length() > maxBytes) throw const FormatException('文件过大');
    return name.endsWith('.png') ? base64Encode(await file.readAsBytes()) : file.readAsString();
  }

  static final _signature = RegExp(r'^<!-- work-sha256:([a-f0-9]{64}) -->\n');
  Future<String> readHtml(String name, {String? expectedDigest}) async {
    if (!name.startsWith('作品-') || !name.endsWith('.html')) throw const FormatException('无效的作品文件');
    final raw = await read(name);
    final header = _signature.firstMatch(raw);
    final legacy = RegExp(r'^作品-([a-f0-9]{64})\.html$').firstMatch(name);
    final page = header == null ? raw : raw.substring(header.end);
    final digest = CreativeContract.hash(page);
    if ((header?.group(1) ?? legacy?.group(1)) != digest || expectedDigest != null && digest != expectedDigest) {
      throw const FormatException('作品文件内容已变化');
    }
    return page;
  }

  Future<String> savePage(String title, String page, Future<void> Function(String?)? checkpoint) async {
    final base = filename('作品', title).replaceFirst(RegExp(r'\.md$'), '');
    final digest = CreativeContract.hash(page);
    final encoded = '<!-- work-sha256:$digest -->\n$page';
    if (utf8.encode(encoded).length > maxBytes) throw const FormatException('文件过大');
    final existing = (await list()).toSet();
    for (var i = 1; ; i++) {
      final name = i == 1 ? '$base.html' : '$base（$i）.html';
      validate(name);
      if (existing.contains(name)) {
        if (await read(name) == encoded) { await checkpoint?.call(name); return name; }
        continue;
      }
      await checkpoint?.call(name);
      if (directory == null) {
        final created = await channel.invokeMethod<bool>('workTreeCreate', {'tree':tree,'name':name,'text':encoded});
        if (created != true) { existing.add(name); continue; }
      } else {
        final file = File('${directory!.path}/$name');
        try { await file.create(exclusive:true); }
        on FileSystemException { if (!await file.exists()) rethrow; existing.add(name); continue; }
        try { await file.writeAsString(encoded, flush:true); } catch (_) { await file.delete(); rethrow; }
      }
      await readHtml(name, expectedDigest:digest);
      return name;
    }
  }

  Future<void> write(String name, String content) async {
    validate(name);
    final bytes = name.endsWith('.png') ? base64Decode(content) : utf8.encode(content);
    if (bytes.length > maxBytes)
      throw const FormatException('文件过大');
    if (directory == null) {
      await channel.invokeMethod<void>('workTreeWrite', {
        'tree': tree,
        'name': name,
        'text': content,
      });
    } else {
      final path = '${directory!.path}/$name';
      final temp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
      try {
        await temp.writeAsBytes(bytes, flush: true);
        await temp.rename(path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
  }

  Future<void> openExternally(String name) async {
    validate(name);
    await channel.invokeMethod<void>('workTreeOpen', {'name': name, 'tree': tree});
  }

  Future<void> remove(String name) async {
    validate(name);
    if (writingTasks.contains(name)) throw StateError('请先停止正在执行的委托');
    if (directory == null) {
      await channel.invokeMethod<void>('workTreeDelete', {
        'tree': tree,
        'name': name,
      });
    } else {
      await File('${directory!.path}/$name').delete();
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> conversations() async {
    final threads = <String, List<Map<String, dynamic>>>{};
    for (final name in (await list()).where((s) => s.startsWith('任务-'))) {
      try {
        final row = jsonDecode(await read(name));
        if (row is! Map<String, dynamic> ||
            row['id'] is! String ||
            row['goal'] is! String ||
            '任务-${row['id']}.json' != name)
          continue;
        threads.putIfAbsent(CommissionThread.key(row), () => []).add(row);
      } on FormatException {
        continue;
      }
    }
    // Task names are UUIDv7, so listing order is also creation order.
    return threads;
  }

  Future<List<Map<String, dynamic>>> conversation(String name) async {
    validate(name);
    final threads = await conversations();
    for (final rows in threads.values) {
      if (rows.any((row) => '任务-${row['id']}.json' == name)) return rows;
    }
    throw const FormatException('工作记录已删除或无法读取');
  }

  // Only compact summaries enter ordinary follow-up handling. Full reports
  // are retrieved explicitly and old completed turns never enter memory jobs.
  Future<List<Map<String, dynamic>>> recent({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now())
        .subtract(const Duration(hours: 48))
        .millisecondsSinceEpoch;
    final rows = <Map<String, dynamic>>[];
    for (final name in (await list()).where((s) => s.startsWith('任务-'))) {
      final Object? row;
      try {
        row = jsonDecode(await read(name));
      } on FormatException {
        continue;
      }
      if (row is Map<String, dynamic> &&
          row['state'] == 'completed' &&
          row['at'] is int &&
          row['at'] >= cutoff)
        rows.add(row);
    }
    rows.sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    return rows.take(3).toList();
  }

  static String filename(String kind, String title) {
    var safe = title
        .replaceAll(RegExp(r'[^\u3400-\u9fffA-Za-z0-9 _-]'), ' ')
        .trim();
    if (safe.isEmpty) safe = '未命名';
    return '$kind-${String.fromCharCodes(safe.runes.take(64))}.md';
  }
}
