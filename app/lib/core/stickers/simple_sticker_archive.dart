import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Converts a human-named folder into the existing indexed pack format.
/// The caller validates all ZIP paths and expansion limits before this runs.
class SimpleStickerArchive {
  static String packId(String name) =>
      'user-${sha256.convert(utf8.encode(name.trim())).toString().substring(0, 32)}';

  static bool ignored(String path) =>
      path.startsWith('__MACOSX/') || p.posix.basename(path) == '.DS_Store';

  static String imageExtension(List<int> bytes) {
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return '.webp';
    }
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      return '.png';
    }
    if (bytes.length >= 6 &&
        const [
          'GIF87a',
          'GIF89a',
        ].contains(ascii.decode(bytes.sublist(0, 6), allowInvalid: true))) {
      return '.gif';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return '.jpg';
    }
    throw const FormatException('图片内容不是受支持的 JPG、PNG、GIF 或 WebP');
  }

  static Future<void> write(Archive archive, Directory root) async {
    final entries = archive.files
        .where((e) => e.isFile && !ignored(e.name))
        .toList();
    if (entries.isEmpty || entries.length > 1200) {
      throw const FormatException('普通表情包需要 1–1200 张图片');
    }
    String? name;
    for (final entry in entries) {
      final parts = entry.name.replaceAll('\\', '/').split('/');
      if (parts.length != 2 ||
          parts.first.trim().isEmpty ||
          (name != null && name != parts.first)) {
        throw const FormatException('普通 ZIP 格式应为：包名文件夹/带描述文件名的图片');
      }
      name = parts.first;
    }
    name = name!.trim();
    if (name.runes.length > 80) throw const FormatException('表情包名称不能超过80字');
    final id = packId(name);
    await Directory(p.join(root.path, 'memes')).create(recursive: true);
    final rows = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final entry in entries) {
      final extension = p.extension(entry.name).toLowerCase();
      if (!const {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.webq',
      }.contains(extension)) {
        throw FormatException('普通表情包中有不支持的文件：${entry.name}');
      }
      if (entry.size <= 0 || entry.size > 25 * 1024 * 1024) {
        throw const FormatException('单张图片为空或超过25 MB');
      }
      final bytes = entry.content;
      final actual = imageExtension(bytes);
      if (extension == '.webq' && actual != '.webp') {
        throw const FormatException('.webq 文件的内容必须为 WebP');
      }
      final hash = sha256.convert(bytes).toString();
      if (!seen.add(hash)) continue;
      final caption = p.basenameWithoutExtension(entry.name).trim();
      if (caption.isEmpty || caption.runes.length > 240) {
        throw const FormatException('图片文件名描述需要1–240字');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width > 8192 ||
            descriptor.height > 8192 ||
            descriptor.width * descriptor.height > 32 * 1024 * 1024) {
          throw const FormatException('图片尺寸过大');
        }
        final codec = await descriptor.instantiateCodec(targetWidth: 128);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      final path = 'memes/$hash$actual';
      await File(p.join(root.path, path)).writeAsBytes(bytes);
      rows.add({
        'path': path,
        'file_name': p.basename(path),
        'caption': caption,
        'keywords': '',
        'tag': name,
        'enabled': 1,
        'tone_scope': 'general',
        'intensity': 1,
      });
    }
    final index = await openDatabase(
      p.join(root.path, 'index.db'),
      singleInstance: false,
    );
    try {
      await index.execute(
        'CREATE TABLE memes(path TEXT PRIMARY KEY, file_name TEXT, caption TEXT, keywords TEXT, tag TEXT, enabled INTEGER, tone_scope TEXT, intensity INTEGER)',
      );
      await index.transaction((txn) async {
        for (final row in rows) {
          await txn.insert('memes', row);
        }
      });
    } finally {
      await index.close();
    }
    await File(p.join(root.path, 'manifest.json')).writeAsString(
      jsonEncode({
        'id': id,
        'name': name,
        'version': '1',
        'license': 'user-provided',
        'description': '从图片文件名导入',
        'sticker_count': rows.length,
        'imported_at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }
}
