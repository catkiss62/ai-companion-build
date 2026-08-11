import 'dart:convert';

import '../database/app_database.dart';
import '../models/daily_continuity.dart';
import '../relationship/relationship_presentation.dart';

class DailyContinuityRunResult {
  const DailyContinuityRunResult({
    required this.changedDays,
    required this.finalizedDays,
  });

  final int changedDays;
  final int finalizedDays;
}

/// Deterministic, local-only bridge between day-sized slices of real history.
///
/// It deliberately does not call a model. AI Self reflection remains private
/// and independent; this record only compresses factual local sources that are
/// already durable elsewhere. One UNIQUE local_day row makes retries exactly
/// once from the user's perspective.
class DailyContinuityEngine {
  DailyContinuityEngine(this.db);

  final AppDatabase db;

  static const _leaseKey = 'daily_continuity_lease_until';

  Future<DailyContinuityRunResult> maybeRefresh({
    DateTime? now,
    bool force = false,
  }) async {
    if ((await db.getSetting('daily_continuity_enabled')) == '0') {
      return const DailyContinuityRunResult(changedDays: 0, finalizedDays: 0);
    }
    if (!await db.brainWorkAllowed()) {
      return const DailyContinuityRunResult(changedDays: 0, finalizedDays: 0);
    }

    final current = (now ?? DateTime.now()).toLocal();
    final lastRaw = int.tryParse(
          await db.getSetting('last_daily_continuity_refresh_at') ?? '',
        ) ??
        0;
    if (!force && lastRaw > 0) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastRaw);
      if (current.difference(last) < const Duration(minutes: 24)) {
        return const DailyContinuityRunResult(changedDays: 0, finalizedDays: 0);
      }
    }

    final acquired = await db.tryAcquireLocalLease(
      _leaseKey,
      holdFor: const Duration(minutes: 4),
    );
    if (!acquired) {
      return const DailyContinuityRunResult(changedDays: 0, finalizedDays: 0);
    }

    var changed = 0;
    var finalized = 0;
    try {
      if (!await _stillOwn()) {
        return const DailyContinuityRunResult(changedDays: 0, finalizedDays: 0);
      }
      final today = DateTime(current.year, current.month, current.day);
      final yesterday = DateTime(today.year, today.month, today.day - 1);

      final yesterdayResult = await _refreshDay(
        yesterday,
        finalized: true,
        now: current,
      );
      if (yesterdayResult.changed) changed += 1;
      if (yesterdayResult.finalizedNow) finalized += 1;

      if (!await _stillOwn()) {
        return DailyContinuityRunResult(
          changedDays: changed,
          finalizedDays: finalized,
        );
      }
      final todayResult = await _refreshDay(
        today,
        finalized: false,
        now: current,
      );
      if (todayResult.changed) changed += 1;

      if (await _stillOwn()) {
        await db.setSetting(
          'last_daily_continuity_refresh_at',
          current.millisecondsSinceEpoch.toString(),
        );
        await db.setSetting('last_daily_continuity_error', '');
      }
      return DailyContinuityRunResult(
        changedDays: changed,
        finalizedDays: finalized,
      );
    } catch (error) {
      if (await _stillOwn()) {
        final text = error.toString();
        await db.setSetting(
          'last_daily_continuity_error',
          text.length <= 320 ? text : text.substring(0, 320),
        );
      }
      rethrow;
    } finally {
      await db.releaseLocalLease(_leaseKey);
    }
  }

  Future<_DayRefreshResult> _refreshDay(
    DateTime dayStart, {
    required bool finalized,
    required DateTime now,
  }) async {
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    final existing = await db.dailyContinuityForDay(_dayKey(dayStart));
    if (existing?.isFinalized == true) {
      return const _DayRefreshResult(changed: false, finalizedNow: false);
    }

    final events = await db.relationshipEventsBetween(
      dayStart,
      dayEnd,
      limit: 24,
    );
    final moments = RelationshipPresentation.sharedMoments(events, limit: 2)
        .map(
          (e) => DailyContinuityMoment(
            id: e.id,
            label: e.label,
            summary: e.summary,
            createdAt: e.createdAt,
          ),
        )
        .toList(growable: false);

    final presentationThoughts = await db.currentThoughtsForPresentation(limit: 40);
    final dayCares = RelationshipPresentation.currentCares(
      presentationThoughts.where(
        (t) => !t.updatedAt.isBefore(dayStart) && t.updatedAt.isBefore(dayEnd),
      ),
      limit: 2,
    );

    final recentRecords = await db.dailyContinuityBefore(
      dayStart,
      limit: 2,
    );
    final seenTopics = <String>{};
    final seenThreadIds = <String>{};
    for (final record in recentRecords) {
      for (final thread in record.carriedThreads) {
        if (thread.topicKey.trim().isNotEmpty) {
          seenTopics.add(thread.topicKey.trim().toLowerCase());
        }
        seenThreadIds.add(thread.id);
      }
    }

    final activeThreads = await db.activeUnfinishedThreads(limit: 12);
    activeThreads.sort((a, b) {
      final byImportance = b.importance.compareTo(a.importance);
      if (byImportance != 0) return byImportance;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    final carriedThreads = <DailyContinuityThread>[];
    for (final thread in activeThreads) {
      if (!thread.createdAt.isBefore(dayEnd)) continue;
      final updatedToday = !thread.updatedAt.isBefore(dayStart) &&
          thread.updatedAt.isBefore(dayEnd);
      final key = thread.topicKey.trim().toLowerCase();
      final seenRecently = key.isNotEmpty
          ? seenTopics.contains(key)
          : seenThreadIds.contains(thread.id);
      if (!updatedToday && seenRecently) continue;
      carriedThreads.add(
        DailyContinuityThread(
          id: thread.id,
          title: thread.title,
          detail: _compact(thread.detail, 220),
          topicKey: thread.topicKey,
        ),
      );
      break;
    }

    final careTopic = carriedThreads.isEmpty
        ? ''
        : carriedThreads.first.topicKey.trim().toLowerCase();
    final cares = dayCares
        .where(
          (care) => careTopic.isEmpty ||
              care.topicKey.trim().toLowerCase() != careTopic,
        )
        .take(1)
        .map(
          (care) => DailyContinuityCare(
            id: care.id,
            label: care.label,
            text: _compact(care.text, 240),
            updatedAt: care.updatedAt,
            topicKey: care.topicKey,
          ),
        )
        .toList(growable: false);

    final awareness = await db.awarenessObservationsBetween(
      dayStart,
      dayEnd,
      limit: 12,
      minConfidence: 0.62,
    );
    final awarenessSummaries = <String>[];
    final awarenessSeen = <String>{};
    for (final observation in awareness) {
      final key = observation.kind.trim().toLowerCase();
      if (!awarenessSeen.add(key)) continue;
      final summary = observation.summary.trim();
      if (summary.isEmpty) continue;
      awarenessSummaries.add(_compact(summary, 160));
      if (awarenessSummaries.length >= 2) break;
    }

    final messageCount = await db.messageCountBetween(dayStart, dayEnd);
    final quietDay = moments.isEmpty && carriedThreads.isEmpty && cares.isEmpty;
    final payload = <String, Object?>{
      'day': _dayKey(dayStart),
      'moments': moments.map((e) => e.toJson()).toList(),
      'threads': carriedThreads.map((e) => e.toJson()).toList(),
      'cares': cares.map((e) => e.toJson()).toList(),
      'awareness': awarenessSummaries,
      'message_count': messageCount,
      'relationship_event_count': events.length,
      'quiet_day': quietDay,
    };
    final fingerprint = _fingerprint(payload);

    if (!await _stillOwn()) {
      return const _DayRefreshResult(changed: false, finalizedNow: false);
    }
    final saved = await db.upsertDailyContinuityIfBrainOwned(
      localDay: _dayKey(dayStart),
      windowStart: dayStart,
      windowEnd: dayEnd,
      sharedMomentsJson: jsonEncode(moments.map((e) => e.toJson()).toList()),
      carriedThreadsJson:
          jsonEncode(carriedThreads.map((e) => e.toJson()).toList()),
      caresJson: jsonEncode(cares.map((e) => e.toJson()).toList()),
      awarenessJson: jsonEncode(awarenessSummaries),
      messageCount: messageCount,
      relationshipEventCount: events.length,
      quietDay: quietDay,
      sourceFingerprint: fingerprint,
      finalizedAt: finalized ? now : null,
    );
    return _DayRefreshResult(
      changed: saved.changed,
      finalizedNow: saved.finalizedNow,
    );
  }

  Future<bool> _stillOwn() async {
    if (!await db.brainWorkAllowed()) return false;
    return db.renewLocalLease(
      _leaseKey,
      holdFor: const Duration(minutes: 4),
    );
  }

  String _dayKey(DateTime local) {
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _compact(String text, int max) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.length <= max ? cleaned : '${cleaned.substring(0, max)}…';
  }

  String _fingerprint(Object payload) {
    final bytes = utf8.encode(jsonEncode(payload));
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xffffffffffffffff;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

class _DayRefreshResult {
  const _DayRefreshResult({required this.changed, required this.finalizedNow});
  final bool changed;
  final bool finalizedNow;
}
