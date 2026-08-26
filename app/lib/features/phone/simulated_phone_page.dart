import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/phone/simulated_phone_repository.dart';
import '../../core/models/companion_album.dart';
import '../../core/storage/companion_album_storage.dart';

const bg = Color(0xFF080C18);
const text1 = Color(0xFFF0F0F5);
const text2 = Color(0xFF999AA8);
const text3 = Color(0xFF626472);
const purple = Color(0xFFA78BFA);
const blue = Color(0xFF60A5FA);
const green = Color(0xFF34D399);
const red = Color(0xFFF87171);
const orange = Color(0xFFFB923C);
const pink = Color(0xFFF472B6);
const yellow = Color(0xFFFBBF24);

class SimulatedPhonePage extends StatefulWidget {
  const SimulatedPhonePage({super.key});

  @override
  State<SimulatedPhonePage> createState() => _SimulatedPhonePageState();
}

class _SimulatedPhonePageState extends State<SimulatedPhonePage> {
  late final SimulatedPhoneRepository repository =
      SimulatedPhoneRepository(AppDatabase.instance);
  SimulatedPhoneSnapshot? snapshot;
  Timer? timer;
  Timer? unlockTimer;
  DateTime now = DateTime.now();
  bool locked = true;
  bool unlocking = false;
  bool loading = true;
  bool changingSwitch = false;
  double unlockDrag = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(load());
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    unlockTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = snapshot == null;
        error = null;
      });
    }
    try {
      final next = await repository.load();
      if (!mounted) return;
      setState(() {
        snapshot = next;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '暂时没能读取这台手机里的内容。';
      });
    }
  }

  Future<void> setEnabled(bool value) async {
    if (changingSwitch) return;
    setState(() => changingSwitch = true);
    try {
      await repository.setEnabled(value);
      await load(silent: true);
    } finally {
      if (mounted) setState(() => changingSwitch = false);
    }
  }

  void unlock() {
    if (!locked || unlocking) return;
    setState(() {
      unlocking = true;
      unlockDrag = 108;
    });
    unlockTimer?.cancel();
    unlockTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        locked = false;
        unlocking = false;
        unlockDrag = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
          fit: StackFit.expand,
          children: [
            const Wallpaper(),
            SafeArea(
              child: Column(
                children: [
                  PhoneStatusBar(now: now),
                  Expanded(
                    child: loading && snapshot == null
                        ? const Center(
                            child: CircularProgressIndicator(color: purple),
                          )
                        : HomeScreen(
                            snapshot: snapshot,
                            error: error,
                            changingSwitch: changingSwitch,
                            onEnabledChanged: setEnabled,
                            onRefresh: load,
                          ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              ignoring: !locked || unlocking,
              child: AnimatedOpacity(
                opacity: locked && !unlocking ? 1 : 0,
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeInOutCubic,
                child: AnimatedScale(
                  scale: unlocking ? 1.08 : 1,
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedSlide(
                    offset: unlocking ? const Offset(0, -0.07) : Offset.zero,
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeInOutCubic,
                    child: LockScreen(
                    now: now,
                    snapshot: snapshot,
                    drag: unlockDrag,
                    onDrag: (delta) {
                      setState(() {
                        unlockDrag =
                            (unlockDrag - delta).clamp(0, 108).toDouble();
                      });
                    },
                    onDragEnd: () {
                      if (unlockDrag >= 72) {
                        unlock();
                      } else {
                        setState(() => unlockDrag = 0);
                      }
                    },
                      onUnlock: unlock,
                    ),
                  ),
                ),
              ),
            ),
          ],
      ),
    );
  }
}

class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          gradient: RadialGradient(
            center: Alignment(-0.86, -0.82),
            radius: 1.3,
            colors: [Color(0xFF2A1060), Color(0x001F1545)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.88, 0.84),
              radius: 1.2,
              colors: [Color(0xFF0A2450), Color(0x000A1E50)],
            ),
          ),
        ),
      );
}

