import 'dart:convert';

import '../database/app_database.dart';

/// Redacted stage telemetry for the local image-message pipeline.
///
/// It deliberately stores no path, bytes, caption, vision summary, provider
/// body or raw exception. Buckets are coarse enough to diagnose expensive
/// stages without reconstructing the selected image.
class AttachmentPipelineTelemetry {
  const AttachmentPipelineTelemetry._();

  static const settingKey = 'attachment_pipeline_telemetry_v1';
  static const _stages = <String>{
    'picker',
    'overlay_guard',
    'prepare',
    'commit',
    'vision',
  };
  static const _outcomes = <String>{
    'started',
    'completed',
    'cancelled',
    'failed',
    'busy',
    'not_called',
  };
  static const _sources = <String>{
    'gallery',
    'camera',
    'retry',
    'recovery',
    'unknown',
  };
  static const _errorCategories = <String>{
    'none',
    'cancelled',
    'timeout',
    'decode',
    'encode',
    'file_io',
    'api',
    'lease',
    'permission',
    'other',
  };

  static Future<void> record(
    AppDatabase db, {
    required String stage,
    required String outcome,
    String source = 'unknown',
    Duration? duration,
    int? byteSize,
    int? width,
    int? height,
    Object? error,
    DateTime? now,
  }) async {
    try {
      final safeStage = _stages.contains(stage) ? stage : 'prepare';
      final safeOutcome = _outcomes.contains(outcome) ? outcome : 'failed';
      final safeSource = _sources.contains(source) ? source : 'unknown';
      final state = _sanitize(_decode(await db.getSetting(settingKey)));
      final counts = Map<String, int>.from(
        state['counts']! as Map<String, int>,
      );
      final countKey = '${safeStage}_$safeOutcome';
      counts[countKey] = (counts[countKey] ?? 0) + 1;
      final recent = <Map<String, Object?>>[
        ...(state['recent']! as List).whereType<Map>().map(
              (item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
        <String, Object?>{
          'stage': safeStage,
          'outcome': safeOutcome,
          'source': safeSource,
          'at': (now ?? DateTime.now()).millisecondsSinceEpoch,
          'durationBucket': durationBucket(duration),
          'byteBucket': byteBucket(byteSize),
          'pixelBucket': pixelBucket(width, height),
          'errorCategory': errorCategory(error),
        },
      ];
      state
        ..['counts'] = counts
        ..['recent'] = recent.reversed.take(24).toList().reversed.toList()
        ..['lastStage'] = safeStage
        ..['lastOutcome'] = safeOutcome
        ..['lastAt'] = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await db.setSetting(settingKey, jsonEncode(state));
    } catch (_) {
      // Diagnostics must never make selecting or sending an image fail.
    }
  }

  static Future<Map<String, Object?>> snapshot(AppDatabase db) async {
    try {
      return _sanitize(_decode(await db.getSetting(settingKey)));
    } catch (_) {
      return _empty();
    }
  }

  static String durationBucket(Duration? duration) {
    if (duration == null) return 'unknown';
    final milliseconds = duration.inMilliseconds.clamp(0, 86400000);
    if (milliseconds < 250) return 'under_250ms';
    if (milliseconds < 1000) return '250_999ms';
    if (milliseconds < 3000) return '1_2s';
    if (milliseconds < 8000) return '3_7s';
    if (milliseconds < 20000) return '8_19s';
    return '20s_plus';
  }

  static String byteBucket(int? bytes) {
    if (bytes == null || bytes < 0) return 'unknown';
    if (bytes <= 1024 * 1024) return 'up_to_1mb';
    if (bytes <= 5 * 1024 * 1024) return '1_5mb';
    if (bytes <= 15 * 1024 * 1024) return '5_15mb';
    return '15mb_plus';
  }

  static String pixelBucket(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 'unknown';
    }
    final pixels = width * height;
    if (pixels <= 2 * 1000 * 1000) return 'up_to_2mp';
    if (pixels <= 8 * 1000 * 1000) return '2_8mp';
    if (pixels <= 20 * 1000 * 1000) return '8_20mp';
    return '20mp_plus';
  }

  static String errorCategory(Object? error) {
    if (error == null) return 'none';
    final value = error.toString().toLowerCase();
    if (value.contains('cancel')) return 'cancelled';
    if (value.contains('timeout') || value.contains('timed out')) {
      return 'timeout';
    }
    if (value.contains('decode') || value.contains('codec')) return 'decode';
    if (value.contains('encode') || value.contains('png')) return 'encode';
    if (value.contains('permission') || value.contains('denied')) {
      return 'permission';
    }
    if (value.contains('lease') || value.contains('占用')) return 'lease';
    if (value.contains('api') ||
        value.contains('http') ||
        value.contains('provider')) {
      return 'api';
    }
    if (value.contains('file') ||
        value.contains('path') ||
        value.contains('directory') ||
        value.contains('文件')) {
      return 'file_io';
    }
    return 'other';
  }

  static Map<String, Object?> correlateHistoricalExit(
    Map<String, Object?> snapshot, {
    required int historicalExitAt,
    required String historicalExitReason,
  }) {
    Map<String, Object?>? preceding;
    final recent = snapshot['recent'];
    if (recent is List && historicalExitAt > 0) {
      for (final raw in recent.whereType<Map>()) {
        final event = raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final at = (event['at'] as num?)?.toInt() ?? 0;
        if (at <= historicalExitAt &&
            (preceding == null ||
                at > ((preceding['at'] as num?)?.toInt() ?? 0))) {
          preceding = event;
        }
      }
    }
    final eventAt = (preceding?['at'] as num?)?.toInt() ?? 0;
    final delta = eventAt == 0 ? -1 : historicalExitAt - eventAt;
    final isAnr = historicalExitReason.toLowerCase().contains('anr');
    final possible = isAnr && delta >= 0 && delta <= 120000;
    return <String, Object?>{
      'historicalExitWasAnr': isAnr,
      'possibleRecentAttachmentStage': possible,
      'precedingStage': possible && preceding != null
          ? preceding['stage'] ?? ''
          : '',
      'precedingOutcome': possible && preceding != null
          ? preceding['outcome'] ?? ''
          : '',
      'deltaBucket': possible
          ? durationBucket(Duration(milliseconds: delta))
          : 'unavailable',
      'causalityEstablished': false,
      'pathsOrContentsIncluded': false,
    };
  }

  static Map<String, Object?> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _empty();
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return _empty();
    }
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> raw) {
    final countRaw = raw['counts'];
    final counts = <String, int>{};
    if (countRaw is Map) {
      for (final entry in countRaw.entries) {
        final key = entry.key.toString();
        final valid = _stages.any(
          (stage) => _outcomes.any((outcome) => key == '${stage}_$outcome'),
        );
        if (!valid) continue;
        counts[key] = ((entry.value as num?)?.toInt() ?? 0)
            .clamp(0, 1000000000)
            .toInt();
      }
    }
    final recent = <Map<String, Object?>>[];
    final recentRaw = raw['recent'];
    if (recentRaw is List) {
      for (final item in recentRaw.whereType<Map>()) {
        final stage = item['stage']?.toString() ?? '';
        final outcome = item['outcome']?.toString() ?? '';
        if (!_stages.contains(stage) || !_outcomes.contains(outcome)) continue;
        final source = item['source']?.toString() ?? '';
        final category = item['errorCategory']?.toString() ?? '';
        recent.add(<String, Object?>{
          'stage': stage,
          'outcome': outcome,
          'source': _sources.contains(source) ? source : 'unknown',
          'at': ((item['at'] as num?)?.toInt() ?? 0)
              .clamp(0, 4102444800000)
              .toInt(),
          'durationBucket': _safeDurationBucket(
            item['durationBucket']?.toString() ?? '',
          ),
          'byteBucket': _safeByteBucket(
            item['byteBucket']?.toString() ?? '',
          ),
          'pixelBucket': _safePixelBucket(
            item['pixelBucket']?.toString() ?? '',
          ),
          'errorCategory':
              _errorCategories.contains(category) ? category : 'other',
        });
      }
    }
    final lastStage = raw['lastStage']?.toString() ?? '';
    final lastOutcome = raw['lastOutcome']?.toString() ?? '';
    return <String, Object?>{
      'counts': counts,
      'recent': recent.reversed.take(24).toList().reversed.toList(),
      'lastStage': _stages.contains(lastStage) ? lastStage : 'never',
      'lastOutcome':
          _outcomes.contains(lastOutcome) ? lastOutcome : 'not_called',
      'lastAt': ((raw['lastAt'] as num?)?.toInt() ?? 0)
          .clamp(0, 4102444800000)
          .toInt(),
      'pathsIncluded': false,
      'imageBytesIncluded': false,
      'captionOrSummaryIncluded': false,
      'rawErrorsIncluded': false,
    };
  }

  static String _safeDurationBucket(String value) => const {
        'unknown',
        'under_250ms',
        '250_999ms',
        '1_2s',
        '3_7s',
        '8_19s',
        '20s_plus',
      }.contains(value)
          ? value
          : 'unknown';

  static String _safeByteBucket(String value) => const {
        'unknown',
        'up_to_1mb',
        '1_5mb',
        '5_15mb',
        '15mb_plus',
      }.contains(value)
          ? value
          : 'unknown';

  static String _safePixelBucket(String value) => const {
        'unknown',
        'up_to_2mp',
        '2_8mp',
        '8_20mp',
        '20mp_plus',
      }.contains(value)
          ? value
          : 'unknown';

  static Map<String, Object?> _empty() => _sanitize(const {});
}
