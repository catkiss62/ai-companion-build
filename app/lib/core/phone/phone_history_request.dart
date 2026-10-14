/// High-confidence requests for the companion's own existing records. Topic
/// mentions remain ordinary chat; ambiguous wording can use the normal model
/// request with the same small read-only tool subset.
class PhoneHistoryRequest {
  const PhoneHistoryRequest({required this.section, this.subject = 'all',
    this.activity = 'all', this.query = '', this.detailed = false});
  final String section, subject, activity, query;
  final bool detailed;
  Map<String, String> get arguments => {
    'section': section, 'query': query, 'subject': subject, 'activity': activity,
  };

  static PhoneHistoryRequest? parse(String input) {
    final text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty || text.startsWith('【检查系统】') ||
        RegExp(r'^(?:请你|你先|请|先|你)?(?:不要|不用|别|无需|不需要)').hasMatch(text) ||
        RegExp(r'^(?:如果|假如|假设|比如|举例|他说|她说|有人说|[>“「"])').hasMatch(text)) return null;
    final asks = RegExp(r'(什么|哪些|哪[一张篇些]|啥|怎么|如何|吗|呢|？|\?|看看|查看|查一下|翻一下|读一下|念一下|告诉我|解读|解释)').hasMatch(text);
    if (!asks) return null;
    final own = RegExp(r'(你(?:自己)?(?:的)?|自己(?:的)?|你的手机|查手机)').hasMatch(text);
    var section = '';
    var activity = 'all';
    if (own && RegExp(r'(浏览器|联网记录|搜索记录|检索记录|浏览记录|搜索历史|联网历史)').hasMatch(text)) {
      section = 'browser';
    } else if (RegExp(r'你.{0,12}(搜了|搜过|搜索了|搜索过|查过|查了|检索过).{0,30}(什么|哪些|啥|哪篇|关键词|记录)').hasMatch(text)) {
      section = 'browser';
    } else if (RegExp(r'(塔罗|抽.{0,6}牌)').hasMatch(text) &&
        (own || RegExp(r'(今天|今日|刚才|这张|抽到|我的牌)').hasMatch(text))) {
      section = 'tarot';
    } else if (own && text.contains('购物车')) {
      section = 'cart';
    } else if (own && text.contains('日记')) {
      section = 'diary';
    } else if (own && RegExp(r'(随笔|便签)').hasMatch(text)) {
      section = 'note';
    } else if (own && text.contains('心情') && RegExp(r'(记录|写|手机|查看|读)').hasMatch(text)) {
      section = 'mood';
    } else if (own && text.contains('愿望') && RegExp(r'(记录|手机|查看|读|有什么|哪些)').hasMatch(text)) {
      section = 'wish';
    } else if (own && RegExp(r'(相册|保存过|收藏过|存了|保存了|收藏了)').hasMatch(text) &&
        RegExp(r'(图|照片|相册)').hasMatch(text)) {
      section = 'album';
    } else if (RegExp(r'你.{0,12}(写了|写过|记了|记录了).{0,12}(什么|哪些|啥)').hasMatch(text)) {
      section = 'all'; activity = 'writing';
    }
    if (section.isEmpty) return null;
    final subject = section == 'tarot'
        ? RegExp(r'(给我|替我|为我|我的牌|我今天|我今日)').hasMatch(text) ? 'user'
        : RegExp(r'(你自己|给你|你今天|你今日|你的牌)').hasMatch(text) ? 'self' : 'all'
        : 'all';
    // Quoted topic names are useful search terms. Generic questions list the
    // latest real records instead of searching for their own wording.
    final quoted = RegExp(r'[“「"]([^”」"]{2,100})[”」"]').firstMatch(text);
    return PhoneHistoryRequest(section: section, subject: subject, activity: activity,
      query: quoted?.group(1) ?? '', detailed: RegExp(r'(解读|解释|读一下|念一下)').hasMatch(text));
  }
}
