import 'commission_thread.dart';
import '../creative/creative_contract.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Documents and task records live outside the companion conversation database.
class CommissionWorkspace {
  CommissionWorkspace({this.directory, this.tree});
  final Directory? directory;
  final String? tree;
  static const channel = MethodChannel('ai_companion/system');
  static final Set<String> writingTasks = {};
  static const maxBytes = 256 * 1024;
  static int limit(String name) => name.startsWith('会话-') ? 8 * 1024 * 1024 : maxBytes;
  static final _writes = <String, Future<void>>{};
  static final names = RegExp(
    r'^((?:会话|任务)-[a-f0-9-]{36}\.json|作品-[\u3400-\u9fffA-Za-z0-9 _（）-]{1,75}\.html|截图-[a-f0-9-]{36}\.png|(?:报告|技能|停用技能)-[\u3400-\u9fffA-Za-z0-9 _-]{1,75}\.md)$',
  );
  static void validate(String name) {
    if (!names.hasMatch(name)) throw const FormatException('无效工作文件名');
  }

  static Future<CommissionWorkspace> open() async {
    final tree = Platform.isAndroid
        ? await channel.invokeMethod<String>('workTreeCurrent')
        : null;
    if (tree != null) {
      final workspace = CommissionWorkspace(tree:tree);
      await workspace._recoverWrites();
      return workspace;
    }
    return CommissionWorkspace(
      directory: await Directory(
        '${(await getApplicationDocumentsDirectory()).path}/commission_workspace',
      ).create(recursive: true),
    );
  }

  bool sameLocation(CommissionWorkspace other) =>
      tree == other.tree && directory?.path == other.directory?.path;

  String get locationLabel {
    if (tree == 'workspace:downloads') return '下载 / 小鲸鱼工作区';
    if (tree == null) return 'App 内部工作区';
    final uri = Uri.tryParse(tree!);
    final parts = uri?.pathSegments;
    return parts == null || parts.isEmpty ? '自选手机文件夹' : parts.last;
  }

