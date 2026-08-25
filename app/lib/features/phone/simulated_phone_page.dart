import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/phone/simulated_phone_repository.dart';

class SimulatedPhonePage extends StatefulWidget {
  const SimulatedPhonePage({super.key});

  @override
  State<SimulatedPhonePage> createState() => _SimulatedPhonePageState();
}

class _SimulatedPhonePageState extends State<SimulatedPhonePage> {
  late final SimulatedPhoneRepository _repository =
      SimulatedPhoneRepository(AppDatabase.instance);
  SimulatedPhoneSnapshot? _snapshot;
  bool _loading = true;
  bool _changingSwitch = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = _snapshot == null;
        _error = null;
      });
    }
    try {
      final next = await _repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = next;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '暂时没能读取这台手机里的内容。';
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (_changingSwitch) return;
    setState(() => _changingSwitch = true);
    try {
      await _repository.setEnabled(value);
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _changingSwitch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      backgroundColor: const Color(0xFF05080E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101B),
        foregroundColor: const Color(0xFFEAF4FF),
        title: const Text('她的手机'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07101B), Color(0xFF05080E), Color(0xFF081624)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _loading && snapshot == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _PhoneStatusCard(
                        enabled: snapshot?.enabled ?? true,
                        changing: _changingSwitch,
                        onChanged: _setEnabled,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFF9DA8)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _PhoneGrid(snapshot: snapshot),
                      const SizedBox(height: 18),
                      const _PrivacyFootnote(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PhoneStatusCard extends StatelessWidget {
  const _PhoneStatusCard({
    required this.enabled,
    required this.changing,
    required this.onChanged,
  });

  final bool enabled;
  final bool changing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF2D8CFF).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: const Text('🐋', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Whale Phone',
                  style: TextStyle(
                    color: Color(0xFFF4F8FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled ? '生活更新已开启' : '更新已暂停 · 历史仍可查看',
                  style: const TextStyle(color: Color(0xFF9DB0C8)),
                ),
              ],
            ),
          ),
          if (changing)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PhoneGrid extends StatelessWidget {
  const _PhoneGrid({required this.snapshot});

  final SimulatedPhoneSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <_PhoneAppItem>[
      _PhoneAppItem(
        title: '相册',
        subtitle: '真实图片收藏',
        icon: Icons.photo_library_outlined,
        tint: const Color(0xFF54A7FF),
        onTap: () => _open(
          context,
          const _EmptyPhoneAppPage(
            title: '相册',
            icon: Icons.photo_library_outlined,
            message: '还没有保存图片。\n相册会在下一批接入用户发图和真实网页图片。',
          ),
        ),
      ),
      _PhoneAppItem(
        title: '浏览器',
        subtitle: '真实浏览记录',
        icon: Icons.language_rounded,
        tint: const Color(0xFF4DD0E1),
        onTap: () => _open(
          context,
          const _EmptyPhoneAppPage(
            title: '浏览器',
            icon: Icons.language_rounded,
            message: '还没有可展示的真实浏览记录。\n这里不会用随机文字冒充访问历史。',
          ),
        ),
      ),
      _PhoneAppItem(
        title: '随笔',
        subtitle: '${snapshot?.notes.length ?? 0} 条',
        icon: Icons.edit_note_rounded,
        tint: const Color(0xFF8BA7FF),
        onTap: () => _open(
          context,
          _EntryListPage(
            title: '随笔',
            icon: Icons.edit_note_rounded,
            entries: snapshot?.notes ?? const [],
            emptyText: '今天还没有想写下来的随笔。',
          ),
        ),
      ),
      _PhoneAppItem(
        title: '心情',
        subtitle: snapshot?.moods.firstOrNull?.title ?? '今天还没有记录',
        icon: Icons.water_drop_outlined,
        tint: const Color(0xFF66B7FF),
        onTap: () => _open(
          context,
          _EntryListPage(
            title: '心情',
            icon: Icons.water_drop_outlined,
            entries: snapshot?.moods ?? const [],
            emptyText: '今天还没有留下心情颜色。',
          ),
        ),
      ),
      _PhoneAppItem(
        title: '愿望单',
        subtitle: '${snapshot?.wishes.length ?? 0} 个进行中',
        icon: Icons.auto_awesome_outlined,
        tint: const Color(0xFF6F8CFF),
        onTap: () => _open(
          context,
          _WishPage(snapshot: snapshot),
        ),
      ),
      _PhoneAppItem(
        title: '日记',
        subtitle: '${snapshot?.diary.length ?? 0} 篇',
        icon: Icons.menu_book_outlined,
        tint: const Color(0xFF3C91E6),
        onTap: () => _open(
          context,
          _EntryListPage(
            title: '日记',
            icon: Icons.menu_book_outlined,
            entries: snapshot?.diary ?? const [],
            emptyText: '跨过零点后，她会为刚结束的一天留下一篇日记。',
          ),
        ),
      ),
      _PhoneAppItem(
        title: '购物车',
        subtitle: '${snapshot?.cart.length ?? 0} 件想买',
        icon: Icons.shopping_bag_outlined,
        tint: const Color(0xFF5D9CFF),
        onTap: () => _open(
          context,
          _CartPage(entries: snapshot?.cart ?? const []),
        ),
      ),
      _PhoneAppItem(
        title: '塔罗牌',
        subtitle: '我 / 他 · 今日两张',
        icon: Icons.style_outlined,
        tint: const Color(0xFF7594FF),
        onTap: () => _open(
          context,
          _TarotPage(
            self: snapshot?.tarotSelf,
            user: snapshot?.tarotUser,
          ),
        ),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _PhoneAppTile(item: items[index]),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _PhoneAppItem {
  const _PhoneAppItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
}

class _PhoneAppTile extends StatelessWidget {
  const _PhoneAppTile({required this.item});

  final _PhoneAppItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: item.onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: item.tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: item.tint.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: item.tint.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(item.icon, color: item.tint, size: 29),
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFEAF2FF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8195AD), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _EntryListPage extends StatelessWidget {
  const _EntryListPage({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<SimulatedPhoneEntry> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return _PhoneSubScaffold(
      title: title,
      child: entries.isEmpty
          ? _EmptyState(icon: icon, message: emptyText)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _EntryCard(entry: entries[index]),
            ),
    );
  }
}

class _WishPage extends StatelessWidget {
  const _WishPage({required this.snapshot});

  final SimulatedPhoneSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final active = snapshot?.wishes ?? const <SimulatedPhoneEntry>[];
    final completed = snapshot?.completedWishes ?? const <SimulatedPhoneEntry>[];
    return DefaultTabController(
      length: 2,
      child: _PhoneSubScaffold(
        title: '愿望单',
        bottom: const TabBar(tabs: [Tab(text: '进行中'), Tab(text: '已实现')]),
        child: TabBarView(
          children: [
            _WishList(
              entries: active,
              emptyText: '现在没有足够明确、反复出现的愿望。',
            ),
            _WishList(
              entries: completed,
              emptyText: '已经实现的愿望会留在这里。',
            ),
          ],
        ),
      ),
    );
  }
}

class _WishList extends StatelessWidget {
  const _WishList({required this.entries, required this.emptyText});
  final List<SimulatedPhoneEntry> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyState(icon: Icons.auto_awesome_outlined, message: emptyText);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _EntryCard(
        entry: entries[index],
        leading: entries[index].state == 'completed'
            ? Icons.check_circle_outline_rounded
            : Icons.star_border_rounded,
      ),
    );
  }
}

class _CartPage extends StatelessWidget {
  const _CartPage({required this.entries});
  final List<SimulatedPhoneEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _PhoneSubScaffold(
      title: '购物车',
      child: entries.isEmpty
          ? const _EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: '今天还没有往购物车里放东西。',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final price = entry.metadata['token_price'] as num? ?? 0;
                return _GlassCard(
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: Color(0xFF65A9FF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(entry.body, style: const TextStyle(color: Color(0xFFA7B8CB), height: 1.4)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$price token',
                        style: const TextStyle(color: Color(0xFF78B5FF), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _TarotPage extends StatelessWidget {
  const _TarotPage({required this.self, required this.user});

  final SimulatedPhoneEntry? self;
  final SimulatedPhoneEntry? user;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: _PhoneSubScaffold(
        title: '塔罗牌',
        bottom: const TabBar(tabs: [Tab(text: '我'), Tab(text: '他')]),
        child: TabBarView(
          children: [
            _TarotReading(entry: self, label: '我的今日占卜'),
            _TarotReading(entry: user, label: '他的今日占卜'),
          ],
        ),
      ),
    );
  }
}

class _TarotReading extends StatelessWidget {
  const _TarotReading({required this.entry, required this.label});
  final SimulatedPhoneEntry? entry;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = entry;
    if (value == null) {
      return const _EmptyState(
        icon: Icons.style_outlined,
        message: '今日牌还没有准备好。',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9CB4D2))),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 196,
            height: 300,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF102C4B), Color(0xFF09111E)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4E9CFF).withValues(alpha: 0.62)),
              boxShadow: const [BoxShadow(color: Color(0x442D8CFF), blurRadius: 32)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nights_stay_outlined, size: 58, color: Color(0xFF85BCFF)),
                const SizedBox(height: 22),
                Text(
                  value.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFF1F7FF)),
                ),
                const SizedBox(height: 12),
                Text(value.localDay, style: const TextStyle(color: Color(0xFF8EA8C5))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _GlassCard(
          child: Text(value.body, style: const TextStyle(fontSize: 16, height: 1.65, color: Color(0xFFDCEAFF))),
        ),
        const SizedBox(height: 12),
        const Text(
          '每日娱乐占卜 · 不替代现实判断',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF72869D), fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyPhoneAppPage extends StatelessWidget {
  const _EmptyPhoneAppPage({required this.title, required this.icon, required this.message});
  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => _PhoneSubScaffold(
        title: title,
        child: _EmptyState(icon: icon, message: message),
      );
}

class _PhoneSubScaffold extends StatelessWidget {
  const _PhoneSubScaffold({required this.title, required this.child, this.bottom});
  final String title;
  final Widget child;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07101B),
        foregroundColor: const Color(0xFFEAF4FF),
        title: Text(title),
        bottom: bottom,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07101B), Color(0xFF05080E), Color(0xFF081624)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.leading});
  final SimulatedPhoneEntry entry;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Icon(leading, color: const Color(0xFF6DAEFF)),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF0F6FF))),
                const SizedBox(height: 7),
                Text(entry.body, style: const TextStyle(color: Color(0xFFB6C8DC), height: 1.55)),
                const SizedBox(height: 9),
                Text(entry.localDay, style: const TextStyle(color: Color(0xFF71869E), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF6DAEFF)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFA9BCD2), height: 1.55)),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF122033).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF5EA8FF).withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

class _PrivacyFootnote extends StatelessWidget {
  const _PrivacyFootnote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '关闭更新不会删除历史；塔罗牌仍会每天更新。',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF71869E), fontSize: 12),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
