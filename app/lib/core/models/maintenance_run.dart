class MaintenanceRun {
  const MaintenanceRun({
    required this.id,
    required this.startedAt,
    required this.completedAt,
    required this.retiredThreads,
    required this.prunedLifecycle,
    required this.prunedFeedback,
    required this.prunedHistory,
    required this.prunedPerceptions,
    required this.prunedDeviceEvents,
    required this.prunedJobs,
    this.notes = '',
  });

  final String id;
  final DateTime startedAt;
  final DateTime completedAt;
  final int retiredThreads;
  final int prunedLifecycle;
  final int prunedFeedback;
  final int prunedHistory;
  final int prunedPerceptions;
  final int prunedDeviceEvents;
  final int prunedJobs;
  final String notes;

  factory MaintenanceRun.fromDb(Map<String, Object?> row) => MaintenanceRun(
        id: row['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        completedAt: DateTime.fromMillisecondsSinceEpoch(row['completed_at'] as int),
        retiredThreads: row['retired_threads'] as int? ?? 0,
        prunedLifecycle: row['pruned_lifecycle'] as int? ?? 0,
        prunedFeedback: row['pruned_feedback'] as int? ?? 0,
        prunedHistory: row['pruned_history'] as int? ?? 0,
        prunedPerceptions: row['pruned_perceptions'] as int? ?? 0,
        prunedDeviceEvents: row['pruned_device_events'] as int? ?? 0,
        prunedJobs: row['pruned_jobs'] as int? ?? 0,
        notes: row['notes'] as String? ?? '',
      );
}
