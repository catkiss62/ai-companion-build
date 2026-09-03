import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/personality_trial.dart';
import '../../core/personality/personality_catalog.dart';

class PersonalityLabPage extends StatefulWidget {
  const PersonalityLabPage({super.key});

  @override
  State<PersonalityLabPage> createState() => _PersonalityLabPageState();
}

class _PersonalityLabPageState extends State<PersonalityLabPage> {
  final db = AppDatabase.instance;
  String baseKey = PersonalityCatalog.noneKey;
  String postureKey = PersonalityCatalog.noneKey;
  String specialKey = PersonalityCatalog.specialStyles.first.key;
  Duration profileDuration = const Duration(days: 1);
  Duration specialDuration = const Duration(hours: 1);
  PersonalityTrial? profile;
  SpecialStyleTrial? special;
  Timer? timer;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (DateTime.now().second == 0) _refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final nextProfile = await db.activePersonalityTrial();
    final nextSpecial = await db.activeSpecialStyleTrial();
    if (!mounted) return;
    setState(() {
      profile = nextProfile;
      special = nextSpecial;
      if (nextProfile != null) {
        baseKey = nextProfile.baseKey;
        postureKey = nextProfile.postureKey;
      } else {
        baseKey = PersonalityCatalog.noneKey;
        postureKey = PersonalityCatalog.noneKey;
      }
      if (nextSpecial != null) specialKey = nextSpecial.styleKey;
    });
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _remaining(Duration value) {
    if (value.isNegative) return '已结束';
    if (value.inDays > 0) {
      return '${value.inDays}天 ${value.inHours.remainder(24)}小时';
    }
    if (value.inHours > 0) {
      return '${value.inHours}小时 ${value.inMinutes.remainder(60)}分';
    }
    return '${value.inMinutes}分 ${value.inSeconds.remainder(60)}秒';
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final s = special;
    return Scaffold(
      appBar: AppBar(title: const Text('性格试穿间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '默认不穿任何性格与相处姿态。这里的选项只用于试穿，不会新建记忆世界线，也不会抹掉她知道自己是 AI 这件事。',
          ),
          const SizedBox(height: 18),
          Text('性格底色', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...PersonalityCatalog.bases.map((item) => RadioListTile<String>(
                value: item.key,
                groupValue: baseKey,
                title: Text(item.label),
                subtitle: Text(item.description),
                onChanged: busy ? null : (value) => setState(() => baseKey = value!),
              )),
          if (baseKey == PersonalityCatalog.noneKey)
            const ListTile(
              leading: Icon(Icons.checkroom_outlined),
              title: Text('当前不穿性格底色'),
              dense: true,
            ),
          const SizedBox(height: 8),
          Text('相处姿态', style: Theme.of(context).textTheme.titleLarge),
          ...PersonalityCatalog.postures.map((item) => RadioListTile<String>(
                value: item.key,
                groupValue: postureKey,
                title: Text(item.label),
                subtitle: Text(item.description),
                onChanged: busy ? null : (value) => setState(() => postureKey = value!),
              )),
          if (postureKey == PersonalityCatalog.noneKey)
            const ListTile(
              leading: Icon(Icons.checkroom_outlined),
              title: Text('当前不穿相处姿态（“平等恋人”不再默认选择）'),
              dense: true,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(
                        db.restoreNaturalPersonality,
                        '已脱下性格与相处姿态。',
                      ),
              icon: const Icon(Icons.layers_clear_outlined),
              label: const Text('全部不穿'),
            ),
          ),
          const SizedBox(height: 8),
          _durationPicker(
            label: '试穿时长',
            value: profileDuration,
            choices: const [
              Duration(hours: 6),
              Duration(days: 1),
              Duration(days: 3),
              Duration(days: 7),
            ],
            onChanged: (value) => setState(() => profileDuration = value),
          ),
          FilledButton.icon(
            onPressed: busy ||
                    (baseKey == PersonalityCatalog.noneKey &&
                        postureKey == PersonalityCatalog.noneKey)
                ? null
                : () => _run(
                      () async {
                        await db.startPersonalityTrial(
                          baseKey: baseKey,
                          postureKey: postureKey,
                          duration: profileDuration,
                        );
                      },
                      p == null ? '开始试穿。' : '已更换试穿，计时和体验进度重新开始。',
                    ),
            icon: const Icon(Icons.checkroom_outlined),
            label: Text(p == null ? '开始试穿' : '换成这套（重新计时）'),
          ),
          if (p != null) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (p.baseKey != PersonalityCatalog.noneKey)
                          PersonalityCatalog.base(p.baseKey).label,
                        if (p.postureKey != PersonalityCatalog.noneKey)
                          PersonalityCatalog.posture(p.postureKey).label,
                      ].join(' × '),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('剩余 ${_remaining(p.remaining())}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _run(
                                    () => db.extendPersonalityTrial(p.id, const Duration(days: 1)),
                                    '试穿已延长 24 小时，原计时与进度保留。',
                                  ),
                          child: const Text('延长24小时'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _run(() => db.endPersonalityTrial(p.id), '已结束试穿，恢复长期性格。'),
                          child: const Text('结束试穿'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 36),
          Text('特殊风格（只试穿，不转正）', style: Theme.of(context).textTheme.titleLarge),
          const Text('特殊层会叠加在当前性格与相处试穿上；没有普通试穿时，就只穿这一层。'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: specialKey,
            items: PersonalityCatalog.specialStyles
                .map((item) => DropdownMenuItem(value: item.key, child: Text(item.label)))
                .toList(),
            onChanged: busy ? null : (value) => setState(() => specialKey = value!),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '特殊风格'),
          ),
          const SizedBox(height: 8),
          Text(PersonalityCatalog.special(specialKey).description),
          const SizedBox(height: 8),
          _durationPicker(
            label: '特殊试穿时长',
            value: specialDuration,
            choices: const [
              Duration(minutes: 30),
              Duration(hours: 1),
              Duration(hours: 3),
              Duration(hours: 12),
            ],
            onChanged: (value) => setState(() => specialDuration = value),
          ),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => _run(() async {
                      await db.startSpecialStyleTrial(
                        styleKey: specialKey,
                        duration: specialDuration,
                      );
                    }, s == null ? '特殊风格已开启。' : '已更换特殊风格，并重新计时。'),
            icon: const Icon(Icons.auto_awesome),
            label: Text(s == null ? '开启特殊试穿' : '换一种（重新计时）'),
          ),
          if (s != null) ...[
            const SizedBox(height: 8),
            Text('${PersonalityCatalog.special(s.styleKey).label} · 剩余 ${_remaining(s.remaining())}'),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(
                            () => db.extendSpecialStyleTrial(s.id, const Duration(hours: 1)),
                            '特殊试穿已延长 1 小时。',
                          ),
                  child: const Text('延长1小时'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(() => db.endSpecialStyleTrial(s.id), '已结束特殊风格。'),
                  child: const Text('立即结束'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _durationPicker({
    required String label,
    required Duration value,
    required List<Duration> choices,
    required ValueChanged<Duration> onChanged,
  }) {
    String text(Duration duration) {
      if (duration.inDays > 0) return '${duration.inDays}天';
      if (duration.inHours > 0) return '${duration.inHours}小时';
      return '${duration.inMinutes}分钟';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text('$label：'),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<Duration>(
              value: value,
              isExpanded: true,
              items: choices
                  .map((duration) => DropdownMenuItem(value: duration, child: Text(text(duration))))
                  .toList(),
              onChanged: busy ? null : (next) => onChanged(next!),
            ),
          ),
        ],
      ),
    );
  }
}
