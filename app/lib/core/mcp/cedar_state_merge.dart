/// Three-way merge for an activity snapshot. Independent edits survive; a
/// conflicting edit is rejected rather than authorizing an old remote action.
abstract final class CedarStateMerge {
  static final Object _missing=Object();
  static Map<String,Object?>? merge(Map<String,Object?> base,Map<String,Object?> desired,Map<String,Object?> current) {
    try {return Map<String,Object?>.from(_merge(base,desired,current,'') as Map);}
    on _StateConflict {return null;}
  }
  static bool _same(Object? a,Object? b) {
    if(identical(a,b))return true;
    if(a is Map && b is Map)return a.length==b.length && a.keys.every((k)=>b.containsKey(k) && _same(a[k],b[k]));
    if(a is List && b is List)return a.length==b.length && List.generate(a.length,(i)=>i).every((i)=>_same(a[i],b[i]));
    return a==b;
  }
  static Object? _merge(Object? base,Object? desired,Object? current,String field) {
    if(_same(base,desired))return current;
    if(_same(base,current) || _same(desired,current))return desired;
    if(base is Map && desired is Map && current is Map) {
      if(field=='session' && base['id']!=current['id'])throw const _StateConflict();
      final result=<String,Object?>{};
      for(final key in {...base.keys,...current.keys,...desired.keys}) {
        final value=_merge(base.containsKey(key)?base[key]:_missing,
          desired.containsKey(key)?desired[key]:_missing,current.containsKey(key)?current[key]:_missing,key.toString());
        if(!identical(value,_missing))result[key.toString()]=value;
      }
      return result;
    }
    if(field=='updated_at' && desired is int && current is int)return desired>current?desired:current;
    if(base is List && desired is List && current is List &&
        const {'sessions','queued_switches','notices','events'}.contains(field)) {
      final key=field=='sessions'?'game_id':'id';
      Map<String,Object?> index(List rows) {
        final indexed=<String,Object?>{};
        for(final row in rows) {
          if(row is! Map || row[key] is! String || (row[key] as String).isEmpty || indexed.containsKey(row[key]))throw const _StateConflict();
          indexed[row[key] as String]=row;
        }
        return indexed;
      }
      final old=index(base),next=index(desired),live=index(current),result=<Object?>[];
      for(final id in {...live.keys,...next.keys,...old.keys}) {
        final value=_merge(old.containsKey(id)?old[id]:_missing,
          next.containsKey(id)?next[id]:_missing,live.containsKey(id)?live[id]:_missing,field=='sessions'?'session':'entry');
        if(!identical(value,_missing))result.add(value);
      }
      final limit=field=='sessions'||field=='queued_switches'?8:24;
      if(field=='sessions') {
        result.sort((a,b)=>(((b as Map)['updated_at'] as num?)??0).compareTo(((a as Map)['updated_at'] as num?)??0));
        return result.take(limit).toList();
      }
      return result.length<=limit?result:result.sublist(result.length-limit);
    }
    throw const _StateConflict();
  }
}
class _StateConflict implements Exception {const _StateConflict();}
