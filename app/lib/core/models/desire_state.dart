import 'dart:convert';

enum DriveKey {
  attachment,
  curiosity,
  reflection,
  duty,
  social,
  libido,
  stress,
  fatigue,
}

extension DriveKeyLabel on DriveKey {
  String get key => name;

  String get zhLabel => switch (this) {
        DriveKey.attachment => '依恋',
        DriveKey.curiosity => '好奇',
        DriveKey.reflection => '沉思',
        DriveKey.duty => '挂念',
        DriveKey.social => '社交',
        DriveKey.libido => '亲密',
        DriveKey.stress => '压力',
        DriveKey.fatigue => '疲劳',
      };
}

class DesireSnapshot {
  DesireSnapshot({
    Map<DriveKey, double>? drives,
    Map<DriveKey, double>? baselines,
    Map<DriveKey, DateTime>? refractoryUntil,
    this.lastIntent,
    this.lastTickAt,
    this.lastWildcardAt,
  })  : drives = drives ?? defaultDrives(),
        baselines = baselines ?? defaultBaselines(),
        refractoryUntil = refractoryUntil ?? <DriveKey, DateTime>{};

  final Map<DriveKey, double> drives;
  final Map<DriveKey, double> baselines;
  final Map<DriveKey, DateTime> refractoryUntil;
  final String? lastIntent;
  final DateTime? lastTickAt;
  final DateTime? lastWildcardAt;

  bool isRefractory(DriveKey drive, DateTime now) {
    final until = refractoryUntil[drive];
    return until != null && until.isAfter(now);
  }

  DesireSnapshot copyWith({
    Map<DriveKey, double>? drives,
    Map<DriveKey, double>? baselines,
    Map<DriveKey, DateTime>? refractoryUntil,
    String? lastIntent,
    DateTime? lastTickAt,
    DateTime? lastWildcardAt,
    bool clearIntent = false,
  }) {
    return DesireSnapshot(
      drives: drives ?? Map.of(this.drives),
      baselines: baselines ?? Map.of(this.baselines),
      refractoryUntil: refractoryUntil ?? Map.of(this.refractoryUntil),
      lastIntent: clearIntent ? null : (lastIntent ?? this.lastIntent),
      lastTickAt: lastTickAt ?? this.lastTickAt,
      lastWildcardAt: lastWildcardAt ?? this.lastWildcardAt,
    );
  }

  Map<String, Object?> toJson() => {
        'drives': {for (final e in drives.entries) e.key.name: e.value},
        'baselines': {for (final e in baselines.entries) e.key.name: e.value},
        'refractory_until': {
          for (final e in refractoryUntil.entries)
            e.key.name: e.value.toIso8601String(),
        },
        'last_intent': lastIntent,
        'last_tick_at': lastTickAt?.toIso8601String(),
        'last_wildcard_at': lastWildcardAt?.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  factory DesireSnapshot.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;

    Map<DriveKey, double> decodeDoubleMap(
      String key,
      Map<DriveKey, double> fallback,
    ) {
      final raw = (json[key] as Map?)?.cast<String, dynamic>() ?? const {};
      return {
        for (final drive in DriveKey.values)
          drive: (raw[drive.name] as num?)?.toDouble() ?? fallback[drive]!,
      };
    }

    final refractory = <DriveKey, DateTime>{};
    final untilRaw =
        (json['refractory_until'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final drive in DriveKey.values) {
      final raw = untilRaw[drive.name] as String?;
      final parsed = raw == null ? null : DateTime.tryParse(raw);
      if (parsed != null) refractory[drive] = parsed;
    }

    // v0.1 compatibility: old snapshots stored cooldowns as heartbeat counts.
    if (refractory.isEmpty) {
      final ticksRaw =
          (json['refractory_ticks'] as Map?)?.cast<String, dynamic>() ?? const {};
      final now = DateTime.now();
      for (final drive in DriveKey.values) {
        final ticks = (ticksRaw[drive.name] as num?)?.toInt() ?? 0;
        if (ticks > 0) {
          refractory[drive] = now.add(Duration(minutes: ticks * 12));
        }
      }
    }

    return DesireSnapshot(
      drives: decodeDoubleMap('drives', defaultDrives()),
      baselines: decodeDoubleMap('baselines', defaultBaselines()),
      refractoryUntil: refractory,
      lastIntent: json['last_intent'] as String?,
      lastTickAt: json['last_tick_at'] == null
          ? null
          : DateTime.tryParse(json['last_tick_at'] as String),
      lastWildcardAt: json['last_wildcard_at'] == null
          ? null
          : DateTime.tryParse(json['last_wildcard_at'] as String),
    );
  }

  static Map<DriveKey, double> defaultDrives() => {
        DriveKey.attachment: 0.44,
        DriveKey.curiosity: 0.36,
        DriveKey.reflection: 0.34,
        DriveKey.duty: 0.28,
        DriveKey.social: 0.25,
        DriveKey.libido: 0.22,
        DriveKey.stress: 0.18,
        DriveKey.fatigue: 0.18,
      };

  static Map<DriveKey, double> defaultBaselines() => {
        DriveKey.attachment: 0.38,
        DriveKey.curiosity: 0.34,
        DriveKey.reflection: 0.30,
        DriveKey.duty: 0.24,
        DriveKey.social: 0.22,
        DriveKey.libido: 0.20,
        DriveKey.stress: 0.14,
        DriveKey.fatigue: 0.16,
      };
}
