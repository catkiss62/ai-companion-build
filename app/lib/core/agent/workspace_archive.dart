import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../platform/android_bridge.dart';
import 'commission_workspace.dart';

class WorkspaceArchive {
  static Future<bool> export(CommissionWorkspace workspace) async {
    final temp = await (await getTemporaryDirectory()).createTemp(
      'commission_',
    );
    try {
      final file = File('${temp.path}/workspace.zip');
      final encoder = ZipFileEncoder()..create(file.path);
      try {
        Future<void> add(String name, String content) async {
          final source = File('${temp.path}/$name');
          if (name.endsWith('.png')) { await source.writeAsBytes(base64Decode(content), flush:true); }
          else { await source.writeAsString(content, flush:true); }
          await encoder.addFile(source, name);
        }

        await add('workspace-version', '1');
        for (final name in await workspace.list()) {
          await add(name, await workspace.read(name));
        }
      } finally {
        await encoder.close();
      }
      return await AndroidBridge.instance.saveCollectedStickerZip(
        file.path,
        'Little-Whale-Workspace.zip',
      );
    } finally {
      await temp.delete(recursive: true);
    }
  }

  static Future<String> import(CommissionWorkspace workspace) async {
    final picked = await AndroidBridge.instance.openPlainBackup();
    final path = picked?['filePath'] as String?;
    if (path == null) return '';
    final file = File(path);
    try {
      if (await file.length() > 32 * 1024 * 1024)
        throw const FormatException('工作区压缩包过大');
      final source = InputFileStream(path);
      try {
        final archive = ZipDecoder().decodeStream(source);
        final marker = archive.findFile('workspace-version');
        if (marker == null ||
            marker.size != 1 ||
            utf8.decode(marker.content) != '1')
          throw const FormatException('无法识别的工作区');
        final imported = <String, String>{};
        var total = 0;
        for (final item in archive.files) {
          if (item.name == 'workspace-version') continue;
          CommissionWorkspace.validate(item.name);
          total += item.size;
          if (!item.isFile ||
              item.size > CommissionWorkspace.maxBytes ||
              total > 32 * 1024 * 1024 ||
              imported.containsKey(item.name))
            throw const FormatException('无效工作区条目');
          final body = item.name.endsWith('.png') ? base64Encode(item.content) : utf8.decode(item.content);
          if (item.name.endsWith('.json')) {
            final data = jsonDecode(body);
            if (data is! Map ||
                data['goal'] is! String ||
                data['at'] is! int ||
                '任务-${data['id']}.json' != item.name)
              throw const FormatException('无效任务记录');
          }
          imported[item.name] = body;
        }
        final existing = (await workspace.list()).toSet();
        for (final entry in imported.entries.where(
          (e) => !existing.contains(e.key),
        )) {
          await workspace.write(entry.key, entry.value);
        }
        return '已导入 ${imported.keys.where((k) => !existing.contains(k)).length} 项，已有同名文件保留';
      } finally {
        await source.close();
      }
    } finally {
      await file.delete();
    }
  }
}