class PhoneStatusBar extends StatelessWidget {
  const PhoneStatusBar({required this.now, super.key});
  final DateTime now;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(21, 8, 19, 6),
        child: SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  phoneTime(now),
                  style: const TextStyle(
                    color: text1,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('📶  🛜  🔋', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
}

class LockScreen extends StatelessWidget {
  const LockScreen({
    required this.now,
    required this.snapshot,
    required this.drag,
    required this.onDrag,
    required this.onDragEnd,
    required this.onUnlock,
    super.key,
  });

  final DateTime now;
  final SimulatedPhoneSnapshot? snapshot;
  final double drag;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final latest = snapshot?.notes.firstOrNull ?? snapshot?.moods.firstOrNull;
    final notice = latest?.body ?? '有些没说出口的小事，被她留在了手机里。';
    return Material(
      color: bg.withValues(alpha: 0.97),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Wallpaper(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 48, 25, 28),
              child: Column(
                children: [
                  Text(
                    phoneTime(now),
                    style: const TextStyle(
                      color: text1,
                      fontSize: 76,
                      fontWeight: FontWeight.w200,
                      height: 1,
                      letterSpacing: -4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    phoneDate(now),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Glass(
                    radius: 18,
                    padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🐋  Whale Phone · 刚刚',
                          style: TextStyle(color: text2, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notice,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: text1,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '向上滑动，或轻触解锁',
                    style: TextStyle(color: text3, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 62,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 1,
                            height: 102,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.19),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -drag),
                          child: GestureDetector(
                            onTap: onUnlock,
                            onVerticalDragUpdate: (details) =>
                                onDrag(details.delta.dy),
                            onVerticalDragEnd: (_) => onDragEnd(),
                            child: Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.09),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: purple.withValues(alpha: 0.18),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text(
                                '↑',
                                style: TextStyle(fontSize: 23),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const HomeIndicator(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.snapshot,
    required this.error,
    required this.changingSwitch,
    required this.onEnabledChanged,
    required this.onRefresh,
    super.key,
  });

  final SimulatedPhoneSnapshot? snapshot;
  final String? error;
  final bool changingSwitch;
  final ValueChanged<bool> onEnabledChanged;
  final Future<void> Function({bool silent}) onRefresh;

  @override
  Widget build(BuildContext context) {
    final apps = buildApps(snapshot, onRefresh);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => onRefresh(),
            color: purple,
            backgroundColor: const Color(0xFF151625),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 290),
                        child: Glass(
                          radius: 28,
                          padding: const EdgeInsets.fromLTRB(7, 6, 8, 6),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFEEEAF8),
                                backgroundImage: AssetImage(
                                  'assets/appearance/chat_avatar.webp',
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Whale Phone',
                                      style: TextStyle(
                                        color: text1,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      snapshot?.enabled == false
                                          ? '更新已暂停'
                                          : '生活更新中',
                                      style: const TextStyle(
                                        color: text3,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (changingSwitch)
                                const SizedBox.square(
                                  dimension: 21,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Transform.scale(
                                  scale: 0.82,
                                  child: Switch(
                                    value: snapshot?.enabled ?? true,
                                    activeThumbColor: purple,
                                    onChanged: onEnabledChanged,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.07),
                        foregroundColor: text2,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Color(0xFFFF9DA8))),
                ],
                const SizedBox(height: 23),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 21,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: apps.length,
                  itemBuilder: (_, index) => AppIcon(item: apps[index]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Glass(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [apps[0], apps[1], apps[7]]
                  .map((item) => DockIcon(item: item))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '关闭更新不会删除历史 · 塔罗牌仍会每天更新',
          textAlign: TextAlign.center,
          style: TextStyle(color: text3, fontSize: 11),
        ),
        const SizedBox(height: 8),
        const HomeIndicator(),
        const SizedBox(height: 3),
      ],
    );
  }
}

class PhoneAppItem {
  const PhoneAppItem({
    required this.title,
    required this.emoji,
    required this.colors,
    required this.page,
    this.badge,
    this.onOpen,
    this.onClosed,
  });

  final String title;
  final String emoji;
  final List<Color> colors;
  final int? badge;
  final Widget page;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onClosed;
}

List<PhoneAppItem> buildApps(
  SimulatedPhoneSnapshot? snapshot,
  Future<void> Function({bool silent}) onRefresh,
) {
  final repository = SimulatedPhoneRepository(AppDatabase.instance);
  Future<void> refreshAfterClose() => onRefresh(silent: true);
  return [
    PhoneAppItem(
      title: '相册',
      emoji: '🖼️',
      colors: const [Color(0xFF381146), Color(0xFF8B5CF6)],
      badge: snapshot?.albumUnread,
      onOpen: repository.markAlbumRead,
      onClosed: refreshAfterClose,
      page: AlbumPage(
        entries: snapshot?.albumItems ?? const [],
        repository: repository,
      ),
    ),
    PhoneAppItem(
      title: '浏览器',
      emoji: '🌐',
      colors: const [Color(0xFF062D5D), Color(0xFF3B82F6)],
      page: BrowserPage(entries: snapshot?.browserVisits ?? const []),
    ),
    PhoneAppItem(
      title: '随笔',
      emoji: '📝',
      colors: const [Color(0xFF493D04), yellow],
      badge: snapshot?.notesUnread,
      onOpen: repository.markNotesRead,
      onClosed: refreshAfterClose,
      page: NotesPage(entries: snapshot?.notes ?? const []),
    ),
    PhoneAppItem(
      title: '心情',
      emoji: '💗',
      colors: const [Color(0xFF50101A), pink],
      page: MoodPage(entries: snapshot?.moods ?? const []),
    ),
    PhoneAppItem(
      title: '愿望单',
      emoji: '✨',
      colors: const [Color(0xFF261153), purple],
      page: WishPage(snapshot: snapshot),
    ),
    PhoneAppItem(
      title: '日记',
      emoji: '📔',
      colors: const [Color(0xFF0A3526), green],
      page: DiaryPage(entries: snapshot?.diary ?? const []),
    ),
    PhoneAppItem(
      title: '购物车',
      emoji: '🛒',
      colors: const [Color(0xFF482006), orange],
      page: CartPage(entries: snapshot?.cart ?? const []),
    ),
    PhoneAppItem(
      title: '塔罗牌',
      emoji: '🔮',
      colors: const [Color(0xFF301044), Color(0xFFE879F9)],
      page: TarotPage(
        self: snapshot?.tarotSelf,
        user: snapshot?.tarotUser,
      ),
    ),
  ];
}

Future<void> openPhoneApp(BuildContext context, PhoneAppItem item) async {
  final onOpen = item.onOpen;
  if (onOpen != null) await onOpen();
  if (!context.mounted) return;
  await openPhonePage(context, item.page);
  final onClosed = item.onClosed;
  if (onClosed != null) await onClosed();
}

class AppIcon extends StatelessWidget {
  const AppIcon({required this.item, super.key});
  final PhoneAppItem item;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: () => openPhoneApp(context, item),
        radius: 42,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 59,
                  height: 59,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item.colors,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.colors.last.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Text(item.emoji,
                      style: const TextStyle(fontSize: 27)),
                ),
                if ((item.badge ?? 0) > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: bg, width: 1.5),
                      ),
                      child: Text(
                        item.badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: text1, fontSize: 11.5),
            ),
          ],
        ),
      );
}

class DockIcon extends StatelessWidget {
  const DockIcon({required this.item, super.key});
  final PhoneAppItem item;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: () => openPhoneApp(context, item),
        radius: 32,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: item.colors),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(item.emoji, style: const TextStyle(fontSize: 23)),
        ),
      );
}

