import 'dart:convert';

class DailyContinuityMoment {
  const DailyContinuityMoment({
    required this.id,
    required this.label,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String label;
  final String summary;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'summary': summary,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory DailyContinuityMoment.fromJson(Map<String, Object?> json) {
    return DailyContinuityMoment(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '共同经历',
      summary: json['summary'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class DailyContinuityThread {
  const DailyContinuityThread({
    required this.id,
    required this.title,
    required this.detail,
    this.topicKey = '',
  });

  final String id;
  final String title;
  final String detail;
  final String topicKey;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'topic_key': topicKey,
      };

  factory DailyContinuityThread.fromJson(Map<String, Object?> json) {
    return DailyContinuityThread(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      topicKey: json['topic_key'] as String? ?? '',
    );
  }
}

class DailyContinuityCare {
  const DailyContinuityCare({
    required this.id,
    required this.label,
    required this.text,
    required this.updatedAt,
    this.topicKey = '',
  });

  final String id;
  final String label;
  final String text;
  final DateTime updatedAt;
  final String topicKey;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'text': text,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'topic_key': topicKey,
      };

  factory DailyContinuityCare.fromJson(Map<String, Object?> json) {
    return DailyContinuityCare(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '她还放在心上',
      text: json['text'] as String? ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as num?)?.toInt() ?? 0,
      ),
      topicKey: json['topic_key'] as String? ?? '',
    );
  }
}

class DailyContinuityRecord {
  const DailyContinuityRecord({
    required this.id,
    required this.localDay,
    required this.windowStart,
    required this.windowEnd,
    required this.sharedMoments,
    required this.carriedThreads,
    required this.cares,
    required this.awarenessSummaries,
    required this.messageCount,
    required this.relationshipEventCount,
    required this.quietDay,
    required this.sourceFingerprint,
    required this.createdAt,
    required this.updatedAt,
    this.finalizedAt,
  });

  final String id;
  final String localDay;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<DailyContinuityMoment> sharedMoments;
  final List<DailyContinuityThread> carriedThreads;
  final List<DailyContinuityCare> cares;
  final List<String> awarenessSummaries;
  final int messageCount;
  final int relationshipEventCount;
  final bool quietDay;
  final String sourceFingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;

  bool get isFinalized => finalizedAt != null;
  bool get hasSharedContent =>
      sharedMoments.isNotEmpty || carriedThreads.isNotEmpty || cares.isNotEmpty;

  factory DailyContinuityRecord.fromDb(Map<String, Object?> row) {
    List<T> decodeList<T>(
      Object? raw,
      T Function(Map<String, Object?> map) decode,
    ) {
      try {
        final value = jsonDecode(raw as String? ?? '[]');
        if (value is! List) return const [];
        return value
            .whereType<Map>()
            .map((e) => decode(Map<String, Object?>.from(e)))
            .toList(growable: false);
      } catch (_) {
        return const [];
      }
    }

    List<String> decodeStrings(Object? raw) {
      try {
        final value = jsonDecode(raw as String? ?? '[]');
        if (value is! List) return const [];
        return value
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      } catch (_) {
        return const [];
      }
    }

    DateTime? time(Object? value) => value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((value as num).toInt());

    return DailyContinuityRecord(
      id: row['id'] as String,
      localDay: row['local_day'] as String,
      windowStart: DateTime.fromMillisecondsSinceEpoch(
        (row['window_start'] as num).toInt(),
      ),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(
        (row['window_end'] as num).toInt(),
      ),
      sharedMoments: decodeList(
        row['shared_moments_json'],
        DailyContinuityMoment.fromJson,
      ),
      carriedThreads: decodeList(
        row['carried_threads_json'],
        DailyContinuityThread.fromJson,
      ),
      cares: decodeList(
        row['cares_json'],
        DailyContinuityCare.fromJson,
      ),
      awarenessSummaries: decodeStrings(row['awareness_json']),
      messageCount: row['message_count'] as int? ?? 0,
      relationshipEventCount: row['relationship_event_count'] as int? ?? 0,
      quietDay: (row['quiet_day'] as int? ?? 0) == 1,
      sourceFingerprint: row['source_fingerprint'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as num).toInt(),
      ),
      finalizedAt: time(row['finalized_at']),
    );
  }
}

class DailyContinuitySaveResult {
  const DailyContinuitySaveResult({
    required this.changed,
    required this.finalizedNow,
  });

  final bool changed;
  final bool finalizedNow;
}
