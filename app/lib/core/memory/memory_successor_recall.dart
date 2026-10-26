import 'package:sqflite/sqflite.dart';
import '../models/memory_item.dart';
import 'conversation_recall_policy.dart';
import 'memory_admission_policy.dart';
import 'memory_retrieval_policy.dart';

abstract final class MemorySuccessorRecall {
  /// Locate a current fact through an explicit bounded revision chain when
  /// the user remembers its OLD wording. Every hop retains source admission.
  static Future<List<MemoryItem>> find(DatabaseExecutor sql,String query,{int limit=3}) async {
    final terms=ConversationRecallPolicy.searchTerms(query).take(12).toList();if(terms.isEmpty) return [];
    final old=await sql.query('memory_items',where:"source_valid=1 AND status='superseded' AND superseded_by IS NOT NULL AND ("
      '${List.filled(terms.length,"instr(lower(content || \' \' || tags || \' \' || subject_key), ?) > 0").join(' OR ')})',
      whereArgs:terms.map((t)=>t.toLowerCase()).toList(),orderBy:'updated_at DESC',limit:24);
    final result=<String,MemoryItem>{};
    for(final row in old) {
      var item=MemoryItem.fromDb(row);
      if(!MemoryAdmissionPolicy.forPrompt(item) || !MemoryRetrievalPolicy.hasDirectTextEvidence(query,item.content)) continue;
      final subject=item.subjectKey;final seen=<String>{item.id};
      for(var hop=0;hop<6;hop++) {
        final next=item.supersededBy;if(next==null || next.isEmpty || !seen.add(next)) break;
        final rows=await sql.query('memory_items',where:'id=?',whereArgs:[next],limit:1);if(rows.isEmpty) break;
        item=MemoryItem.fromDb(rows.single);
        if(!MemoryAdmissionPolicy.forPrompt(item) || subject.isEmpty || item.subjectKey!=subject) break;
        if(item.isActive) {if(const {'current_fact','shared_experience'}.contains(item.semanticType)) result[item.id]=item;break;}
        if(!item.isHistorical) break;
      }
      if(result.length>=limit) break;
    }
    return result.values.take(limit).toList();
  }
}
