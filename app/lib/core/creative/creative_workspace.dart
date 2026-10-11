import 'dart:convert';
import 'creative_contract.dart';

/// A small durable project, not a second personality or a second API account.
/// Tool writes and their receipts are committed together by CreativeWorker.
class CreativeWorkspace {
  static const prefix = 'creative_agent_v1:';
  static const paths = {'index.html', 'style.css', 'script.js'};
  static const chunkLimit = 16000;
  static const maxStateBytes = 3000000;
  static String key(String id) => '$prefix$id';

  static Map<String, dynamic> create(String id, String requestId,
      {String html = ''}) => {
    'schema': 1, 'id': id, 'request_id': requestId,
    'files': <String, String>{if (html.isNotEmpty) 'index.html': html},
    'history': <Object?>[], 'pending': <Object?>[], 'next_tool': 0,
    'plan': <String, Object?>{}, 'verification': <String, Object?>{},
    'feedback': <Object?>[], 'failures': 0, 'next_at': 0,
  };

  static Map<String, String> files(Map<String, dynamic> state) =>
      Map<String, String>.from(state['files'] as Map? ?? {});

  static void validate(Map<String, dynamic> state, String id) {
    if (state['schema'] != 1 || state['id'] != id ||
        state['request_id'] is! String || state['files'] is! Map ||
        state['history'] is! List || state['pending'] is! List ||
        state['next_tool'] is! int ||
        (state['next_tool'] as int) < 0 ||
        (state['next_tool'] as int) > (state['pending'] as List).length) {
      throw const FormatException('工作检查点损坏');
    }
    var size = 0;
    for (final entry in (state['files'] as Map).entries) {
      if (!paths.contains(entry.key) || entry.value is! String) {
        throw const FormatException('工作文件无效');
      }
      size += utf8.encode(entry.value as String).length;
    }
    if (size > CreativeContract.maxHtmlBytes ||
        utf8.encode(jsonEncode(state)).length > maxStateBytes ||
        (state['pending'] as List).length > 8) {
      throw const FormatException('工作检查点超过容量');
    }
    for (final raw in state['pending'] as List) {
      if (raw is! Map || raw['id'] is! String ||
          raw['name'] is! String || raw['arguments'] is! String) {
        throw const FormatException('工作工具记录损坏');
      }
    }
  }

  static List<Map<String, Object?>> manifest(Map<String, dynamic> state) =>
      files(state).entries.map((e) => <String, Object?>{
        'path': e.key, 'characters': e.value.length,
        'hash': CreativeContract.hash(e.value),
      }).toList();

  static String assemble(Map<String, dynamic> state) {
    final project = files(state);
    var html = project['index.html'] ?? '';
    if (html.trim().isEmpty) throw const FormatException('请先写入 index.html');
    // Only these two known local assets are bundled. Other URLs remain blocked
    // by the renderer's CSP, rather than gaining arbitrary filesystem access.
    html = html.replaceAll(RegExp(r'''<link\b[^>]*href=["'](?:\./)?style\.css["'][^>]*>''', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'''<script\b[^>]*src=["'](?:\./)?script\.js["'][^>]*>\s*</script\s*>''', caseSensitive: false), '');
    final css = project['style.css'] ?? '';
    final js = project['script.js'] ?? '';
    if (css.isNotEmpty) {
      if (RegExp('</style', caseSensitive: false).hasMatch(css)) {
        throw const FormatException('style.css 只放 CSS，不放 style 标签');
      }
      final style = '<style>\n$css\n</style>';
      final close = RegExp('</head\\s*>', caseSensitive: false);
      html = close.hasMatch(html) ? html.replaceFirst(close, '$style</head>') : '$style\n$html';
    }
    if (js.isNotEmpty) {
      final escaped = js.replaceAll(RegExp('</script', caseSensitive: false), r'<\/script');
      final script = '<script>\n$escaped\n</script>';
      final close = RegExp('</body\\s*>', caseSensitive: false);
      html = close.hasMatch(html) ? html.replaceFirst(close, '$script</body>') : '$html\n$script';
    }
    CreativeContract.validateHtml(html);
    return html;
  }

