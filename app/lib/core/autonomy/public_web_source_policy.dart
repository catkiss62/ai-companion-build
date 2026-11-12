import '../models/public_web_candidate.dart';
import 'public_web_topic.dart';

enum PublicWebSourceGrade {
  firstParty('已识别的一手发布者'),
  editorial('编辑媒体'),
  reference('资料库或发行平台'),
  unconfirmed('发布者未确认');

  const PublicWebSourceGrade(this.label);
  final String label;
}

/// Orders links before reading and groups obvious copies of readable articles.
/// A known publisher raises reading priority. The body must still support the claim.
class PublicWebSourcePolicy {
  PublicWebSourcePolicy(String query) : _query = query.trim().toLowerCase();

  final String _query;

  static const _publishers = [
    (
      names: ['异环', 'neverness to everness'],
      sites: ['yh.wanmei.com', 'nte.perfectworld.com'],
      weibo: <String>[],
      bilibili: <String>[],
    ),
    (
      names: ['原神', 'genshin'],
      sites: ['ys.mihoyo.com', 'genshin.hoyoverse.com'],
      weibo: ['6593199887', 'ysmihoyo'],
      bilibili: ['401742377'],
    ),
    (
      names: ['明日方舟', 'arknights'],
      sites: ['ak.hypergryph.com'],
      weibo: ['6279793937', 'arknights'],
      bilibili: ['161775300'],
    ),
  ];

  PublicWebSourceGrade grade(String url) {
    final uri = PublicWebTopic.publicPage(url);
    if (uri == null) return PublicWebSourceGrade.unconfirmed;
    final host = uri.host;
    final path = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final onWeibo = const {
      'weibo.com',
      'www.weibo.com',
      'weibo.cn',
      'm.weibo.cn',
    }.contains(host);
    final weiboOwner = switch (path) {
      ['u', final id] => id,
      [final id, ...] => id,
      _ => '',
    };
    for (final publisher in _publishers) {
      if (_query.isNotEmpty && !publisher.names.any(_query.contains)) continue;
      if (publisher.sites.contains(host) ||
          onWeibo && publisher.weibo.contains(weiboOwner.toLowerCase()) ||
          host == 'space.bilibili.com' &&
              path.isNotEmpty &&
              publisher.bilibili.contains(path.first)) {
        return PublicWebSourceGrade.firstParty;
      }
    }
    if (PublicWebTopic.matchesDomain(host, [
      'gnn.gamer.com.tw',
      'reuters.com',
      'apnews.com',
      'news.cn',
    ])) {
      return PublicWebSourceGrade.editorial;
    }
    if (PublicWebTopic.matchesDomain(host, [
          'bgm.tv',
          'bangumi.tv',
          'prts.wiki',
        ]) ||
        host == 'store.steampowered.com' &&
            path.isNotEmpty &&
            path.first == 'app') {
      return PublicWebSourceGrade.reference;
    }
    return PublicWebSourceGrade.unconfirmed;
  }

  List<T> rank<T>(Iterable<T> items, String Function(T) url) {
    final ranked =
        [
          for (final (index, item) in items.indexed)
            (item: item, index: index, grade: grade(url(item)).index),
        ]..sort((a, b) {
          final order = a.grade.compareTo(b.grade);
          return order == 0 ? a.index.compareTo(b.index) : order;
        });
    return ranked.map((entry) => entry.item).toList(growable: false);
  }

  static String canonical(String url) {
    final uri = PublicWebTopic.publicPage(url);
    if (uri == null) return url;
    final parameters = {
      for (final entry in uri.queryParametersAll.entries)
        if (!entry.key.toLowerCase().startsWith('utm_') &&
            !const {
              'spm_id_from',
              'share_source',
              'share_medium',
              'share_plat',
            }.contains(entry.key.toLowerCase()))
          entry.key: entry.value,
    };
    return uri.removeFragment().replace(queryParameters: parameters).toString();
  }

  List<PublicWebCandidateDraft> distinctOriginals(
    Iterable<PublicWebCandidateDraft> items,
  ) {
    final urls = <String>{};
    final kept = <PublicWebCandidateDraft>[];
    final articles = <({Set<String> phrases, String numbers, String text})>[];
    for (final item in rank(items, (item) => item.url)) {
      if (!urls.add(canonical(item.url))) continue;
      final article = _articleSample(item.pageBody);
      if (article.phrases.isNotEmpty &&
          articles.any((previous) {
            if (article.numbers != previous.numbers) return false;
            final (
              longer,
              shorter,
            ) = article.text.length >= previous.text.length
                ? (article.text, previous.text)
                : (previous.text, article.text);
            if (shorter.length / longer.length >= .90 &&
                longer.contains(shorter)) {
              return true;
            }
            final common = article.phrases
                .intersection(previous.phrases)
                .length;
            return common /
                    (article.phrases.length +
                        previous.phrases.length -
                        common) >=
                .85;
          })) {
        continue;
      }
      articles.add(article);
      kept.add(item);
    }
    return kept;
  }

  static ({Set<String> phrases, String numbers, String text}) _articleSample(
    String body,
  ) {
    final sample = body.substring(0, body.length.clamp(0, 2400));
    final text = sample.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
    if (text.length < 160) return (phrases: const {}, numbers: '', text: '');
    return (
      phrases: {
        for (var i = 0; i + 8 <= text.length; i++) text.substring(i, i + 8),
      },
      numbers: RegExp(
        r'\d+',
      ).allMatches(sample).map((match) => match[0]).join(','),
      text: text,
    );
  }
}
