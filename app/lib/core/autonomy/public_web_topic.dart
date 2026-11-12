import 'dart:io';

/// The query and domains are public search inputs, never a transcript.
class PublicWebTopic {
  const PublicWebTopic(
    this.query, {
    this.domains = const [],
    this.baidu = false,
    this.fresh = false,
  });
  final String query;
  final List<String> domains;
  final bool baidu;
  final bool fresh;

  static const sites = <String, List<String>>{
    '微博': ['weibo.com', 'weibo.cn'],
    'B站': ['bilibili.com'],
    'Bangumi': ['bgm.tv', 'bangumi.tv'],
    'Steam': ['store.steampowered.com'],
    '巴哈姆特': ['gamer.com.tw'],
    '米游社': ['miyoushe.com'],
    'PRTS': ['prts.wiki'],
  };

  static final _namedSite = <RegExp, String>{
    RegExp(r'微博|weibo[.]'): '微博',
    RegExp(r'[Bb]站|哔哩哔哩|bilibili[.]'): 'B站',
    RegExp(r'番组计划|bangumi|bgm[.]tv', caseSensitive: false): 'Bangumi',
    RegExp(r'\bsteam\b|蒸汽平台', caseSensitive: false): 'Steam',
    RegExp(r'巴哈姆特|gamer[.]com[.]tw'): '巴哈姆特',
    RegExp(r'米游社|miyoushe[.]'): '米游社',
    RegExp(r'\bprts\b', caseSensitive: false): 'PRTS',
  };
  static final _fresh = RegExp(r'刚刚|刚发|刚出|今天|最新|突发|这两天|今日');
  static final _chinese = RegExp(r'[\u3400-\u9fff]');
  static final _localNews = RegExp(r'公告|新闻|维护|实装|官宣|发售|上线|开播|版本|预告|活动');

  static List<PublicWebTopic> routes(
    String query, {
    required bool hasBaidu,
    Iterable<String> configuredDomains = const [],
    bool qq = false,
  }) {
    final domains = <String>{
      for (final entry in _namedSite.entries)
        if (entry.key.hasMatch(query)) ...sites[entry.value]!,
      for (final host in configuredDomains)
        if (query.toLowerCase().contains(host)) host,
    };
    final specified = domains.isNotEmpty;
    if (qq && domains.isEmpty) {
      if (RegExp(r'番剧|新番|声优|配音|放送').hasMatch(query)) {
        domains.addAll(sites['Bangumi']!);
      } else if (RegExp(
        r'实机|直播回放|攻略视频|PV',
        caseSensitive: false,
      ).hasMatch(query)) {
        domains.addAll(sites['B站']!);
      }
    }
    final fresh = _fresh.hasMatch(query);
    final baiduFirst =
        hasBaidu &&
        (domains.isNotEmpty ||
            _chinese.hasMatch(query) &&
                (fresh || qq && _localNews.hasMatch(query)));
    PublicWebTopic route(bool baidu, Iterable<String> target) => PublicWebTopic(
      query,
      domains: target.toList(growable: false),
      baidu: baidu,
      fresh: fresh,
    );
    return [
      route(baiduFirst, domains),
      if (hasBaidu)
        route(!baiduFirst, domains)
      else if (!specified && domains.isNotEmpty)
        route(false, const []),
    ];
  }

  static Uri? publicPage(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.host.split('.').length < 2 ||
        !RegExp(
          r'^[a-z0-9.-]+[.][a-z][a-z0-9-]+$',
          caseSensitive: false,
        ).hasMatch(uri.host) ||
        InternetAddress.tryParse(uri.host) != null ||
        const [
          '.local',
          '.internal',
          '.localhost',
          '.test',
          '.example',
          '.invalid',
        ].any(uri.host.toLowerCase().endsWith))
      return null;
    return uri.removeFragment();
  }

  static bool matchesDomain(String host, Iterable<String> domains) =>
      domains.isEmpty ||
      domains.any((site) => host == site || host.endsWith('.$site'));
}
