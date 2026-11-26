import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../platform/android_bridge.dart';
import 'commission_workspace.dart';

class WorkspaceArchive {
  static const _maxBytes = 512 * 1024 * 1024;

  static void _checkSize(int bytes) {
    if (bytes > _maxBytes) throw const FormatException('工作区备份超过 512 MiB');
  }

  static Future<bool> export(CommissionWorkspace workspace) async {
    final temp = await (await getTemporaryDirectory()).createTemp(
      'commission_',
    );
    try {
      final file = File('${temp.path}/workspace.zip');
      final encoder = ZipFileEncoder()..create(file.path);
      try {
        var total = 0;
        Future<void> add(String name, String content) async {
          final source = File('${temp.path}/$name');
          if (name.endsWith('.png')) { await source.writeAsBytes(base64Decode(content), flush:true); }
          else { await source.writeAsString(content, flush:true); }
          total += await source.length();
          _checkSize(total);
          await encoder.addFile(source, name);
          await source.delete();
        }

        await add('workspace-version', '1');
        for (final name in await workspace.list()) {
          await add(name, await workspace.read(name));
        }
      } finally {
        await encoder.close();
      }
      _checkSize(await file.length());
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
      _checkSize(await file.length());
      final source = InputFileStream(path);
      try {
        final archive = ZipDecoder().decodeStream(source);
        final marker = archive.findFile('workspace-version');
        if (marker == null ||
            marker.size != 1 ||
            utf8.decode(marker.content) != '1')
          throw const FormatException('无法识别的工作区');
        final staged = await (await getTemporaryDirectory()).createTemp('work_import_');
        try {
          final names = <String>{};
          var total = marker.size;
          for (final item in archive.files) {
            if (item.name == 'workspace-version') continue;
            final name = item.name;
            CommissionWorkspace.validate(name);
            if (!item.isFile || item.size > CommissionWorkspace.limit(name) || !names.add(name)) {
              throw const FormatException('无效工作区条目');
            }
            total += item.size;
            _checkSize(total);
            final bytes = item.content;
            if (bytes.length != item.size) throw const FormatException('工作区条目长度异常');
            if (!name.endsWith('.png')) {
              final body = utf8.decode(bytes);
              if (name.endsWith('.json')) CommissionWorkspace.decodeRecords(name, body);
            }
            await File('${staged.path}/$name').writeAsBytes(bytes);
            item.clear();
          }
          final existing = (await workspace.list()).toSet();
          var count = 0;
          for (final name in names) {
            final source = File('${staged.path}/$name');
            if (name.startsWith('会话-')) {
              final turns = CommissionWorkspace.decodeRecords(name, await source.readAsString());
              await workspace.mergeTurns(name, turns, keepExisting: true);
            } else {
              if (existing.contains(name)) continue;
              final body = name.endsWith('.png') ? base64Encode(await source.readAsBytes()) : await source.readAsString();
              await workspace.write(name, body);
            }
            count++;
          }
          return '已导入或合并 $count 项，已有内容保留';
        } finally {
          await staged.delete(recursive: true);
        }
      } finally {
        await source.close();
      }
    } finally {
      await file.delete();
    }
  }
}
