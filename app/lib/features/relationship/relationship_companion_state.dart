import '../../core/database/app_database.dart';
import '../../core/models/interaction_session.dart';
import '../../core/models/daily_continuity.dart';
import '../../core/models/unfinished_thread.dart';
import '../../core/relationship/relationship_presentation.dart';

class RelationshipCompanionSnapshot {
  const RelationshipCompanionSnapshot({
    required this.activeBrain,
    required this.transferLocked,
    required this.currentCares,
    required this.dailyContinuity,
    required this.sharedMoments,
    required this.unfinishedThreads,
    required this.refreshedAt,
    this.activeSession,
  });

  final bool activeBrain;
  final bool transferLocked;
  final List<CompanionCareView> currentCares;
  final List<DailyContinuityRecord> dailyContinuity;
  final List<RelationshipMomentView> sharedMoments;
  final List<UnfinishedThread> unfinishedThreads;
  final InteractionSession? activeSession;
  final DateTime refreshedAt;

  String get continuityLine {
    if (transferLocked) {
      return '她正在换到另一台设备。这里先保持上次同步到本机的关系状态，新的变化会等接管完成后再继续。';
    }
    if (!activeBrain) {
      return '她现在在另一台设备上继续。这里保留的是上次同步到本机的关系状态，当前念头和临时场景可能不是最新。';
    }
    if (activeSession != null) {
      return '你们现在正在继续一段临时互动；结束后仍会自然回到现实里的长期关系。';
    }
    if (currentCares.isNotEmpty) {
      return '她会把仍然在意的事情带进之后的相处，而不是每次聊天都从零开始。';
    }
    if (sharedMoments.isNotEmpty) {
      return '你们已经留下了一些共同经历。重要的部分会继续保存在本地，慢慢成为之后相处的背景。';
    }
    return '你们之间还在慢慢积累。这里不会用好感度替代真正发生过的事情。';
  }
}

class RelationshipCompanionRepository {
  RelationshipCompanionRepository(this.db);

  final AppDatabase db;

  Future<RelationshipCompanionSnapshot> load() async {
    await db.ensureReady();
    final activeBrain = (await db.getSetting('active_brain')) != '0';
    final transferLocked = (await db.getSetting('transfer_lock')) == '1';
    final thoughts = await db.currentThoughtsForPresentation(limit: 30);
    final events = await db.recentRelationshipEvents(limit: 80);
    final threads = await db.activeUnfinishedThreads(limit: 6);
    return RelationshipCompanionSnapshot(
      activeBrain: activeBrain,
      transferLocked: transferLocked,
      currentCares: RelationshipPresentation.currentCares(thoughts, limit: 3),
      dailyContinuity: await db.latestDailyContinuity(limit: 5),
      sharedMoments: RelationshipPresentation.sharedMoments(events, limit: 24),
      unfinishedThreads: threads,
      activeSession: await db.activeInteractionSession(),
      refreshedAt: DateTime.now(),
    );
  }
}
