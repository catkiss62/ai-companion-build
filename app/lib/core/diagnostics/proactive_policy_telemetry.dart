class ProactivePolicyEvent {
  const ProactivePolicyEvent({
    required this.lane,
    required this.sourceType,
    required this.intentKind,
    required this.outcome,
    this.reasonTag = 'none',
    this.repeatDepth = 0,
    this.adjustmentBucket = 'none',
    this.createdAt,
  });

  final String lane;
  final String sourceType;
  final String intentKind;
  final String outcome;
  final String reasonTag;
  final int repeatDepth;
  final String adjustmentBucket;
  final DateTime? createdAt;
}

/// Fixed, content-free vocabulary for proactive selection diagnostics.
///
/// Thought text, message text, app/package names, web data and model output are
/// intentionally absent from this contract. Unknown values collapse to safe
/// buckets before SQLite sees them.
class ProactivePolicyTelemetry {
  const ProactivePolicyTelemetry._();

  static const lanes = <String>{
    'current_app',
    'selection',
    'generation',
    'delivery',
  };
  static const sourceTypes = <String>{
    'none',
    'drive_state',
    'user_history',
    'internal',
    'memory',
    'self_experience',
    'awareness',
    'screen_observation',
    'inference',
    'public_web',
    'mcp',
    'accessibility',
    'usage_events',
    'usage_stats',
  };
  static const intentKinds = <String>{
    'none',
    'gentle_ping',
    'miss_you',
    'followup',
    'share_thought',
    'curiosity',
    'social_share',
    'intimacy_invitation',
    'emotional_reach',
  };
  static const outcomes = <String>{
    'resolved_first_try',
    'resolved_after_retry',
    'unresolved_after_retry',
    'unresolved_no_capability',
    'retry_skipped_device_state',
    'selected',
    'selected_after_rerank',
    'repetition_downranked',
    'waiting_share_promoted',
    'model_wait',
    'model_wait_declined',
    'guard_blocked',
    'preempted',
    'sent',
    'failed',
    'gate_blocked',
  };
  static const reasonTags = <String>{
    'none',
    'prompt_proactive',
    'initial_miss',
    'screen_off',
    'device_locked',
    'theme_repeat',
    'share_waiting',
    'ordinary_selection',
    'grounding_guard',
    'service_template_guard',
    'writer_lease',
    'user_preempted',
    'device_state',
    'frequency_ceiling',
    'missing_config',
    'public_web_declined',
    'internal_wait',
    'delivered',
    'delivery_gate',
  };
  static const adjustmentBuckets = <String>{
    'none',
    'repeat_1',
    'repeat_2',
    'repeat_3_plus',
    'wait_90m',
    'wait_4h',
    'wait_12h',
    'wait_24h_plus',
    'mixed',
  };

  static String safeLane(String value) =>
      lanes.contains(value) ? value : 'generation';
  static String safeSourceType(String value) =>
      sourceTypes.contains(value) ? value : 'none';
  static String safeIntentKind(String value) =>
      intentKinds.contains(value) ? value : 'none';
  static String safeOutcome(String value) =>
      outcomes.contains(value) ? value : 'failed';
  static String safeReasonTag(String value) =>
      reasonTags.contains(value) ? value : 'none';
  static String safeAdjustmentBucket(String value) =>
      adjustmentBuckets.contains(value) ? value : 'none';

  static String appSourceType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('accessibility')) return 'accessibility';
    if (normalized == 'usage_events') return 'usage_events';
    if (normalized == 'usage_stats_fallback') return 'usage_stats';
    return 'none';
  }
}
