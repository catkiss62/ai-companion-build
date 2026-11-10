import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../illustration/illustration_job.dart';
import '../platform/android_bridge.dart';

/// A portable inspection report with text and reference metadata only. Its
/// format is distinct from the backup/restore protocol.
class CheckPackExport {
  const CheckPackExport(this.db);
  final AppDatabase db;

  Future<bool> save() async {
    final sql = await db.database;
    final state = await sql.transaction((txn) async {
      final diary = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [IllustrationJob.diaryEntriesKey],
        limit: 1,
      );
      final jobs = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key LIKE ?',
        whereArgs: ['${IllustrationJob.keyPrefix}%'],
      );
      final illustrations =
          [
            for (final row in jobs)
              if (IllustrationJob.decode(row['value'] as String?)
                  case final job?)
                {
                  for (final field in [
                    'state',
                    'source',
                    'owner_id',
                    'at',
                    'attempts',
                    'error',
                    'blob_id',
                    'description',
                    'style',
                    'positive',
                    'negative',
                  ])
                    if (job.containsKey(field)) field: job[field],
                },
          ]..sort(
            (a, b) =>
                ((b['at'] as num?) ?? 0).compareTo((a['at'] as num?) ?? 0),
          );
      return <String, Object?>{
        'messages': await txn.query(
          'messages',
          columns: [
            'id',
            'role',
            'content',
            'created_at',
            'model',
            'is_proactive',
          ],
          orderBy: 'created_at DESC, id DESC',
          limit: 600,
        ),
        'diary': diary.isEmpty
            ? const []
            : jsonDecode(diary.single['value'] as String),
        'album': await txn.query(
          'companion_album_candidates',
          columns: [
            'id',
            'source_kind',
            'source_id',
            'title',
            'vision_summary',
            'user_tags_json',
            'lifecycle_state',
            'blob_id',
            'original_content_sha256',
            'original_byte_size',
            'created_at',
            'saved_at',
          ],
          orderBy: 'created_at DESC, id DESC',
          limit: 600,
        ),
        'message_image_refs': await txn.query(
          'message_attachments',
          columns: [
            'id',
            'message_id',
            'blob_id',
            'byte_size',
            'source',
            'mime_type',
          ],
          orderBy: 'created_at DESC, id DESC',
          limit: 1200,
        ),
        'media_index': await txn.query(
          'media_blobs',
          columns: [
            'id',
            'original_sha256',
            'thumbnail_sha256',
            'byte_size',
            'mime_type',
            'width',
            'height',
            'message_ref_count',
            'album_ref_count',
          ],
          orderBy: 'created_at DESC, id DESC',
          limit: 1200,
        ),
        'illustrations': illustrations.take(400).toList(growable: false),
      };
    });
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final directory = await getTemporaryDirectory();
    final name = 'ai_companion_check_$stamp.txt';
    final file = File(p.join(directory.path, name));
    try {
      final encoded = jsonEncode({
        'format': 'ai-companion-inspection-report',
        'version': 1,
        'created_at': stamp,
        'restorable': false,
        'media_bytes_included': false,
        'limits': {
          'messages': 600,
          'album': 600,
          'media_index': 1200,
          'message_image_refs': 1200,
          'illustrations': 400,
        },
        'state': state,
      });
      if (utf8.encode(encoded).length > 16 * 1024 * 1024) {
        throw const FormatException('检查包文字超过 16 MiB 保存上限');
      }
      await file.writeAsString(encoded, flush: true);
      return await AndroidBridge.instance.saveDiagnosticReport(
        sourcePath: file.path,
        suggestedName: name,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