  static Future<bool> hasPrivateFiles() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/commission_workspace');
    if (!await dir.exists()) return false;
    return dir.list(followLinks: false).any(
      (entry) => entry is File && names.hasMatch(entry.uri.pathSegments.last),
    );
  }

  static Future<void> choose() => channel.invokeMethod<void>('workTreeChoose');
  static Future<void> useDefault({bool private = false}) =>
      channel.invokeMethod<void>('workTreeDefault', {'private': private});
  Future<List<String>> list() async {
    final values = directory == null
        ? await channel.invokeListMethod<String>('workTreeList', {
                'tree': tree,
              }) ??
              []
        : await directory!
              .list(followLinks: false)
              .where((e) => e is File)
              .map((e) => e.uri.pathSegments.last)
              .toList();
    return values.where(names.hasMatch).toList()..sort();
  }

  Future<String> read(String name) async {
    validate(name);
    if (directory == null)
      return (await channel.invokeMethod<String>('workTreeRead', {
        'tree': tree,
        'name': name,
      }))!;
    final file = File('${directory!.path}/$name');
    if (await file.length() > limit(name)) throw const FormatException('文件过大');
    return name.endsWith('.png') ? base64Encode(await file.readAsBytes()) : file.readAsString();
  }

  static final _signature = RegExp(r'^<!-- work-sha256:([a-f0-9]{64}) -->\n');
  Future<String> readHtml(String name, {String? expectedDigest}) async {
    if (!name.startsWith('作品-') || !name.endsWith('.html')) throw const FormatException('无效的作品文件');
    final raw = await read(name);
    final header = _signature.firstMatch(raw);
    final legacy = RegExp(r'^作品-([a-f0-9]{64})\.html$').firstMatch(name);
    final page = header == null ? raw : raw.substring(header.end);
    final digest = CreativeContract.hash(page);
    if ((header?.group(1) ?? legacy?.group(1)) != digest || expectedDigest != null && digest != expectedDigest) {
      throw const FormatException('作品文件内容已变化');
    }
    return page;
  }

  Future<String> savePage(String title, String page, Future<void> Function(String?)? checkpoint) async {
    final base = filename('作品', title).replaceFirst(RegExp(r'\.md$'), '');
    final digest = CreativeContract.hash(page);
    final encoded = '<!-- work-sha256:$digest -->\n$page';
    if (utf8.encode(encoded).length > maxBytes) throw const FormatException('文件过大');
    return _createHtml(base, encoded, checkpoint, digest:digest);
  }

  Future<String> importHtml(String name, String encoded) async {
    validate(name);
    final legacy = RegExp(r'^作品-([a-f0-9]{64})\.html$').firstMatch(name);
    // Legacy files use the filename as their signature. A renamed copy needs
    // an embedded signature to remain verifiable after export and re-import.
    final legacyDigest = legacy != null && CreativeContract.hash(encoded) == legacy[1] ? legacy[1] : null;
    return _createHtml(name.substring(0,name.length-5),encoded,null,legacyDigest:legacyDigest);
  }

  Future<String> _createHtml(String base,String original,Future<void> Function(String?)? checkpoint,
      {String? digest,String? legacyDigest}) async {
    final existing = (await list()).toSet();
    for (var i = 1; ; i++) {
      final suffix = i == 1 ? '' : '（$i）';
      final stem = base.substring(0,base.length.clamp(0,78-suffix.length));
      final name = '$stem$suffix.html';
      final encoded = i > 1 && legacyDigest != null ? '<!-- work-sha256:$legacyDigest -->\n$original' : original;
      if (utf8.encode(encoded).length > maxBytes) throw const FormatException('文件过大');
      validate(name);
      if (existing.contains(name)) {
        if (await read(name) == encoded) { await checkpoint?.call(name); return name; }
        continue;
      }
      await checkpoint?.call(name);
      if (directory == null) {
        final created = await channel.invokeMethod<bool>('workTreeCreate', {'tree':tree,'name':name,'text':encoded});
        if (created != true) { existing.add(name); continue; }
      } else {
        final file = File('${directory!.path}/$name');
        try { await file.create(exclusive:true); }
        on FileSystemException { if (!await file.exists()) rethrow; existing.add(name); continue; }
        try { await file.writeAsString(encoded, flush:true); } catch (_) { await file.delete(); rethrow; }
      }
      if (digest != null) await readHtml(name, expectedDigest:digest);
      return name;
    }
  }

  Future<void> saveMarkdown(String name, String content, {required String? expected}) =>
      _serialized(name, () async {
        final current = (await list()).contains(name) ? await read(name) : null;
        if (current != expected) throw const FormatException('文档已变化，请重新读取后修改');
        await _write(name, content);
        if (await read(name) != content) throw const FormatException('报告或技能写入后校验失败');
      });

  Future<void> write(String name, String content) => name.endsWith('.md')
      ? _serialized(name, () => _write(name, content))
      : _write(name, content);

  Future<void> _write(String name, String content) async {
    validate(name);
    final bytes = name.endsWith('.png') ? base64Decode(content) : utf8.encode(content);
    if (bytes.length > limit(name))
      throw const FormatException('文件过大');
    if (directory == null) {
      await channel.invokeMethod<void>('workTreeWrite', {
        'tree': tree,
        'name': name,
        'text': content,
      });
    } else {
      final path = '${directory!.path}/$name';
      final temp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
      try {
        await temp.writeAsBytes(bytes, flush: true);
        await temp.rename(path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
  }

  Future<void> openExternally(String name) async {
    validate(name);
    await channel.invokeMethod<void>('workTreeOpen', {'name': name, 'tree': tree});
  }

  Future<void> remove(String name) async {
    validate(name);
    if (writingTasks.contains(name)) throw StateError('请先停止正在执行的委托');
    if (directory == null) {
      await channel.invokeMethod<void>('workTreeDelete', {
        'tree': tree,
        'name': name,
      });
    } else {
      await File('${directory!.path}/$name').delete();
    }
  }

  static List<Map<String,dynamic>> decodeRecords(String name,String raw) {
    final data=jsonDecode(raw);
    if(data is! Map<String,dynamic>) throw const FormatException('无效工作记录');
    if(name.startsWith('任务-')){
      final id=data['id'] ?? name.substring(3,name.length-5);
      if('任务-$id.json'!=name || data['goal'] is! String) throw const FormatException('无效任务记录');
      return [{...data,'id':id}];
    }
    final thread=data['threadId'];
    final turns=data['turns'];
    if(data['version']!=1 || '会话-$thread.json'!=name || turns is! List || turns.isEmpty) {
      throw const FormatException('无法读取这份工作会话');
    }
    final seen=<String>{};
    return turns.map((r){
      if(r is! Map<String,dynamic> || r['id'] is! String || !names.hasMatch("任务-${r['id']}.json") ||
          r['goal'] is! String || CommissionThread.key(r)!=thread || !seen.add(r['id'] as String)){
        throw const FormatException('无效会话轮次');
      }
      return r;
    }).toList();
  }

  Future<void> _serialized(String name,Future<void> Function() action) async {
    final key='${directory?.path ?? tree}/$name';
    final prior=_writes[key];
    final next=(prior ?? Future<void>.value()).then((_)=>action(),onError:(Object _,StackTrace __)=>action());
    _writes[key]=next;
    try {await next;} finally {if(identical(_writes[key],next)) _writes.remove(key);}
  }

  Future<Directory> _journal() async {
    final path=(await getApplicationSupportDirectory()).path;
    return Directory('$path/work_write_recovery/${sha256.convert(utf8.encode(tree!))}');
  }

  Future<void> _recoverWrites() async {
    final dir=await _journal();
    if(!await dir.exists())return;
    await for(final f in dir.list()){
      final name=f.uri.pathSegments.last;
      if(f is! File || !name.startsWith('会话-') || !names.hasMatch(name))continue;
      await _serialized(name,() async {
        if(!await f.exists())return;
        final raw=await f.readAsString();
        decodeRecords(name,raw);
        await write(name,raw);
        await f.delete();
      });
    }
  }

  Future<void> mergeTurns(String name,Iterable<Map<String,dynamic>> incoming,{bool keepExisting=false}) =>
      _serialized(name,() async {
        final thread=name.substring(3,name.length-5);
        final byId=<String,Map<String,dynamic>>{};
        final journal=tree==null ? null : await _journal();
        final pending=journal==null ? null : File('${journal.path}/$name');
        final fromJournal=pending!=null && await pending.exists();
        if(fromJournal || (await list()).contains(name)){
          final original=fromJournal ? await pending.readAsString() : await read(name);
          for(final row in decodeRecords(name,original)){byId[row['id'] as String]=row;}
        }
        for(final row in incoming){
          final id=row['id'] as String;
          if(CommissionThread.key(row)!=thread) throw const FormatException('会话编号不一致');
          if(!keepExisting || !byId.containsKey(id)) byId[id]=row;
        }
        final turns=byId.values.toList()..sort((a,b)=>(a['id'] as String).compareTo(b['id'] as String));
        final raw=jsonEncode({'version':1,'threadId':thread,'turns':turns});
        if(utf8.encode(raw).length>limit(name)) throw const FormatException('会话文件已达 8 MiB，请新开工作窗口');
        if(journal!=null && pending!=null){
          await journal.create(recursive:true);
          final temp=File('${pending.path}.tmp');
          await temp.writeAsString(raw,flush:true);
          await temp.rename(pending.path);
        }
        await write(name,raw);
        await pending?.delete();
      });

  Future<Map<String, List<Map<String, dynamic>>>> conversations() async {
    final threads=<String,Map<String,Map<String,dynamic>>>{};
    final files=await list();
    for(final name in [...files.where((s)=>s.startsWith('任务-')),...files.where((s)=>s.startsWith('会话-'))]){
      try {
        for(final row in decodeRecords(name,await read(name))){
          (threads[CommissionThread.key(row)]??={})[row['id'] as String]=row;
        }
      } on FormatException {continue;}
    }
    return threads.map((k,v)=>MapEntry(k,v.values.toList()..sort((a,b)=>(a['id'] as String).compareTo(b['id'] as String))));
  }

  Future<List<Map<String,dynamic>>> conversation(String name) async {
    validate(name);
    final threads=await conversations();
    for(final e in threads.entries){
      if('会话-${e.key}.json'==name || e.value.any((r)=>"任务-${r['id']}.json"==name))return e.value;
    }
    throw const FormatException('工作记录已删除或无法读取');
  }

  Future<List<Map<String, dynamic>>> recent({DateTime? now}) async {
    final cutoff=(now ?? DateTime.now()).subtract(const Duration(hours:48)).millisecondsSinceEpoch;
    final rows=(await conversations()).values.expand((g)=>g)
        .where((r)=>r['state']=='completed' && r['at'] is int && r['at']>=cutoff).toList();
    rows.sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    return rows.take(3).toList();
  }

  static String filename(String kind, String title) {
    var safe = title
        .replaceAll(RegExp(r'[^\u3400-\u9fffA-Za-z0-9 _-]'), ' ')
        .trim();
    if (safe.isEmpty) safe = '未命名';
    return '$kind-${String.fromCharCodes(safe.runes.take(64))}.md';
  }
}