  static String path(Map<String, dynamic> args) {
    final value = args['path'];
    if (value is! String || !paths.contains(value)) {
      throw const FormatException('path 只能是 index.html、style.css、script.js');
    }
    return value;
  }

  static Map<String, Object?> read(Map<String, dynamic> state, Map<String, dynamic> args) {
    final name = path(args);
    final text = files(state)[name];
    if (text == null) return {'exists': false, 'path': name, 'hash': ''};
    final start = (args['offset'] as num? ?? 0).toInt();
    if (start < 0 || start > text.length) throw const FormatException('offset 超出文件');
    final end = (start + chunkLimit).clamp(0, text.length);
    return {'path': name, 'hash': CreativeContract.hash(text),
      'content': text.substring(start, end), 'offset': start, 'next_offset': end,
      'characters': text.length, 'eof': end == text.length};
  }

  static Map<String, Object?> edit(Map<String, dynamic> state,
      Map<String, dynamic> args, {bool patch = false}) {
    final name = path(args);
    final project = files(state);
    final before = project[name];
    final beforeHash = before == null ? '' : CreativeContract.hash(before);
    if (args['expected_hash'] != beforeHash) {
      throw const FormatException('文件已变化，请先读取最新 hash 再修改');
    }
    String after;
    if (patch) {
      final old = args['old_text'];
      final replacement = args['new_text'];
      if (before == null || old is! String || old.isEmpty ||
          replacement is! String || old.length > chunkLimit || replacement.length > chunkLimit) {
        throw const FormatException('局部修改需要原文和新文，每段最多 16000 字符');
      }
      final at = before.indexOf(old);
      if (at < 0 || before.indexOf(old, at + old.length) >= 0) {
        throw const FormatException('原文必须在文件中唯一匹配，请重新读取');
      }
      after = before.replaceRange(at, at + old.length, replacement);
    } else {
      final content = args['content'];
      if (content is! String || content.length > chunkLimit) {
        throw const FormatException('单次写入最多 16000 字符，请分块追加');
      }
      if (!{'replace', 'append'}.contains(args['mode'])) {
        throw const FormatException('mode 必须是 replace 或 append');
      }
      after = args['mode'] == 'append' ? '${before ?? ''}$content' : content;
    }
    project[name] = after;
    if (project.values.fold<int>(0, (n, s) => n + utf8.encode(s).length) > CreativeContract.maxHtmlBytes) {
      throw const FormatException('作品文件合计超过 800 KB');
    }
    state['files'] = project;
    state['verification'] = <String, Object?>{};
    return {'saved': true, 'path': name, 'hash': CreativeContract.hash(after), 'characters': after.length};
  }

  /// Start a fresh context only at a completed tool boundary. Files, plan and
  /// actual feedback survive; never cut a reasoning/tool exchange in half.
  static void compact(Map<String, dynamic> state) {
    if ((state['pending'] as List).isNotEmpty) return;
    final history = state['history'] as List;
    if (history.length > 18 || utf8.encode(jsonEncode(history)).length > 180000) {
      state['history'] = <Object?>[];
    }
  }

  static List<Map<String, Object?>> messages(Map<String, dynamic> state,
      Map<String, dynamic> work) => [
    {'role': 'system', 'content': instruction},
    {'role': 'user', 'content': jsonEncode({
      'original_request': work['original_request'] ?? work['request_quote'] ?? '',
      'creative_brief': work['brief'], 'saved_plan': state['plan'],
      'files': manifest(state), 'last_feedback': state['feedback'],
      'verification': state['verification'],
      'recovery': state['recovery'] ?? '',
    })},
    ...(state['history'] as List).whereType<Map>().map((m) => Map<String, Object?>.from(m)),
  ];

