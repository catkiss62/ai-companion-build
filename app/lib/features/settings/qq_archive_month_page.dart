import 'dart:convert';
import 'package:flutter/services.dart';
import '../../integrations/qq_private/qq_work_queue.dart';
import '../../integrations/qq_private/qq_sketch.dart';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../integrations/qq_private/qq_archive_admin.dart';
import '../../integrations/qq_private/qq_archive_reader.dart';
import '../../integrations/qq_private/qq_display_names.dart';

class QqArchiveConversationPage extends StatefulWidget {
  const QqArchiveConversationPage({super.key, required this.conversation, required this.title, required this.names});
  final Map<String, Object?> conversation;
  final String title;
  final QqDisplayNames names;
  @override State<QqArchiveConversationPage> createState() => _QqArchiveConversationPageState();
}

class _QqArchiveConversationPageState extends State<QqArchiveConversationPage> {
  List<QqArchiveMonth>? _months;
  String _notice = '';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final rows = await QqArchiveAdmin(AppDatabase.instance).months(widget.conversation['id'] as String);
      if (mounted) setState(() { _months = rows; _notice = ''; });
    } catch (_) { if (mounted) setState(() => _notice = '档案读取失败，请重试。'); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _months == null ? Center(child: _notice.isEmpty ? const CircularProgressIndicator() : Text(_notice)) : ListView(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('按自然月整理。本月和上个月保留为近期资料；历史月份仍可按需查询。跨月不清空聊天，不自动删除。\n原文、整理记忆和修改状态随App存档保存。')),
      ListTile(leading:const Icon(Icons.replay),title:const Text('重试失败的记忆整理'),subtitle:const Text('只重试本会话已登记、三次失败的任务，不重新读取已整理或已删除的旧资料。'),onTap:() async {
        try {final count=await QqWorkQueue.retrySummary(AppDatabase.instance,widget.conversation['id'] as String);
          try {await const MethodChannel('ai_companion/qq_private_control').invokeMethod<void>('wakeWork',{'cid':widget.conversation['id']});}catch(_) {}
          if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(count==0?'没有可重试的任务。':'已登记$count项，QQ连接开启后执行。')));
        }catch(_) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('请先开启自动记忆，再重试。')));}
      }),
      for (final month in _months!) ListTile(
        title: Text(month.label), subtitle: Text('${month.messages} 条原文 · ${month.recentAt(DateTime.now()) ? '近期资料' : '历史档案 · 仍可查询'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => QqArchiveMonthPage(
            conversation: widget.conversation, title: widget.title, names: widget.names, month: month)));
          if (mounted) await _load();
        }),
      if (_months!.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('这份档案暂时没有记录。')),
    ]));
}

class QqArchiveMonthPage extends StatefulWidget {
  const QqArchiveMonthPage({super.key, required this.conversation, required this.title, required this.names, required this.month});
  final Map<String, Object?> conversation;
  final String title;
  final QqDisplayNames names;
  final QqArchiveMonth month;
  @override State<QqArchiveMonthPage> createState() => _QqArchiveMonthPageState();
}

