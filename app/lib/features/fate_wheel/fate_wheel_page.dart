import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/fate_wheel/fate_wheel_catalog.dart';
import '../../core/platform/android_bridge.dart';

const _gold = Color(0xFFE9BA70);
const _ruby = Color(0xFFAC253B);
const _ink = Color(0xFF150E17);
const _originalUrl = 'https://github.com/29-Cu/Ruota-della-Fortuna';

/// An offline native rendering of the original seven-reel fantasy machine.
/// It only returns a proposal; the caller creates a room after confirmation.
class FateWheelPage extends StatefulWidget {
  const FateWheelPage({super.key});

  @override
  State<FateWheelPage> createState() => _FateWheelPageState();
}

class _FateWheelPageState extends State<FateWheelPage> {
  final _random = Random();
  final _enabled = <String>{};
  final _values = <String, FateWheelTag>{};
  List<FateWheelDimension>? _dimensions;
  Timer? _spinTimer;
  bool _spinning = false;
  bool _lit = true;
  Timer? _lightTimer;

  @override
  void initState() {
    super.initState();
    _lightTimer = Timer.periodic(const Duration(milliseconds: 580), (_) {
      if (mounted) setState(() => _lit = !_lit);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final dimensions = await FateWheelCatalog.load();
    if (!mounted) return;
    setState(() {
      _dimensions = dimensions;
      _enabled.addAll(dimensions.where((d) => !d.gore).map((d) => d.id));
    });
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _lightTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggle(FateWheelDimension dimension) async {
    if (_spinning) return;
    if (dimension.gore && !_enabled.contains(dimension.id)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('解锁 GORE 轮？'),
          content: const Text('这一轮包含血腥与暴力的虚构标签，默认锁定。只在你明确希望抽取这类设定时开启。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保持锁定'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('解锁'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      if (!_enabled.add(dimension.id)) {
        _enabled.remove(dimension.id);
        _values.remove(dimension.id);
      }
    });
  }

  void _spin({FateWheelDimension? only}) {
    if (_spinning || _dimensions == null) return;
    final selected = _dimensions!
        .where((dimension) => _enabled.contains(dimension.id))
        .where((dimension) => only == null || dimension.id == only.id)
        .toList(growable: false);
    if (selected.isEmpty) return;
    _spinTimer?.cancel();
    setState(() => _spinning = true);
    var tick = 0;
    _spinTimer = Timer.periodic(const Duration(milliseconds: 78), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        for (var index = 0; index < selected.length; index++) {
          if (tick <= 13 + index * 2) {
            final dimension = selected[index];
            _values[dimension.id] = FateWheelResult.draw(dimension, _random);
          }
        }
        if (tick >= 14 + (selected.length - 1) * 2) {
          timer.cancel();
          _spinTimer = null;
          _spinning = false;
        }
      });
      tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _dimensions;
    final ready = dimensions != null && !_spinning && _enabled.isNotEmpty &&
        _enabled.every(_values.containsKey);
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _ink,
        colorScheme: const ColorScheme.dark(primary: _gold, secondary: _ruby),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('命运之轮'),
          backgroundColor: const Color(0xFF190D17),
        ),
        body: dimensions == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    children: [
                      _cabinet(dimensions),
                      const SizedBox(height: 20),
                      const Text('选择轮子', style: TextStyle(color: _gold, fontSize: 18)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final dimension in dimensions)
                            FilterChip(
                              label: Text('${dimension.label} · ${dimension.tags.length}'),
                              avatar: dimension.gore
                                  ? const Icon(Icons.lock_outline, size: 17)
                                  : null,
                              selected: _enabled.contains(dimension.id),
                              selectedColor: const Color(0xFF693243),
                              onSelected: (_) => _toggle(dimension),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_values.isNotEmpty) ...[
                        const Text('本次抽签',
                            style: TextStyle(color: _gold, fontSize: 18)),
                        const SizedBox(height: 8),
                        for (final dimension in dimensions)
                          if (_enabled.contains(dimension.id) &&
                              _values.containsKey(dimension.id))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '${dimension.label}  ·  ${_values[dimension.id]!.zh.isNotEmpty ? _values[dimension.id]!.zh : _values[dimension.id]!.en}',
                                style: const TextStyle(color: Color(0xFFF5D8B2)),
                              ),
                            ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton.icon(
                        onPressed: ready
                            ? () => Navigator.of(context).pop(
                                  FateWheelResult({
                                    for (final id in _enabled) id: _values[id]!,
                                  }),
                                )
                            : null,
                        icon: const Icon(Icons.auto_stories_rounded),
                        label: const Text('确认结果，创建沉浸房间'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: _ruby,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '这是虚构场景的随机素材。抽签不会替你说话或决定你的行动；进入房间后仍以你当下的表达为准。',
                        style: TextStyle(color: Color(0xFFBDA5AA), height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => AndroidBridge.instance
                            .openExternalHttpsUrl(_originalUrl),
                        child: const Text(
                          'Based on Ruota della Fortuna by Copper (29-Cu) ↗',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _gold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _cabinet(List<FateWheelDimension> dimensions) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B2743), Color(0xFF290D20), Color(0xFF431B30)],
        ),
        border: Border.all(color: _gold, width: 3),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x887C304A), blurRadius: 30)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _bulbs(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text('✦  RUOTA DELLA FORTUNA  ✦',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _gold, fontSize: 17,
                        letterSpacing: 2, fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: _gold, blurRadius: 16)])),
                SizedBox(height: 5),
                Text('命  运  之  轮',
                    style: TextStyle(color: Color(0xFFFFE7BA), letterSpacing: 8)),
              ],
            ),
          ),
          Container(
            height: 194,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF110C13),
              border: Border.all(color: const Color(0xFFB48157), width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black87,
                  blurRadius: 14, spreadRadius: 3, blurStyle: BlurStyle.inner)],
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              itemCount: dimensions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) => _reel(dimensions[index]),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    _spinning ? '✦  命运正在转动…' : '✦  为幻想设定抽签',
                    style: const TextStyle(color: _gold),
                  ),
                ),
              ),
              GestureDetector(
                onVerticalDragEnd: (_) => _spin(),
                child: InkWell(
                  onTap: () => _spin(),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 92,
                    height: 110,
                    margin: const EdgeInsets.only(right: 18, bottom: 8),
                    child: Column(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _ruby, shape: BoxShape.circle,
                          border: Border.all(color: _gold, width: 3),
                          boxShadow: const [BoxShadow(color: _ruby, blurRadius: 18)],
                        )),
                      Container(width: 7, height: 38, color: _gold),
                      const Text('拉动 / 旋转',
                          style: TextStyle(color: _gold, fontSize: 11)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          _bulbs(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _bulbs() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(14, (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (_lit == index.isEven) ? _gold : const Color(0xFF765064),
            boxShadow: (_lit == index.isEven)
                ? const [BoxShadow(color: _gold, blurRadius: 9)] : const [],
          ),
        )),
      );

  Widget _reel(FateWheelDimension dimension) {
    final active = _enabled.contains(dimension.id);
    final tag = _values[dimension.id];
    return SizedBox(
      width: 112,
      child: InkWell(
        onLongPress: active && !_spinning ? () => _spin(only: dimension) : null,
        onTap: active && !_spinning && tag != null
            ? () => _spin(only: dimension)
            : () => _toggle(dimension),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? const [Color(0xFF382B3A), Color(0xFFFFECD5),
                      Color(0xFFFAE8C6), Color(0xFF382B3A)]
                  : const [Color(0xFF271C2B), Color(0xFF382933)],
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: active ? _gold : const Color(0xFF624454)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(dimension.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? const Color(0xFF301B22) : _gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
            ),
            const Divider(height: 2, color: _ruby, thickness: 2),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 65),
                  child: Text(
                    active
                        ? (tag == null ? '✦' :
                            (tag.zh.isNotEmpty ? tag.zh : tag.en))
                        : (dimension.gore ? '🔒' : '—'),
                    key: ValueKey('$active:${tag?.zh}:${tag?.en}'),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? const Color(0xFF561D30) : _gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
            Text(active ? '点按重抽' : '点击开启',
                style: TextStyle(fontSize: 10,
                    color: active ? const Color(0xFF5E3743) : _gold)),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }
}
