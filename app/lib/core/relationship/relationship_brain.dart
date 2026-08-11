import '../database/app_database.dart';
import 'relationship_context.dart';

class RelationshipBrain {
  RelationshipBrain(this.db);

  final AppDatabase db;

  Future<RelationshipContext> buildContext() async {
    return RelationshipContext(
      events: await db.recentRelationshipEvents(limit: 10),
      activeSession: await db.activeInteractionSession(),
    );
  }
}