class _QqArchiveMonthPageState extends State<QqArchiveMonthPage> {
  final _messages = <Map<String, Object?>>[], _notes = <Map<String, Object?>>[];
  final _texts = <String, String>{};
  final _sketches=<int,Map<String,Object?>>{};
  bool _loading = true, _busy = false, _moreMessages = false, _moreNotes = false;
  String _notice = '';
  String get cid => widget.conversation['id'] as String;
  QqArchiveAdmin get admin => QqArchiveAdmin(AppDatabase.instance);
  @override void initState() { super.initState(); _load(reset: true); }
  String speaker(Map<String, Object?> row) => row['role'] == 'assistant' ? '小鲸鱼' : row['owner'] == 1 ? '你' :
    widget.names.member(widget.conversation['target'] as String, row['sender'] as String) ?? '群成员';
  Future<void> _load({bool reset = false, bool notesOnly = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _notice = ''; });
    try {
      final messages = notesOnly ? <Map<String, Object?>>[] : await admin.messages(cid, widget.month,
        before: reset || _messages.isEmpty ? null : _messages.last['seq'] as int);
      final notes = reset || notesOnly ? await admin.notes(cid, widget.month, offset: reset ? 0 : _notes.length) : null;
      final reader = QqArchiveReader(await AppDatabase.instance.database);
      final texts = <String, String>{};
      for (final row in messages) { texts[row['id'] as String] = await reader.display(row, speaker: speaker(row)); }
      final sketches=messages.isEmpty?<Map<String,Object?>>[]:await (await AppDatabase.instance.database).query('qq_sketches',where:'archive_seq IN (${List.filled(messages.length,'?').join(',')})',whereArgs:[for(final r in messages)r['seq']]);
      if (!mounted) return;
      setState(() {
        if(reset)_sketches.clear();
        for(final sketch in sketches)_sketches[sketch['archive_seq'] as int]=sketch;
        if (reset) { _messages.clear(); _notes.clear(); _texts.clear(); }
        _messages.addAll(messages); _texts.addAll(texts);
        if (!notesOnly) _moreMessages = messages.length == 50;
        if (notes != null) { _notes.addAll(notes); _moreNotes = notes.length == 30; }
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() { _notice = '读取失败，请刷新重试。'; _loading = false; }); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _preview(Map<String,Object?> sketch) async {
    try {final png=await QqSketchService.preview(sketch['svg'] as String);if(png==null || !mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('小涂鸦 · 本机重绘预览'),content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Image.memory(png),Text(sketch['description'] as String),ExpansionTile(title:const Text('SVG源文件'),children:[SelectableText(sketch['svg'] as String)])]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('关闭'))]));
    }catch(_) {if(mounted)setState(()=>_notice='这张涂鸦暂时无法预览，文字描述仍保留。');}
  }
  Future<bool> _confirm(String title, String text) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title), content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认'))])) ?? false;

  Future<void> _edit(Map<String, Object?> note) async {
    final text = await showDialog<String>(context: context, builder: (_) => _QqNoteEditor(initial:note['content'] as String));
    if (text == null || !mounted) return;
    await _mutate(() => admin.editNote(note, text));
  }

  Future<void> _deleteNote(Map<String, Object?> note) async {
    if (!await _confirm('删除这条整理记忆？', '停止使用这条笔记及其待发分享，不自动重建同一条笔记。原文仍可查询。App私人记忆和已有备份不受影响。') || !mounted) return;
    await _mutate(() => admin.deleteNote(note));
  }

  Future<void> _sources(Map<String, Object?> note) async {
    try {
      final ids = (jsonDecode(note['sources'] as String) as List).cast<int>();
      final sql = await AppDatabase.instance.database;
      final rows = ids.isEmpty ? <Map<String, Object?>>[] : await sql.query('qq_archive',
        where: 'conversation_id=? AND seq IN (${List.filled(ids.length, '?').join(',')})', whereArgs: [cid, ...ids], orderBy: 'seq');
      final reader = QqArchiveReader(sql);
      final texts = <String>[];
      for (final row in rows) { texts.add(await reader.display(row, speaker: speaker(row))); }
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('整理记忆的原文来源'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: SelectableText(texts.isEmpty ? '来源已不可用。' : texts.join('\n\n')))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))]));
    } catch (_) { if (mounted) setState(() => _notice = '来源读取失败。'); }
  }

  Future<void> _deleteRange({bool selectDates = false}) async {
    var start = widget.month.start, end = widget.month.end;
    if (selectDates) {
      final range = await showDateRangePicker(context: context, firstDate: start, lastDate: DateTime(end.year, end.month, 0),
        initialDateRange: DateTimeRange(start: start, end: DateTime(end.year, end.month, 0)));
      if (range == null || !mounted) return;
      start = DateTime(range.start.year, range.start.month, range.start.day);
      end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    }
    final sql = await AppDatabase.instance.database;
    final c = (await sql.query('qq_conversations', where: 'id=?', whereArgs: [cid], limit: 1)).firstOrNull;
    final selected = await sql.rawQuery('SELECT COUNT(*) AS count,MAX(seq) AS through FROM qq_archive WHERE conversation_id=? AND observed_at>=? AND observed_at<?',
      [cid, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
    if (!mounted || c == null) return;
    final count = selected.single['count'] as int;
    if (count == 0) { setState(() => _notice = '选定日期没有原文。'); return; }
    if (!await _confirm('删除${selectDates ? '所选日期' : widget.month.label}的档案？',
      '删除这次选中的 $count 条原文、图片描述和相关整理记忆/分享记录。\n跨月笔记会先撤下，保留日期的原文仍在，下次QQ整理时据此重建。\nApp私人聊天、独立记忆和已有备份不删除。确认之后新收到的消息不在本次范围内。') || !mounted) return;
    await _mutate(() async {
      await admin.deleteRange(cid, start, end, expectedVersion: c['version'] as int, throughSeq: selected.single['through'] as int);
    });
  }

  Future<void> _mutate(Future<void> Function() change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await change(); }
    catch (_) { if (mounted) setState(() => _notice = '资料已变化或暂时不能修改，请刷新后重试。'); return; }
    finally { if (mounted) setState(() => _busy = false); }
    if (mounted) await _load(reset: true);
  }

  @override Widget build(BuildContext context) => DefaultTabController(length: 2, child: Scaffold(
    appBar: AppBar(title: Text('${widget.title} · ${widget.month.label}'), bottom: const TabBar(tabs: [Tab(text: '原文'), Tab(text: '整理记忆')]),
      actions: [IconButton(onPressed: _busy ? null : () => _load(reset: true), icon: const Icon(Icons.refresh)),
        PopupMenuButton<String>(enabled: !_busy, onSelected: (value) => _deleteRange(selectDates: value == 'dates'), itemBuilder: (_) => const [
          PopupMenuItem(value: 'dates', child: Text('按日期删除')), PopupMenuItem(value: 'month', child: Text('删除整月原文和整理记忆'))])]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
      if (_notice.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_notice)),
      if (_busy) const LinearProgressIndicator(),
      Expanded(child: TabBarView(children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          const Text('每次加载50条，图片仅保留文字观察。月份不限制她按需查阅历史。'),
          for (final row in _messages) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SelectableText(_texts[row['id']] ?? ''),if(_sketches.containsKey(row['seq']))TextButton(onPressed:()=>_preview(_sketches[row['seq']]!),child:const Text('查看小涂鸦'))])),
          if (_messages.isEmpty) const Text('本月没有原文。'),
          if (_moreMessages) TextButton(onPressed: _busy ? null : () => _load(), child: const Text('加载更早原文'))]),
        ListView(padding: const EdgeInsets.all(16), children: [
          const Text('可修改或删除单条整理记忆；删除笔记后原文仍可查询。'),
          for (final note in _notes) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note['valid'] == 0 ? '保留原文待重新整理' : (note['edited_at'] as int) > 0 ? '你修改的整理记忆' : '自动整理记忆'),
            const SizedBox(height: 8), SelectableText(note['valid'] == 0 ? '跨日期笔记已撤下，保留范围将依据原文重建。' : note['content'] as String),
            Wrap(children: [TextButton(onPressed: _busy ? null : () => _sources(note), child: const Text('查看来源')),
              if (note['valid'] == 1) TextButton(onPressed: _busy ? null : () => _edit(note), child: const Text('编辑')),
              TextButton(onPressed: _busy ? null : () => _deleteNote(note), child: const Text('删除'))])]))),
          if (_notes.isEmpty) const Text('本月没有整理记忆。'),
          if (_moreNotes) TextButton(onPressed: _busy ? null : () => _load(notesOnly: true), child: const Text('加载更多整理记忆'))]),
      ])),
    ])));
}

class _QqNoteEditor extends StatefulWidget {
  const _QqNoteEditor({required this.initial});
  final String initial;
  @override State<_QqNoteEditor> createState()=>_QqNoteEditorState();
}
class _QqNoteEditorState extends State<_QqNoteEditor> {
  late final controller=TextEditingController(text:widget.initial);
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('编辑整理记忆'),
    content:SizedBox(width:480,child:TextField(controller:controller,minLines:4,maxLines:12,maxLength:6000)),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('取消')),
      FilledButton(onPressed:(){if(controller.text.trim().isNotEmpty)Navigator.pop(context,controller.text.trim());},child:const Text('保存'))]);
}
