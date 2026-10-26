import 'package:sqflite/sqflite.dart';
import 'qq_display_names.dart';

/// Read-only directory shared by App retrieval and the owner's QQ adapter.
/// Names are search labels, never identity or disclosure authority.
class QqHistoryCatalog {
  QqHistoryCatalog(this.sql);
  final DatabaseExecutor sql;
  Future<List<Map<String,Object?>>> list({String? scope,String kind='all',int resetAt=0,int? through}) async {
    final rows=await sql.rawQuery('SELECT c.*,COUNT(a.seq) AS message_count,'
      'MIN(a.observed_at) AS first_at,MAX(a.observed_at) AS last_at '
      'FROM qq_conversations c LEFT JOIN qq_archive a ON a.conversation_id=c.id '
      'AND a.observed_at>=? ${through==null?'':'AND a.seq<=?'} '
      'WHERE 1=1 ${scope==null?'':'AND c.scope=?'} ${kind=='all'?'':'AND c.kind=?'} '
      'GROUP BY c.id ORDER BY MAX(a.seq) DESC,c.id LIMIT 200',
      [resetAt,if(through!=null)through,if(scope!=null)scope,if(kind!='all')kind]);
    final names=<String,QqDisplayNames>{};final result=<Map<String,Object?>>[];
    for(final row in rows) {
      final source=row['scope'] as String;
      final labels=names[source]??=await QqDisplayNames.read(sql,source);
      final group=row['kind']=='group';final label=group?labels.groups[row['target']]:null;
      result.add({...row,'name':group?label??'未命名群聊':'本人QQ私聊','named':label!=null});
    }
    return result;
  }
  static List<Map<String,Object?>> namedMatches(String query,List<Map<String,Object?>> rows) {
    final text=query.toLowerCase();
    final hits=rows.where((r)=>r['kind']=='group' && r['named']==true &&
      text.contains((r['name'] as String).toLowerCase())).toList();
    if(hits.length<2) return hits;
    // An overlapping short name is not a second requested group. Identical
    // names remain ambiguous and must be resolved using the directory.
    return hits.where((r)=>!hits.any((other)=>other['id']!=r['id'] &&
      (other['name'] as String).length>(r['name'] as String).length &&
      (other['name'] as String).toLowerCase().contains((r['name'] as String).toLowerCase()))).toList();
  }
  static String kindFor(String query) {
    if(RegExp(r'QQ\s*(私聊|单聊)|私聊记录',caseSensitive:false).hasMatch(query)) return 'private';
    if(RegExp(r'QQ群|群聊|群友|群里|在群|这个群|那个群|群的.{0,12}(消息|记录)',caseSensitive:false).hasMatch(query)) return 'group';
    return 'all';
  }
  static bool namedReference(String query)=>RegExp(r'这个群|那个群|名为|叫.{1,80}的群').hasMatch(query);
  static bool request(String query) {
    final text=query.trim();
    if(RegExp(r'^(?:请|先|你)?(?:不要|不用|别|无需)|^(?:如果|假如|假设|比如|[>“「"])').hasMatch(text)) return false;
    if(RegExp(r'开发|实现|设计|新增功能|修改代码|接口怎么|怎么接入|如何接入').hasMatch(text)) return false;
    return (kindFor(text)!='all' || RegExp(r'QQ.{0,10}(历史|记录|说过|聊过)',caseSensitive:false).hasMatch(text)) &&
      RegExp(r'看|查|读|找|翻|记得|记录|内容|说了|聊了|说过|聊过|哪些群|什么群|群列表').hasMatch(text);
  }
  static Map<String,Object?> entry(Map<String,Object?> row)=>{
    'conversation_id':row['id'],'name':row['name'],'kind':row['kind'],
    'message_count':row['message_count'],'first_at':row['first_at'],'last_at':row['last_at']};
}
