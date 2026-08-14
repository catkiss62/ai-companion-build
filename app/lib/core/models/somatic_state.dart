enum SomaticChannel {
  touch,
  smell,
  taste,
  sound;

  static SomaticChannel fromKey(String value) => SomaticChannel.values.firstWhere(
        (channel) => channel.name == value,
        orElse: () => SomaticChannel.touch,
      );
}

enum SomaticDirection {
  userToAi('user_to_ai'),
  aiToSelf('ai_to_self');

  const SomaticDirection(this.key);
  final String key;

  static SomaticDirection fromKey(String value) =>
      SomaticDirection.values.firstWhere(
        (direction) => direction.key == value,
        orElse: () => SomaticDirection.userToAi,
      );
}

class SomaticEvent {
  const SomaticEvent({
    required this.id,
    required this.turnId,
    required this.channel,
    required this.action,
    required this.part,
    required this.sceneKey,
    required this.direction,
    required this.source,
    required this.narrative,
    required this.intensity,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String turnId;
  final SomaticChannel channel;
  final String action;
  final String part;
  final String sceneKey;
  final SomaticDirection direction;
  final String source;
  final String narrative;
  final double intensity;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toDb() => {
        'id': id,
        'turn_id': turnId,
        'channel': channel.name,
        'action': action,
        'part': part,
        'scene_key': sceneKey,
        'direction': direction.key,
        'source': source,
        'narrative': narrative,
        'intensity': intensity.clamp(0.0, 1.0),
        'created_at': createdAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  factory SomaticEvent.fromDb(Map<String, Object?> row) => SomaticEvent(
        id: row['id'] as String,
        turnId: row['turn_id'] as String,
        channel: SomaticChannel.fromKey(row['channel'] as String? ?? ''),
        action: row['action'] as String? ?? '',
        part: row['part'] as String? ?? '',
        sceneKey: row['scene_key'] as String? ?? '',
        direction: SomaticDirection.fromKey(row['direction'] as String? ?? ''),
        source: row['source'] as String? ?? '',
        narrative: row['narrative'] as String? ?? '',
        intensity: (row['intensity'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      );
}

class SomaticAggregate {
  const SomaticAggregate({
    required this.channel,
    required this.value,
    required this.sceneKey,
    required this.narrative,
    required this.lastEventId,
    required this.updatedAt,
    required this.expiresAt,
  });

  final SomaticChannel channel;
  final double value;
  final String sceneKey;
  final String narrative;
  final String lastEventId;
  final DateTime updatedAt;
  final DateTime expiresAt;

  Map<String, Object?> toDb() => {
        'channel': channel.name,
        'value': value.clamp(0.0, 1.0),
        'scene_key': sceneKey,
        'narrative': narrative,
        'last_event_id': lastEventId,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  factory SomaticAggregate.fromDb(Map<String, Object?> row) =>
      SomaticAggregate(
        channel: SomaticChannel.fromKey(row['channel'] as String? ?? ''),
        value: (row['value'] as num?)?.toDouble() ?? 0.0,
        sceneKey: row['scene_key'] as String? ?? '',
        narrative: row['narrative'] as String? ?? '',
        lastEventId: row['last_event_id'] as String? ?? '',
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      );

  SomaticAggregate copyWith({double? value}) => SomaticAggregate(
        channel: channel,
        value: value ?? this.value,
        sceneKey: sceneKey,
        narrative: narrative,
        lastEventId: lastEventId,
        updatedAt: updatedAt,
        expiresAt: expiresAt,
      );
}