  static Map<String, Object?> _tool(String name, String description,
      Map<String, Object?> properties, List<String> required) => {
    'type': 'function', 'function': {'name': name, 'description': description,
      'parameters': {'type': 'object', 'properties': properties,
        'required': required, 'additionalProperties': false}},
  };
  static const _string = <String, Object?>{'type': 'string'};
  static final tools = <Map<String, Object?>>[
    _tool('work_plan', '保存作品体验与接续计划；先理解原始委托再制作。', {
      'title': _string, 'intro': _string, 'plan': _string,
      'interaction': {'type': 'string', 'enum': ['companion', 'local']},
    }, ['title', 'intro', 'plan', 'interaction']),
    _tool('work_read', '读取当前作品文件和内容 hash；大文件按 next_offset 继续。', {
      'path': _string, 'offset': {'type': 'integer'},
    }, ['path']),
    _tool('work_write', '写入或追加一段文件，最多16000字符。新文件 expected_hash=""，已有文件使用最新 hash。', {
      'path': _string, 'content': _string, 'expected_hash': _string,
      'mode': {'type': 'string', 'enum': ['replace', 'append']},
    }, ['path', 'content', 'expected_hash', 'mode']),
    _tool('work_patch', '用唯一匹配的原文作局部替换，不必重写整个作品。', {
      'path': _string, 'old_text': _string, 'new_text': _string, 'expected_hash': _string,
    }, ['path', 'old_text', 'new_text', 'expected_hash']),
    _tool('work_preview', '实际运行当前作品并依次点击、检查文字；返回真实报错、DOM和宿主互动证据。', {
      'checks': {'type': 'array', 'items': {'type': 'object', 'properties': {
        'click': _string, 'selector': _string, 'text': _string,
      }, 'required': ['selector', 'text'], 'additionalProperties': false}},
    }, ['checks']),
    _tool('work_finish', '提交当前已通过试玩的版本。必须先完成体验、检查和修复；本轮最后一个调用。', {}, []),
  ];

  static const instruction = '''你是鲸鱼娘的小作品工作 Agent，负责实现作品，不扮演聊天角色。自主选择读写、局部修改、实际试玩和提交工具，根据实际结果继续工作。不要仅描述计划或一次输出整件作品 JSON。
original_request 是用户原始要求，优先于 creative_brief 中额外推断；brief 提供创作心意和风格。不要擅自添加离线、随机对手、固定台词等限制。“我们一起玩”“和她对战”应使用真实伴侣互动，不能伪装成随机电脑。保留相关审美与心意，不需要整套角色设定。作品源码中不放私人聊天、密钥、思考或工程诊断。
先 work_plan 保存简短体验设计与后续步骤：interaction=companion 表示她实际参与选择，local 表示无需模型参与的本地作品。每次操作由宿主完成并返回事实；报错要检查和修正。内容开放，不局限于游戏。复用已有正确文件，缺信息先读文件。每次最多8个工具调用，依赖上一步返回的 hash 时等下一轮；工具执行严格按顺序，work_finish 必须最后。
工作区仅含 index.html（界面）、style.css（可选纯CSS）、script.js（可选纯JS）。宿主自动内联后两者，脚本在界面后执行；不要 import/require、CDN、网络、iframe、本地文件、外部字体、localStorage 或请求手机权限。可以内联SVG/Canvas/CSS画图。适配360px手机，按钮有实际功能。单次文件写入最多16000字符，大文件追加或局部修改。
work_preview 传1至6个按顺序执行的 checks，每项 click 可选，selector 必须有且存在，text 是预期包含的文字。每步等待页面更新后检查。覆盖关键按钮、实际状态变化；互动作品须完成 choose/reveal 的整轮，不能只测标题。失败结果含实际DOM/错误，可据此重读并修复。修改之后必须再次试玩同一版本才能 work_finish。预览成功只证明已执行的检查，不编造全面质量保证。
宿主异步 API window.companion：initialState 为上次保存的轻量状态；saveState(value) 保存进度；choose(turn, options, context) 请她在2–8个字符串选项中选择，只返回{committed:true}；reveal(turn, playerChoice) 提交玩家选择并返回{choice,playerChoice}；report({text:简短真实结果}) 留给聊天理解。先 await choose 成功，再允许玩家选择，最后 reveal。回合编号持久化且不复用，重进同局继续原回合，重复调用不重选。await saveState 后更新恢复点。API失败提供重试按钮，不以随机或预设台词冒充她。普通动画/计分在本地执行，不每点击都调用模型。
companion.preview===true 时宿主模拟选择并记录顺序，不需要绕过真实游戏路径。只有通过真实试玩且有当前源码的验证记录才能提交。直接文字说完成不会发布。可用 work_plan 更新接续说明；任务可能暂停重启，文件和已执行工具会保留。''';
}
