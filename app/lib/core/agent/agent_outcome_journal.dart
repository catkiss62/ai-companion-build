import 'dart:convert';

class AgentOutcomeEvent {
  const AgentOutcomeEvent({
    required this.capabilityId,
    required this.origin,
    required this.status,
    required this.outcome,
    required this.resultCount,
    required this.occurredAt,
  });

  final String capabilityId;
  final String origin;
  final String status;
  final String outcome;
  final int resultCount;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'capability': capabilityId,
        'origin': origin,
        'status': status,
        'outcome': outcome,
        'result_count': resultCount.clamp(0, 1000),
        'occurred_at': occurredAt.millisecondsSinceEpoch,
      };
}

/// A bounded, content-free journal shared by current Agent tools and future
/// registered MCP executors. It deliberately accepts only machine codes: no
/// query, title, summary, URL, path, Thought, chat text, or raw error can enter.
class AgentOutcomeJournal {
  const AgentOutcomeJournal._();

  static const maxEntries = 24;
  static final RegExp _safeCode = RegExp(r'^[a-z0-9][a-z0-9_.:-]{0,79}$');

  static AgentOutcomeEvent? create({
    required String capabilityId,
    required String origin,
    required String status,
    required String outcome,
    required int resultCount,
    required DateTime occurredAt,
  }) {
    final capability = capabilityId.trim().toLowerCase();
    final safeOrigin = origin.trim().toLowerCase();
    final safeStatus = status.trim().toLowerCase();
    final safeOutcome = outcome.trim().toLowerCase();
    if (!_safeCode.hasMatch(capability) ||
        !_safeCode.hasMatch(safeOrigin) ||
        !_safeCode.hasMatch(safeStatus) ||
        !_safeCode.hasMatch(safeOutcome) ||
        occurredAt.millisecondsSinceEpoch <= 0) {
      return null;
    }
    return AgentOutcomeEvent(
      capabilityId: capability,
      origin: safeOrigin,
      status: safeStatus,
      outcome: safeOutcome,
      resultCount: resultCount.clamp(0, 1000).toInt(),
      occurredAt: occurredAt,
    );
  }

  static List<AgentOutcomeEvent> decode(String raw) {
    if (raw.trim().isEmpty || raw.length > 24000) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final events = <AgentOutcomeEvent>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final at = (item['occurred_at'] as num?)?.toInt() ?? 0;
        final event = create(
          capabilityId: item['capability']?.toString() ?? '',
          origin: item['origin']?.toString() ?? '',
          status: item['status']?.toString() ?? '',
          outcome: item['outcome']?.toString() ?? '',
          resultCount: (item['result_count'] as num?)?.toInt() ?? 0,
          occurredAt: DateTime.fromMillisecondsSinceEpoch(at),
        );
        if (event != null) events.add(event);
      }
      events.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      return events.length <= maxEntries
          ? List<AgentOutcomeEvent>.unmodifiable(events)
          : List<AgentOutcomeEvent>.unmodifiable(
              events.sublist(events.length - maxEntries),
            );
    } catch (_) {
      return const [];
    }
  }

  static String append(String current, AgentOutcomeEvent event) {
    final events = <AgentOutcomeEvent>[...decode(current), event]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final bounded = events.length <= maxEntries
        ? events
        : events.sublist(events.length - maxEntries);
    return jsonEncode(bounded.map((item) => item.toJson()).toList());
  }
}
