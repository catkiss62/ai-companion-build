import '../models/desire_state.dart';

class OrdinaryDesireResponseOutcome {
  const OrdinaryDesireResponseOutcome({
    required this.hadAiBid,
    required this.outcome,
    required this.resolution,
    required this.action,
    required this.drive,
    required this.satisfactionIntensity,
  });

  final bool hadAiBid;
  final String outcome;
  final double resolution;
  final String action;
  final DriveKey? drive;
  final double satisfactionIntensity;

  DriveKey? get satisfiedDrive =>
      satisfactionIntensity > 0 ? drive : null;

  static OrdinaryDesireResponseOutcome? parse({
    required bool hasPreviousOrdinaryAssistant,
    required Object? raw,
    bool? authoritativeHadAiBid,
    String? authoritativeDrive,
    String? authoritativeAction,
  }) {
    if (!hasPreviousOrdinaryAssistant || raw is! Map) return null;
    final item = raw.cast<String, dynamic>();
    final hadAiBid = authoritativeHadAiBid ?? (item['had_ai_bid'] == true);
    const outcomes = {
      'engaged',
      'acknowledged',
      'deferred',
      'dodged',
      'refused',
      'redirected',
      'none',
    };
    final proposedOutcome = item['outcome'] as String? ?? 'none';
    final outcome = hadAiBid && outcomes.contains(proposedOutcome)
        ? proposedOutcome
        : 'none';
    final drive = hadAiBid
        ? _drive(authoritativeDrive ?? (item['drive'] as String?))
        : null;
    if (drive == null) return none;

    final resolution = ((item['resolution'] as num?)?.toDouble() ?? 0)
        .clamp(0.0, 1.0)
        .toDouble();
    final proposedAction =
        authoritativeAction ?? (item['action'] as String?) ?? '';
    const actions = {
      'reach_out',
      'continue_thread',
      'share_thought',
      'check_in',
      'tease_or_intimacy',
      'comfort_or_ground',
      'discover_interest',
      'remember_shared_experience',
      'wildcard_share',
      'rest',
      'wait',
    };
    final action = actions.contains(proposedAction)
        ? proposedAction
        : _defaultActionForDrive(drive);
    final intensity = switch (outcome) {
      'engaged' => (0.35 + resolution * 0.55).clamp(0.35, 0.90).toDouble(),
      'acknowledged' =>
        (0.18 + resolution * 0.32).clamp(0.18, 0.50).toDouble(),
      _ => 0.0,
    };
    return OrdinaryDesireResponseOutcome(
      hadAiBid: true,
      outcome: outcome,
      resolution: resolution,
      action: action,
      drive: drive,
      satisfactionIntensity: intensity,
    );
  }

  static const none = OrdinaryDesireResponseOutcome(
    hadAiBid: false,
    outcome: 'none',
    resolution: 0,
    action: '',
    drive: null,
    satisfactionIntensity: 0,
  );

  static DriveKey? _drive(String? raw) {
    if (raw == null) return null;
    for (final drive in DriveKey.values) {
      if (drive.name == raw) return drive;
    }
    return null;
  }

  static String _defaultActionForDrive(DriveKey drive) => switch (drive) {
        DriveKey.attachment => 'reach_out',
        DriveKey.curiosity => 'discover_interest',
        DriveKey.reflection => 'share_thought',
        DriveKey.duty => 'continue_thread',
        DriveKey.social => 'share_thought',
        DriveKey.libido => 'tease_or_intimacy',
        DriveKey.stress => 'comfort_or_ground',
        DriveKey.fatigue => 'rest',
      };
}
