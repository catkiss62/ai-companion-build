import '../../core/database/app_database.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/interaction_session.dart';
import '../../core/models/daily_continuity.dart';
import '../../core/models/perception_snapshot.dart';
import '../../core/models/unfinished_thread.dart';
import '../../core/relationship/relationship_presentation.dart';

class CompanionHomeSnapshot {
  const CompanionHomeSnapshot({
    required this.activeBrain,
    required this.transferLocked,
    required this.deviceId,
    required this.refreshedAt,
    this.currentCare,
    this.recentContinuity,
    this.recentRelationshipMoment,
    this.latestProactiveMessage,
    this.unfinishedThread,
    this.latestPerception,
    this.activeSession,
  });

  final bool activeBrain;
  final bool transferLocked;
  final String deviceId;
  final DateTime refreshedAt;
  final CompanionCareView? currentCare;
  final DailyContinuityRecord? recentContinuity;
  final RelationshipMomentView? recentRelationshipMoment;
  final ChatMessage? latestProactiveMessage;
  final UnfinishedThread? unfinishedThread;
  final PerceptionSnapshot? latestPerception;
  final InteractionSession? activeSession;

  bool get isStandby => !activeBrain && !transferLocked;

  String get presenceTitle {
    if (transferLocked) return '她正在换到另一台设备';
    if (activeBrain) return '她现在就在这台设备上';
    return '她正在另一台设备上陪着你';
  }

  String get presenceDetail {
    if (transferLocked) {
      return '接管过程中会暂时停止新的聊天与长期状态更新，避免两台设备同时改变同一个她。';
    }
    if (activeBrain) {
      return '她的聊天、记忆、念头和主动联系都会从这台设备继续向前积累。';
    }
    return '这台设备仍保留上次同步到本机的完整数据，但她现在在另一台设备上继续；这里看到的可能不是她此刻的最新状态，也不会偷偷生成第二份人生。';
  }
}

class CompanionHomeRepository {
  CompanionHomeRepository(this.db);

  final AppDatabase db;

  Future<CompanionHomeSnapshot> load() async {
    await db.ensureReady();
    final activeBrain = (await db.getSetting('active_brain')) != '0';
    final transferLocked = (await db.getSetting('transfer_lock')) == '1';
    final deviceId = await db.ensureDeviceId();

    final thoughts = await db.currentThoughtsForPresentation(limit: 24);
    final cares = RelationshipPresentation.currentCares(thoughts, limit: 1);
    final events = await db.recentRelationshipEvents(limit: 8);
    final moments = RelationshipPresentation.sharedMoments(events, limit: 4);
    final threads = await db.activeUnfinishedThreads(limit: 4);
    final perceptions = await db.recentPerceptionSnapshots(limit: 1);
    final continuityRecords = await db.latestDailyContinuity(limit: 1);
    final recentContinuity = continuityRecords.isEmpty ? null : continuityRecords.first;

    final care = cares.isEmpty ? null : cares.first;
    RelationshipMomentView? visibleMoment;
    for (final moment in moments) {
      final duplicatesCare = care != null &&
          RelationshipPresentation.sameDisplayText(care.text, moment.summary);
      final duplicatesContinuity = recentContinuity?.sharedMoments.any(
            (item) => item.id == moment.id ||
                RelationshipPresentation.sameDisplayText(item.summary, moment.summary),
          ) ??
          false;
      if (!duplicatesCare && !duplicatesContinuity) {
        visibleMoment = moment;
        break;
      }
    }

    UnfinishedThread? visibleThread;
    for (final thread in threads) {
      final sameTopic = care != null &&
          care.topicKey.trim().isNotEmpty &&
          thread.topicKey.trim().isNotEmpty &&
          care.topicKey.trim().toLowerCase() == thread.topicKey.trim().toLowerCase();
      if (!sameTopic) {
        visibleThread = thread;
        break;
      }
    }

    return CompanionHomeSnapshot(
      activeBrain: activeBrain,
      transferLocked: transferLocked,
      deviceId: deviceId,
      currentCare: care,
      recentContinuity: recentContinuity,
      recentRelationshipMoment: visibleMoment,
      latestProactiveMessage: await db.latestProactiveMessage(),
      unfinishedThread: visibleThread,
      latestPerception: perceptions.isEmpty ? null : perceptions.first,
      activeSession: await db.activeInteractionSession(),
      refreshedAt: DateTime.now(),
    );
  }
}
