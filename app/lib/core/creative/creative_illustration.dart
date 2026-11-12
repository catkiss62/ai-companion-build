import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../illustration/illustration_client.dart';
import '../storage/media_blob_storage.dart';

typedef CreativeAlbumImage = ({
  String workId,
  String blobId,
  String description,
  bool depictsCompanion,
});

/// Each work has its own allowlist; a URL alone never grants access to a blob.
class CreativeIllustration {
  static const enabledKey = 'creative_illustration_enabled_v1';
  static const ownerPrefix = 'creative_media_v1:';
  static const urlPrefix = 'https://companion-work.invalid/generated/';
  static const maxBytes = 4 * 1024 * 1024;
  static const maxImages = 3;
  static const maxExportBytes = 18 * 1024 * 1024;
  static final _url = RegExp('${RegExp.escape(urlPrefix)}([0-9a-f]{64})[.]image');

  static String owner(String workId, String blobId) => '$ownerPrefix$workId:$blobId';
  static String url(String blobId) => '$urlPrefix$blobId.image';
  static Set<String> references(String html) =>
      _url.allMatches(html).map((match) => match.group(1)!).toSet();

  static Future<Map<String, Map<String, Object>>> load(
    AppDatabase db, String workId, String html, {bool requiredForPreview = false}
  ) async {
    final ids = references(html);
    if (ids.length > maxImages) throw const FormatException('作品配图最多三张');
    final assets = <String, Map<String, Object>>{};
    if (ids.isEmpty) return assets;
    final storage = MediaBlobStorage(db: db);
    for (final id in ids) {
      final blob = await db.getSetting(owner(workId, id)) == id
          ? await db.mediaBlobById(id) : null;
      if (blob != null && blob.byteSize > 0 && blob.byteSize <= maxBytes) {
        final file = await storage.fileFor(blob.originalPath);
        if (await file.exists() && await file.length() == blob.byteSize) {
          final bytes = await file.readAsBytes();
          final mime = IllustrationClient.imageType(bytes);
          if (mime != null && sha256.convert(bytes).toString() == id) {
            assets[url(id)] = {'mime': mime, 'bytes': bytes};
            continue;
          }
        }
      }
      if (requiredForPreview) throw const FormatException('配图未找到，请检查工具返回的地址或调整版式');
    }
    return assets;
  }

  static Future<String> standaloneHtml(AppDatabase db, String workId, String html) async {
    final assets = await load(db, workId, html);
    var total = utf8.encode(html).length;
    for (final match in _url.allMatches(html)) {
      final bytes = assets[match.group(0)]?['bytes'] as List<int>?;
      if (bytes != null) total += ((bytes.length + 2) ~/ 3) * 4;
      if (total > maxExportBytes) throw const FormatException('作品内嵌配图后超过 HTML 导出容量');
    }
    final dataUrls = <String, String>{
      for (final entry in assets.entries)
        entry.key: 'data:${entry.value['mime']};base64,${base64Encode(entry.value['bytes'] as List<int>)}',
    };
    return html.replaceAllMapped(_url, (match) => dataUrls[match.group(0)] ?? 'data:,');
  }
}
