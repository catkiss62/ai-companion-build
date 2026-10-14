import '../database/app_database.dart';
import 'simulated_phone_repository.dart';

class SimulatedPhoneReadItem {
  const SimulatedPhoneReadItem({
    required this.handle,
    required this.section,
    required this.title,
    required this.body,
    required this.createdAt,
    this.source = '',
    this.facts = const {},
  });

  final String handle;
  final String section;
  final String title;
  final String body;
  final DateTime createdAt;
  final String source;
  final Map<String, Object?> facts;
}

/// Side-effect-free read adapter for the companion's simulated phone.
class SimulatedPhoneReader {
  SimulatedPhoneReader(this.db);

  final AppDatabase db;

  Future<List<SimulatedPhoneReadItem>> search(
    String query, {
    String section = 'all',
    String subject = 'all',
    String activity = 'all',
    int limit = 6,
  }) async {
    final snapshot = await SimulatedPhoneRepository(db).readOnlySnapshot();
    if (!snapshot.enabled) return const [];
    final normalizedSection = _normalizeSection(section);
    final candidates = _items(snapshot, includeCart: normalizedSection == 'cart')
        .where(
          (item) =>
              normalizedSection == 'all' || item.section == normalizedSection,
        )
        .where((item) => subject == 'all' || item.section != 'tarot' || item.facts['subject'] == subject)
        .where((item) => activity != 'writing' || const {'diary', 'note'}.contains(item.section))
        .toList(growable: false);
    final needle = _semanticQuery(query);
    final matched = needle.isEmpty
        ? candidates
        : candidates.where((item) {
            final text = '${item.title}\n${item.body}\n${item.source}'.toLowerCase();
            return text.contains(needle) ||
                _tokens(needle).any((token) => text.contains(token));
          }).toList(growable: false);
    matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matched.take(limit.clamp(1, 12).toInt()).toList(growable: false);
  }

  Future<SimulatedPhoneReadItem?> read({
    String handle = '',
    String section = 'all',
    String query = '',
    String subject = 'all',
    String activity = 'all',
  }) async {
    final normalizedHandle = handle.trim();
    if (normalizedHandle.isNotEmpty) {
      final snapshot = await SimulatedPhoneRepository(db).readOnlySnapshot();
      if (!snapshot.enabled) return null;
      for (final item in _items(snapshot, includeCart: normalizedHandle.startsWith('phone:cart:'))) {
        if (item.handle == normalizedHandle &&
            (subject == 'all' || item.section != 'tarot' || item.facts['subject'] == subject)) return item;
      }
      return null;
    }
    final matches = await search(query, section: section, subject: subject, activity: activity, limit: 1);
    return matches.isEmpty ? null : matches.first;
  }

  static List<SimulatedPhoneReadItem> _items(SimulatedPhoneSnapshot snapshot, {bool includeCart = false}) {
    final result = <SimulatedPhoneReadItem>[];
    void addEntries(String section, Iterable<SimulatedPhoneEntry> entries) {
      for (final entry in entries) {
        result.add(SimulatedPhoneReadItem(
          handle: 'phone:$section:${entry.id}',
          section: section,
          title: entry.title,
          body: section == 'tarot' ? [entry.body,
            if (entry.metadata['closing'] is String) '已有解读：${entry.metadata['closing']}'].join('\n') : entry.body,
          createdAt: entry.createdAt,
          source: entry.provenance,
          facts: {
            'record_source': entry.provenance, 'record_state': entry.state,
            if (section == 'cart') ...{'fictional': true, 'purchased': false,
              'price_unit': 'virtual_token', 'real_item_or_capability': false},
            if (section == 'tarot') ...{'subject': entry.state, 'card_name': entry.title,
              'reversed': entry.metadata['reversed'] is bool ? entry.metadata['reversed'] : null,
              'card_index': entry.metadata['card_index'], 'new_draw_performed': false},
          },
        ));
      }
    }

    addEntries('diary', snapshot.diary);
    addEntries('note', snapshot.notes);
    addEntries('mood', snapshot.moods);
    addEntries('wish', snapshot.wishes);
    addEntries(
      'wish',
      snapshot.completedWishes,
    );
    addEntries('wish', snapshot.archivedWishes);
    if (includeCart) addEntries('cart', snapshot.cart);
    final tarotSelf = snapshot.tarotSelf;
    final tarotUser = snapshot.tarotUser;
    if (tarotSelf != null) addEntries('tarot', [tarotSelf]);
    if (tarotUser != null) addEntries('tarot', [tarotUser]);
    for (final item in snapshot.albumItems) {
      if (!item.isVisible) continue;
      result.add(SimulatedPhoneReadItem(
        handle: 'phone:album:${item.id}',
        section: 'album',
        title: item.title,
        body: '${item.summary}\n收藏理由：${item.reason}'.trim(),
        createdAt: item.savedAt ?? item.createdAt,
        source: item.sourceDomain,
        facts: {'source_kind': item.sourceKind, 'lifecycle': item.lifecycle,
          'saved_at': item.savedAt?.millisecondsSinceEpoch,
          'original_available': item.hasOriginal, 'image_reobserved': false},
      ));
    }
    for (final item in snapshot.browserVisits) {
      result.add(SimulatedPhoneReadItem(
        handle: 'phone:browser:${item.id}',
        section: 'browser',
        title: item.title,
        body: <String>[
          if (item.searchQuery.isNotEmpty) '搜索：${item.searchQuery}',
          item.summary,
          if (item.readAt != null)
            '原网页读取时间：${item.readAt!.toLocal().toIso8601String()}',
          if (item.isLegacyUnverified) '旧版搜索片段，未重新读取原网页。',
        ].where((value) => value.trim().isNotEmpty).join('\n'),
        createdAt: item.discoveredAt,
        source: '${item.domain} ${item.url}'.trim(),
        facts: {'origin': item.origin, 'search_query': item.searchQuery,
          'action_run_id': item.actionRunId, 'read_state': item.readState,
          'read_at': item.readAt?.millisecondsSinceEpoch,
          'self_search_evidence': const {'autonomous', 'agent_tool', 'user_turn'}.contains(item.origin) &&
              item.actionRunId.isNotEmpty && item.searchQuery.isNotEmpty,
          'new_search_performed': false},
      ));
    }
    return result;
  }

  static String _normalizeSection(String value) {
    final normalized = value.trim().toLowerCase();
    const allowed = <String>{
      'all',
      'diary',
      'note',
      'mood',
      'wish',
      'cart',
      'tarot',
      'album',
      'browser',
    };
    return allowed.contains(normalized) ? normalized : 'all';
  }

  static Set<String> _tokens(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.length <= 1) return {compact};
    return {
      for (var index = 0; index < compact.length - 1; index++)
        compact.substring(index, index + 2),
    };
  }

  static String _semanticQuery(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'(麻烦|请你|帮我|给我|查一下|搜一下|找一下|检索一下|看一下|看看|'
          r'读一下|打开|查手机|你的手机|你手机|自己手机|手机里的|手机里|'
          r'日记|随笔|便签|心情|愿望|购物车|塔罗|浏览器|相册|里的|里面|'
          r'有没有|是否有|内容|记录)',
        ),
        '',
      )
      .replaceAll(RegExp(r'[\s，。！？、,.!?]+'), '');
}
