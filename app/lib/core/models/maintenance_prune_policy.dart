abstract final class MaintenancePrunePolicy {
  static const allowedTables = <String>{
    'proactive_feedback',
    'proactive_history',
    'perception_snapshots',
    'awareness_observations',
    'device_events',
    'daily_continuity',
    'post_turn_jobs',
    'maintenance_runs',
    'provider_health_events',
    'proactive_policy_events',
  };

  static const allowedTimeColumns = <String>{
    'sent_at',
    'created_at',
    'occurred_at',
    'updated_at',
    'window_start',
    'completed_at',
  };

  static bool supports({required String table, required String timeColumn}) =>
      allowedTables.contains(table) && allowedTimeColumns.contains(timeColumn);
}
