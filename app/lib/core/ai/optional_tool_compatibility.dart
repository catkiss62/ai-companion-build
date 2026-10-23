/// Only the voluntary, optional reader entry may fall back to plain chat.
/// Explicit task tool schemas and their permissions must never be discarded.
class OptionalToolCompatibility {
  static final Map<String,DateTime> _plainUntil = {};
  static bool isOptionalEntry(List<Map<String,Object?>> tools) => tools.length==1 &&
      (tools.single['function'] as Map?)?['name']=='agent_request';
  static bool plainChat(String key) {
    final until=_plainUntil[key];
    if(until==null)return false;
    if(DateTime.now().isBefore(until))return true;
    _plainUntil.remove(key);return false;
  }
  static void remember(String key) {
    if(_plainUntil.length>=128)_plainUntil.remove(_plainUntil.keys.first);
    _plainUntil[key]=DateTime.now().add(const Duration(hours:6));
  }
  static bool explicitlyUnsupported(int status,String body) =>
      const {400,422}.contains(status) &&
      RegExp(r'tools?|tool_choice|function.?call(?:ing)?',caseSensitive:false).hasMatch(body) &&
      RegExp(r'not.?support|unsupported|not.?allow|unknown.?parameter|unrecognized|unexpected|not.?permitted|extra.?inputs|不支持|未知参数',
        caseSensitive:false).hasMatch(body);
}
