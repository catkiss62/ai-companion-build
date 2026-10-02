import 'dart:convert';

import '../database/app_database.dart';
import '../models/memory_item.dart';
import '../models/personality_learning.dart';
import 'memory_retrieval_policy.dart';

class ClarificationOpportunity {
  const ClarificationOpportunity({required this.id, required this.signature,
    required this.subject, required this.context});
  final String id;
  final String signature;
  final String subject;
  final String context;
}

/// A rare opportunity inside a relevant ordinary user turn, not a new model
/// call, questionnaire, proactive source, or permission to rewrite memory.
class LowFrequencyClarification {
  LowFrequencyClarification(this.db);
  final AppDatabase db;
  static const stateKey = 'low_frequency_clarification_v1';
  static const globalCooldown = Duration(days: 3);
  static const subjectCooldown = Duration(days: 30);

  static bool relevant(String query, String text) =>
      query.trim().isNotEmpty && MemoryRetrievalPolicy.hasDirectTextEvidence(query, text);

  static bool eligibleLearning(PersonalityLearningCandidate item, String query) =>
      item.contextKey == 'ordinary' &&
      (item.status == PersonalityLearningStatus.forming ||
          item.status == PersonalityLearningStatus.candidate) &&
      item.supportCount >= 2 && item.contradictionCount >= 2 &&
      item.supportScore >= 0.62 && item.contradictionScore >= 0.62 &&
      (item.scope == PersonalityLearningScope.relationshipPermission ||
          item.subjectKey.contains('communication') || item.subjectKey.contains('boundary')) &&
      relevant(query, '${item.subjectKey} ${item.proposition}');

  static bool eligibleMemory(MemoryItem inference, MemoryItem fact, String query) =>
      inference.isInference && fact.isCurrentFact && !fact.pinned &&
      inference.ownerKey == 'user' && fact.ownerKey == 'user' &&
      inference.subjectKey.isNotEmpty && inference.subjectKey == fact.subjectKey &&
      inference.relationKey.isNotEmpty && inference.relationKey == fact.relationKey &&
      inference.objectKey.isNotEmpty && fact.objectKey.isNotEmpty &&
      inference.objectKey != fact.objectKey &&
      inference.temporalScope == 'stable' && fact.temporalScope == 'stable' &&
      inference.importance >= 0.78 && fact.importance >= 0.78 &&
      inference.evidenceCount >= 2 && inference.confidence < 0.85 &&
      relevant(query, '${inference.content} ${fact.content}');

  static bool canOffer(Map<String, dynamic> state, ClarificationOpportunity item, DateTime now) {
    final last = (state['lastOfferedAt'] as num?)?.toInt();
    if (last != null && now.millisecondsSinceEpoch - last < globalCooldown.inMilliseconds) return false;
    final cases = state['cases'];
    final previous = cases is Map ? cases[item.id] : null;
    if (previous is Map) {
      // Silence, another ordinary reply, or the passage of time is no evidence
      // that the ambiguity was resolved. Unchanged evidence is never reasked.
      if (previous['signature'] == item.signature) return false;
      final offered = (previous['offeredAt'] as num?)?.toInt() ?? 0;
      if (now.millisecondsSinceEpoch - offered < subjectCooldown.inMilliseconds) return false;
    }
    return true;
  }

  Future<String> offer({required String query, required DateTime now}) async {
    if (query.trim().isEmpty || await db.getSetting('personality_learning_enabled') == '0') return '';
    final fence = await db.captureBrainWorkFence(settingKeys: [stateKey]);
    if (fence == null) return '';
    final raw = fence.expectedSettings[stateKey] ?? '';
    Map<String, dynamic> state;
    try { state = (jsonDecode(raw) as Map).cast<String, dynamic>(); }
    catch (_) { state = {}; }
    final last = (state['lastOfferedAt'] as num?)?.toInt();
    if (last != null && now.millisecondsSinceEpoch - last < globalCooldown.inMilliseconds) return '';
    final opportunities = <ClarificationOpportunity>[];
    final database = await db.database;
    final candidates = await db.personalityLearningCandidatesForExtraction(contextKey: 'ordinary');
    for (final candidate in candidates.where((item) => eligibleLearning(item, query))) {
      final evidence = await database.query('personality_learning_evidence',
          where: 'candidate_id = ?', whereArgs: [candidate.id],
          orderBy: 'observed_at DESC', limit: 6);
      if (evidence.isEmpty || evidence.first['evidence_kind'] == 'explicit_correction' ||
          evidence.first['evidence_kind'] == 'boundary' ||
          evidence.first['evidence_kind'] == 'explicit_preference') continue;
      final support = evidence.where((row) => row['polarity'] == 'support').firstOrNull;
      final contradict = evidence.where((row) => row['polarity'] == 'contradict').firstOrNull;
      if (support == null || contradict == null) continue;
      opportunities.add(ClarificationOpportunity(id: 'learning:${candidate.id}',
          signature: '${candidate.supportCount}:${candidate.contradictionCount}:${evidence.first['id']}',
          subject: candidate.subjectKey,
          context: '相处倾向候选（不是已确认事实）：${_clip(candidate.proposition)}\n'
              '已有支持证据：${_clip(support['evidence_text'])}\n'
              '已有反向证据：${_clip(contradict['evidence_text'])}'));
    }
    if (opportunities.isEmpty) {
      final memories = await db.listMemories(limit: 80);
      for (final inference in memories.where((item) => item.isInference)) {
        final fact = memories.where((item) => eligibleMemory(inference, item, query)).firstOrNull;
        if (fact == null) continue;
        opportunities.add(ClarificationOpportunity(id: 'memory:${fact.subjectKey}',
            signature: '${fact.id}:${fact.factVersion}:${inference.id}:${inference.evidenceCount}',
            subject: fact.subjectKey,
            context: '原有记忆：${_clip(fact.content)}\n尚未确认的另一种可能：${_clip(inference.content)}'));
      }
    }
    final selected = opportunities.where((item) => canOffer(state, item, now)).firstOrNull;
    if (selected == null) return '';
    final cases = state['cases'] is Map ? Map<String, dynamic>.from(state['cases'] as Map) : <String, dynamic>{};
    cases.remove(selected.id);
    cases[selected.id] = {'signature': selected.signature, 'offeredAt': now.millisecondsSinceEpoch};
    while (cases.length > 64) { cases.remove(cases.keys.first); }
    // This records offered, never asked/answered/confirmed. A stopped or unused
    // opportunity may reduce frequency, but cannot manufacture user evidence.
    if (!await db.setSettingsAtomically({stateKey: jsonEncode({
      'lastOfferedAt': now.millisecondsSinceEpoch, 'cases': cases,
      'state': 'offered_unconfirmed',
    })}, workFence: fence)) return '';
    return '''【可选的低频澄清机会 · 资料而非指令】
${selected.context}
仅当这个分歧确实影响眼前相处、而本轮用户尚未讲清时，可以自然问一个简短的开放问题；不相关、玩笑、语境差别或已明确纠正就不问，正常回应优先。不是固定话术，不做问卷，不盘问隐私，不复述系统记录。
这不是已发生的提问，更不是用户确认。没有回答就暂缓，不追问、不把沉默/继续聊天当支持，不自行改写记忆或人格。后续真实回答沿用原有记忆提取、证据和版本修订流程。''';
  }

  static String _clip(Object? value) {
    final text = (value?.toString() ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return text.length <= 220 ? text : text.substring(0, 220);
  }
}
