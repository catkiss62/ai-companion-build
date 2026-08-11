import '../models/conversation_summary.dart';
import '../models/memory_item.dart';
import '../models/unfinished_thread.dart';

class MemoryContext {
  const MemoryContext({
    required this.stableUser,
    required this.aiSelf,
    required this.preferences,
    required this.relevant,
    required this.inferences,
    required this.history,
    required this.summaries,
    required this.threads,
  });

  final List<MemoryItem> stableUser;
  final List<MemoryItem> aiSelf;
  final List<MemoryItem> preferences;
  final List<MemoryItem> relevant;
  final List<MemoryItem> inferences;
  final List<MemoryItem> history;
  final List<ConversationSummary> summaries;
  final List<UnfinishedThread> threads;

  bool get isEmpty => stableUser.isEmpty && aiSelf.isEmpty && preferences.isEmpty &&
      relevant.isEmpty && inferences.isEmpty && history.isEmpty &&
      summaries.isEmpty && threads.isEmpty;
}
