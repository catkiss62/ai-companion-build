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
    r'^(任务-[a-f0-9-]{36}\.json|(?:报告|技能|停用技能)-[\u3400-\u9fffA-Za-z0-9 _-]{1,75}\.md)$',
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

  static Future<void> choose() => channel.invokeMethod<void>('workTreeChoose');
  static Future<void> useDefault() =>
      channel.invokeMethod<void>('workTreeDefault');
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
    return file.readAsString();
  }

  Future<void> write(String name, String content) async {
    validate(name);
    if (utf8.encode(content).length > maxBytes)
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
        await temp.writeAsString(content, flush: true);
        await temp.rename(path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
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
