import '../database/app_database.dart';
import '../models/personality_learning.dart';
import 'relationship_context.dart';

class RelationshipBrain {
  RelationshipBrain(this.db);

  final AppDatabase db;

  Future<RelationshipContext> buildContext() async {
    final events = (await db.recentRelationshipEvents(limit: 10))
        .where((event) =>
            !PersonalityLearningBoundaryPolicy.looksLikeBehavioralPreference(
              event.summary,
            ) &&
            !PersonalityLearningBoundaryPolicy.isCapabilityImplementationClaim(
              event.summary,
            ))
        .toList(growable: false);
    return RelationshipContext(
      events: events,
      activeSession: await db.activeInteractionSession(),
    );
  }
}