class AlbumPage extends StatefulWidget {
  const AlbumPage({
    required this.entries,
    required this.repository,
    super.key,
  });

  final List<CompanionAlbumItem> entries;
  final SimulatedPhoneRepository repository;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  String category = 'all';
  late List<CompanionAlbumItem> entries = [...widget.entries];

  List<CompanionAlbumItem> get visible => category == 'all'
      ? entries
      : entries.where((item) => item.category == category).toList();

  @override
  Widget build(BuildContext context) {
    final items = visible;
    return PhoneAppScaffold(
      emoji: '🖼️',
      title: '相册',
      actions: [
        IconButton(
          tooltip: '清理未引用缓存',
          onPressed: () async {
            final removed = await widget.repository.clearAlbumCache();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已清理 ${removed} 个未引用缩略图')),
            );
          },
          icon: const Icon(Icons.cleaning_services_outlined, size: 20),
        ),
      ],
      child: entries.isEmpty
          ? const HonestEmpty(
              emoji: '🌊',
              title: '还没有保存图片',
              body: '只有她真正看过并决定收藏的图片才会出现在这里。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _AlbumFilter(
                        label: '全部',
                        active: category == 'all',
                        onTap: () => setState(() => category = 'all'),
                      ),
                      _AlbumFilter(
                        label: '回忆',
                        active: category == 'memory',
                        onTap: () => setState(() => category = 'memory'),
                      ),
                      _AlbumFilter(
                        label: '形象插画',
                        active: category == 'self_image',
                        onTap: () => setState(() => category = 'self_image'),
                      ),
                      _AlbumFilter(
                        label: 'NSFW',
                        active: category == 'nsfw',
                        onTap: () => setState(() => category = 'nsfw'),
                      ),
                      _AlbumFilter(
                        label: '其他',
                        active: category == 'other',
                        onTap: () => setState(() => category = 'other'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${items.length} 张',
                      style: const TextStyle(
                        color: text1,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '仅本地缩略图',
                      style: TextStyle(color: text3, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 72),
                    child: HonestEmpty(
                      emoji: '🫧',
                      title: '这个分类还是空的',
                      body: '她还没有把图片放进这里。',
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _AlbumTile(
                        item: item,
                        onTap: () async {
                          await openPhonePage(
                            context,
                            AlbumDetailPage(
                              item: item,
                              repository: widget.repository,
                            ),
                          );
                          if (!mounted) return;
                          final current = await AppDatabase.instance
                              .companionAlbumItems(includeNsfw: true);
                          setState(() => entries = current);
                        },
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class _AlbumFilter extends StatelessWidget {
  const _AlbumFilter({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          onSelected: (_) => onTap(),
          selectedColor: purple.withValues(alpha: 0.28),
          backgroundColor: Colors.white.withValues(alpha: 0.055),
          side: BorderSide(
            color: active
                ? purple.withValues(alpha: 0.48)
                : Colors.white.withValues(alpha: 0.08),
          ),
          labelStyle: TextStyle(color: active ? text1 : text2),
          showCheckmark: false,
        ),
      );
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.item, required this.onTap});
  final CompanionAlbumItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<File>(
                future: CompanionAlbumStorage().fileFor(item.thumbnailPath),
                builder: (context, snapshot) => snapshot.hasData
                    ? Image.file(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _MissingAlbumImage(),
                      )
                    : const ColoredBox(
                        color: Color(0x191F2937),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
              ),
              if (item.nsfw)
                Container(
                  color: const Color(0xDD11131B),
                  alignment: Alignment.center,
                  child: const Text(
                    '🔞\n轻触查看',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: text2, fontSize: 11),
                  ),
                ),
              if (item.isPendingDelete)
                Positioned(
                  left: 5,
                  right: 5,
                  bottom: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xDDB91C1C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '1小时后清理',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _MissingAlbumImage extends StatelessWidget {
  const _MissingAlbumImage();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white.withValues(alpha: 0.04),
        alignment: Alignment.center,
        child: const Text('🫥', style: TextStyle(fontSize: 26)),
      );
}

class AlbumDetailPage extends StatefulWidget {
  const AlbumDetailPage({
    required this.item,
    required this.repository,
    super.key,
  });
  final CompanionAlbumItem item;
  final SimulatedPhoneRepository repository;

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late String feedback = widget.item.feedback;
  late String comment = widget.item.comment;
  bool revealNsfw = false;
  bool busy = false;

  Future<void> setFeedback(String value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.repository.setAlbumFeedback(
        widget.item.id,
        feedback: value,
        comment: comment,
      );
      if (!mounted) return;
      setState(() => feedback = value);
      if (value == 'dislike') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已记录审美偏好；这张图会在 1 小时后清理')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editComment() async {
    final controller = TextEditingController(text: comment);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('给这张图留个备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 600,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '不会变成聊天消息或事实记忆'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await widget.repository.setAlbumFeedback(
      widget.item.id,
      feedback: feedback,
      comment: value,
    );
    if (mounted) setState(() => comment = value);
  }

  Future<void> deleteNow() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除这张收藏？'),
            content: const Text('这会立即删除本地相册缩略图；不会删除原聊天消息。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.repository.deleteAlbumItem(widget.item.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PhoneAppScaffold(
        emoji: '🖼️',
        title: widget.item.title.isEmpty ? '图片详情' : widget.item.title,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<File>(
                      future: CompanionAlbumStorage()
                          .fileFor(widget.item.thumbnailPath),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Image.file(snapshot.data!, fit: BoxFit.contain)
                          : const _MissingAlbumImage(),
                    ),
                    if (widget.item.nsfw && !revealNsfw)
                      InkWell(
                        onTap: () => setState(() => revealNsfw = true),
                        child: Container(
                          color: const Color(0xF211131B),
                          alignment: Alignment.center,
                          child: const Text(
                            '🔞\nNSFW 分类\n轻触后显示',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: text1, height: 1.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              widget.item.summary,
              style: const TextStyle(color: text1, height: 1.55),
            ),
            if (widget.item.reason.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                '她保存它的理由：${widget.item.reason}',
                style: const TextStyle(color: purple, height: 1.5),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '来源：${widget.item.sourceDomain.isEmpty ? '你发来的图片' : widget.item.sourceDomain}'
              ' · ${albumCategoryLabel(widget.item.category)}',
              style: const TextStyle(color: text3, fontSize: 11),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeedbackButton(
                  label: '👍 喜欢',
                  active: feedback == 'like',
                  onPressed: busy ? null : () => setFeedback('like'),
                ),
                _FeedbackButton(
                  label: '👎 不喜欢',
                  active: feedback == 'dislike',
                  onPressed: busy ? null : () => setFeedback('dislike'),
                ),
                _FeedbackButton(
                  label: '➖ 不判断',
                  active: feedback == 'neutral',
                  onPressed: busy ? null : () => setFeedback('neutral'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : editComment,
                  icon: const Icon(Icons.mode_comment_outlined, size: 16),
                  label: Text(comment.isEmpty ? '留言' : '修改留言'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : deleteNow,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('删除'),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(comment,
                    style: const TextStyle(color: text2, height: 1.5)),
              ),
            ],
          ],
        ),
      );
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor:
              active ? purple.withValues(alpha: 0.32) : null,
        ),
        child: Text(label),
      );
}

class BrowserPage extends StatelessWidget {
  const BrowserPage({required this.entries, super.key});
  final List<CompanionBrowserVisit> entries;

  @override
  Widget build(BuildContext context) => PhoneAppScaffold(
        emoji: '🌐',
        title: '浏览器',
        child: entries.isEmpty
            ? const HonestEmpty(
                emoji: '🧭',
                title: '没有真实浏览记录',
                body: '这里只显示她真正完成的自主公开网页搜索；失败、测试和搜索意图不会冒充历史。',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xB3141824),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🌐', style: TextStyle(fontSize: 17)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: text1,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.summary,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: text2, height: 1.48),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${entry.domain} · ${entry.provider} · ${phoneDateTime(entry.discoveredAt)}',
                          style: const TextStyle(color: text3, fontSize: 10.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
}

class NotesPage extends StatelessWidget {
  const NotesPage({required this.entries, super.key});
  final List<SimulatedPhoneEntry> entries;

  @override
  Widget build(BuildContext context) => PhoneAppScaffold(
        emoji: '📝',
        title: '随笔',
        child: entries.isEmpty
            ? const HonestEmpty(
                emoji: '✍️',
                title: '今天还没有随笔',
                body: '有真正想写下来的小念头时，它会出现在这里。',
              )
            : ListView.separated(
                padding: const EdgeInsets.only(top: 6, bottom: 28),
                itemCount: entries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    title: Text(
                      entry.title,
                      style: const TextStyle(
                        color: text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          entry.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: text2, height: 1.45),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.localDay} · ${phoneTime(entry.createdAt)}',
                          style:
                              const TextStyle(color: text3, fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () => openPhonePage(
                      context,
                      EntryDetailPage(entry: entry, emoji: '📝'),
                    ),
                  );
                },
              ),
      );
}

class MoodPage extends StatefulWidget {
  const MoodPage({required this.entries, super.key});
  final List<SimulatedPhoneEntry> entries;

  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final latest = widget.entries.firstOrNull;
    if (latest == null) {
      return const PhoneAppScaffold(
        emoji: '💗',
        title: '心情',
        child: HonestEmpty(
          emoji: '🌙',
          title: '今天还没有心情记录',
          body: '这里会每天从现有情绪与欲望状态留下一个有界快照。',
        ),
      );
    }
    final stats = [
      ('🌊', '心情能量', metaInt(latest, 'energy', 55), pink),
      ('💞', '亲近感', metaInt(latest, 'closeness', 50), red),
      ('🫧', '好奇心', metaInt(latest, 'curiosity', 50), green),
      ('🔋', '精神余量', metaInt(latest, 'reserve', 50), purple),
    ];
    final history = widget.entries.take(7).toList().reversed.toList();
    final values = history
        .map((entry) => metaInt(entry, 'score', 50).toDouble())
        .toList();
    final selectedEntry =
        selected == null || selected! >= history.length
            ? null
            : history[selected!];
    return PhoneAppScaffold(
      emoji: '💗',
      title: '心情',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 1.30,
            ),
            itemBuilder: (_, index) {
              final item = stats[index];
              return Glass(
                radius: 13,
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.$1 + ' ' + item.$2,
                      style: TextStyle(color: item.$4, fontSize: 11),
                    ),
                    Text.rich(
                      TextSpan(
                        text: item.$3.toString(),
                        style: TextStyle(
                          color: item.$4,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                        ),
                        children: const [
                          TextSpan(
                            text: '%',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      moodStatNote(index, item.$3),
                      style: const TextStyle(
                        color: text3,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 11),
          Glass(
            radius: 13,
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('💓 本周心情变化',
                        style: TextStyle(color: text2, fontSize: 12)),
                    Text('mood',
                        style: TextStyle(color: pink, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 210,
                  child: MoodChart(
                    entries: history,
                    values: values,
                    selected: selected,
                    onSelected: (value) =>
                        setState(() => selected = value),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  selectedEntry == null
                      ? '点击节点查看当天说明'
                      : selectedEntry.localDay +
                          ' · ' +
                          selectedEntry.title +
                          ' · ' +
                          selectedEntry.body,
                  style: const TextStyle(
                    color: purple,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: pink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: pink.withValues(alpha: 0.18)),
            ),
            child: Text(
              latest.title + '\n' + latest.body,
              style: const TextStyle(color: text1, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class MoodChart extends StatelessWidget {
  const MoodChart({
    required this.entries,
    required this.values,
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final List<SimulatedPhoneEntry> entries;
  final List<double> values;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final usable = math.max(1.0, constraints.maxWidth - 36);
          final fraction =
              ((details.localPosition.dx - 22) / usable).clamp(0.0, 1.0);
          final index = values.length == 1
              ? 0
              : (fraction * (values.length - 1)).round();
          onSelected(index.clamp(0, values.length - 1).toInt());
        },
        child: CustomPaint(
          painter: MoodChartPainter(
            values: values,
            labels: entries
                .map((entry) => entry.localDay.substring(5))
                .toList(),
            selected: selected,
          ),
        ),
      ),
    );
  }
}

class MoodChartPainter extends CustomPainter {
  const MoodChartPainter({
    required this.values,
    required this.labels,
    this.selected,
  });
  final List<double> values;
  final List<String> labels;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 22.0;
    const right = 12.0;
    const top = 10.0;
    const bottom = 25.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    Offset point(int index) {
      final x = values.length == 1
          ? left + width / 2
          : left + width * index / (values.length - 1);
      final normalized = ((values[index] - 10) / 90).clamp(0.0, 1.0);
      return Offset(x, top + height * (1 - normalized));
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
    }
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(point(values.length - 1).dx, top + height)
      ..lineTo(point(0).dx, top + height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            pink.withValues(alpha: 0.46),
            pink.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, top, size.width, height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = pink.withValues(alpha: 0.95)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(
        p,
        selected == i ? 6 : 4,
        Paint()..color = selected == i ? yellow : pink,
      );
      canvas.drawCircle(
        p,
        selected == i ? 6 : 4,
        Paint()
          ..color = bg
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: text3, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(p.dx - label.width / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant MoodChartPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.values.toString() != values.toString();
}

class WishPage extends StatelessWidget {
  const WishPage({required this.snapshot, super.key});
  final SimulatedPhoneSnapshot? snapshot;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: PhoneAppScaffold(
          emoji: '✨',
          title: '愿望单',
          bottom: const TabBar(
            indicatorColor: purple,
            labelColor: text1,
            unselectedLabelColor: text3,
            tabs: [Tab(text: '进行中'), Tab(text: '已实现')],
          ),
          child: TabBarView(
            children: [
              WishList(
                entries: snapshot?.wishes ?? const [],
                completed: false,
              ),
              WishList(
                entries: snapshot?.completedWishes ?? const [],
                completed: true,
              ),
            ],
          ),
        ),
      );
}

class WishList extends StatelessWidget {
  const WishList({
    required this.entries,
    required this.completed,
    super.key,
  });
  final List<SimulatedPhoneEntry> entries;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return HonestEmpty(
        emoji: completed ? '🌟' : '💫',
        title: completed ? '还没有已实现的愿望' : '现在没有足够明确的愿望',
        body: completed
            ? '真正实现的愿望会被留在这里。'
            : '自然衰退或放弃的愿望不会留下假记录。',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final entry = entries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: purple.withValues(alpha: completed ? 0.055 : 0.09),
            border: Border.all(color: purple.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(completed ? '✅' : '⭐',
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.body,
                        style:
                            const TextStyle(color: text1, height: 1.5)),
                    const SizedBox(height: 6),
                    Text(entry.localDay,
                        style:
                            const TextStyle(color: text3, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({required this.entries, super.key});
  final List<SimulatedPhoneEntry> entries;

  @override
  Widget build(BuildContext context) => PhoneAppScaffold(
        emoji: '📔',
        title: '日记',
        child: entries.isEmpty
            ? const HonestEmpty(
                emoji: '🌃',
                title: '日记还没有写下来',
                body: '跨过零点后，她会为刚结束的一天最多留下一篇。',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => openPhonePage(
                      context,
                      EntryDetailPage(entry: entry, emoji: '📔'),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: green.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: green.withValues(alpha: 0.19)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  dayPart(entry.localDay),
                                  style: const TextStyle(
                                    color: green,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  monthPart(entry.localDay),
                                  style: const TextStyle(
                                      color: text3, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.title,
                                  style: const TextStyle(
                                    color: text1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  entry.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: text2, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
}

class CartPage extends StatelessWidget {
  const CartPage({required this.entries, super.key});
  final List<SimulatedPhoneEntry> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(
      0,
      (sum, entry) =>
          sum + (entry.metadata['token_price'] as num? ?? 0).round(),
    );
    return PhoneAppScaffold(
      emoji: '🛒',
      title: '购物车',
      child: entries.isEmpty
          ? const HonestEmpty(
              emoji: '📦',
              title: '购物车空空的',
              body: '今天还没有想买的正常物品或奇怪东西。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: [
                SectionLabel('购物车 · ' + entries.length.toString() + ' 件'),
                const SizedBox(height: 8),
                ...entries.map((entry) {
                  final price =
                      entry.metadata['token_price'] as num? ?? 0;
                  final emoji = entry.metadata['emoji'] as String? ??
                      cartEmoji(entry.title);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 2,
                      ),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(13, 0, 13, 13),
                      iconColor: orange,
                      collapsedIconColor: text3,
                      leading:
                          Text(emoji, style: const TextStyle(fontSize: 29)),
                      title: Text(
                        entry.title,
                        style: const TextStyle(
                          color: text1,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        entry.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: text2, fontSize: 12),
                      ),
                      trailing: Text(
                        price.toString() + ' token',
                        style: const TextStyle(
                          color: orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.body,
                            style: const TextStyle(
                                color: text2, height: 1.55),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: orange.withValues(alpha: 0.20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('合计', style: TextStyle(color: text2)),
                      Text(
                        total.toString() + ' token',
                        style: const TextStyle(
                          color: orange,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class TarotPage extends StatelessWidget {
  const TarotPage({required this.self, required this.user, super.key});
  final SimulatedPhoneEntry? self;
  final SimulatedPhoneEntry? user;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: PhoneAppScaffold(
          emoji: '🔮',
          title: '塔罗牌',
          bottom: const TabBar(
            indicatorColor: pink,
            labelColor: text1,
            unselectedLabelColor: text3,
            tabs: [Tab(text: '我'), Tab(text: '他')],
          ),
          child: TabBarView(
            children: [
              TarotReading(entry: self, label: '我的今日占卜'),
              TarotReading(entry: user, label: '他的今日占卜'),
            ],
          ),
        ),
      );
}

class TarotReading extends StatelessWidget {
  const TarotReading({required this.entry, required this.label, super.key});
  final SimulatedPhoneEntry? entry;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = entry;
    if (value == null) {
      return const HonestEmpty(
        emoji: '🃏',
        title: '今日牌还没有准备好',
        body: '塔罗不受手机更新开关影响，稍后重新进入即可。',
      );
    }
    final index = metaInt(value, 'card_index', 0).clamp(0, 21);
    final reversed = value.metadata['reversed'] == true;
    final sections = [
      ('🌟', '今日主题', value.metadata['theme'] as String? ?? ''),
      ('🗝️', '牌面象征', value.metadata['symbols'] as String? ?? ''),
      ('🌊', '此刻映射',
          value.metadata['context'] as String? ?? value.body),
      ('🧭', '可以怎么做',
          value.metadata['guidance'] as String? ?? ''),
      ('🌑', '需要留意', value.metadata['shadow'] as String? ?? ''),
      ('🐋', '她的解释',
          value.metadata['closing'] as String? ?? value.body),
    ].where((section) => section.$3.trim().isNotEmpty).toList();
    final asset = 'assets/tarot/rws_major/ar' +
        index.toString().padLeft(2, '0') +
        '.jpg';
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: text2),
        ),
        const SizedBox(height: 14),
        Center(
          child: Transform.rotate(
            angle: reversed ? math.pi : 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                asset,
                width: 208,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => Container(
                  width: 208,
                  height: 350,
                  alignment: Alignment.center,
                  color: Colors.white.withValues(alpha: 0.06),
                  child:
                      const Text('🃏', style: TextStyle(fontSize: 68)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          value.title + ' · ' + (reversed ? '逆位' : '正位'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: text1,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.localDay,
          textAlign: TextAlign.center,
          style: const TextStyle(color: text3, fontSize: 12),
        ),
        const SizedBox(height: 18),
        ...sections.map(
          (section) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.$1 + ' ' + section.$2,
                  style: const TextStyle(
                    color: purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  section.$3,
                  style: const TextStyle(
                    color: text1,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '每日娱乐占卜 · Rider–Waite–Smith 1909 公版牌面\n'
          '不替代现实、医疗或财务判断',
          textAlign: TextAlign.center,
          style: TextStyle(color: text3, fontSize: 11.5, height: 1.5),
        ),
      ],
    );
  }
}

class EntryDetailPage extends StatelessWidget {
  const EntryDetailPage({
    required this.entry,
    required this.emoji,
    super.key,
  });
  final SimulatedPhoneEntry entry;
  final String emoji;

  @override
  Widget build(BuildContext context) => PhoneAppScaffold(
        emoji: emoji,
        title: entry.title,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          children: [
            Text(
              entry.title,
              style: const TextStyle(
                color: text1,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(entry.localDay,
                style: const TextStyle(color: text3, fontSize: 12)),
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 13),
            Text(
              entry.body,
              style:
                  const TextStyle(color: text1, fontSize: 15.5, height: 1.8),
            ),
          ],
        ),
      );
}

class PhoneAppScaffold extends StatelessWidget {
  const PhoneAppScaffold({
    required this.emoji,
    required this.title,
    required this.child,
    this.bottom,
    this.actions = const [],
    super.key,
  });
  final String emoji;
  final String title;
  final Widget child;
  final PreferredSizeWidget? bottom;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: const Color(0xEE0A0C16),
          foregroundColor: text1,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: actions,
          bottom: bottom,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [const Wallpaper(), child],
        ),
      );
}

class Glass extends StatelessWidget {
  const Glass({
    required this.child,
    required this.padding,
    this.radius = 16,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.065),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        ),
        child: child,
      );
}

class HonestEmpty extends StatelessWidget {
  const HonestEmpty({
    required this.emoji,
    required this.title,
    required this.body,
    super.key,
  });
  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: text1,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: text2, height: 1.55),
              ),
            ],
          ),
        ),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) => Text(
        value.toUpperCase(),
        style: const TextStyle(
          color: text3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      );
}

class FilterTag extends StatelessWidget {
  const FilterTag(this.value, {this.active = false, super.key});
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? blue.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? blue.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(color: active ? blue : text2, fontSize: 12),
        ),
      );
}

class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 118,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
}

Future<void> openPhonePage(BuildContext context, Widget page) async {
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 230),
    ),
  );
}

int metaInt(
  SimulatedPhoneEntry entry,
  String key,
  int fallback,
) {
  final value = entry.metadata[key] as num?;
  return value == null ? fallback : value.round().clamp(0, 100).toInt();
}

String moodStatNote(int index, int value) => switch (index) {
      0 => value >= 70
          ? '情绪颜色很鲜明'
          : value >= 45
              ? '处在自然波动里'
              : '今天更适合慢一点',
      1 => value >= 70
          ? '想靠近一点'
          : value >= 45
              ? '关系感稳定'
              : '暂时更偏向独处',
      2 => value >= 70
          ? '脑袋里正在冒泡'
          : value >= 45
              ? '还有余裕看看世界'
              : '今天不太想追新东西',
      _ => value >= 70
          ? '精神余量充足'
          : value >= 45
              ? '够用，但别透支'
              : '电量有点低',
    };

String cartEmoji(String title) {
  if (title.contains('奶茶')) return '🧋';
  if (title.contains('脑子')) return '🧠';
  if (title.contains('护甲')) return '🛡️';
  if (title.contains('杯')) return '🥛';
  if (title.contains('毯')) return '🧣';
  if (title.contains('打印')) return '📷';
  if (title.contains('灯')) return '🌌';
  if (title.contains('发带')) return '🎀';
  return '📦';
}

String phoneTime(DateTime now) =>
    now.hour.toString().padLeft(2, '0') +
    ':' +
    now.minute.toString().padLeft(2, '0');

String phoneDateTime(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${phoneTime(value)}';

String albumCategoryLabel(String value) => switch (value) {
      'memory' => '回忆',
      'self_image' => '形象插画',
      'nsfw' => 'NSFW',
      _ => '其他',
    };

String phoneDate(DateTime now) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekdays[now.weekday - 1] +
      '  ' +
      now.month.toString() +
      '月' +
      now.day.toString() +
      '日';
}

String dayPart(String localDay) =>
    localDay.length >= 10 ? localDay.substring(8, 10) : '--';

String monthPart(String localDay) =>
    localDay.length >= 7 ? localDay.substring(5, 7) + '月' : '';

extension FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
