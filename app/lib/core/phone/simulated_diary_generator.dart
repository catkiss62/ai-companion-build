import 'dart:convert';
import 'dart:async';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../storage/secure_config.dart';

class SimulatedDiaryMaterial {
  const SimulatedDiaryMaterial({
    required this.localDay,
    required this.sharedMoments,
    required this.cares,
    required this.carriedThreads,
    required this.awareness,
    required this.messageCount,
    required this.relationshipEventCount,
    required this.quietDay,
  });

  final String localDay;
  final List<String> sharedMoments;
  final List<String> cares;
  final List<String> carriedThreads;
  final List<String> awareness;
  final int messageCount;
  final int relationshipEventCount;
  final bool quietDay;

  Map<String, Object?> toPromptJson() => {
        'local_day': localDay,
        'shared_moments': sharedMoments,
        'cares': cares,
        'carried_threads': carriedThreads,
        'awareness': awareness,
        'message_count': messageCount,
        'relationship_event_count': relationshipEventCount,
        'quiet_day': quietDay,
      };

  factory SimulatedDiaryMaterial.fromJson(Map<String, dynamic> value) {
    List<String> list(String key) => (value[key] as List? ?? const [])
        .whereType<String>().toList(growable: false);
    return SimulatedDiaryMaterial(
      localDay: value['local_day'] as String,
      sharedMoments: list('shared_moments'), cares: list('cares'),
      carriedThreads: list('carried_threads'), awareness: list('awareness'),
      messageCount: (value['message_count'] as num?)?.toInt() ?? 0,
      relationshipEventCount: (value['relationship_event_count'] as num?)?.toInt() ?? 0,
      quietDay: value['quiet_day'] == true,
    );
  }

  int get concreteItemCount =>
      sharedMoments.length + cares.length + carriedThreads.length + awareness.length;
}

class SimulatedDiaryDraft {
  const SimulatedDiaryDraft({required this.body, required this.focusKind});

  final String body;
  final String focusKind;
}

abstract interface class SimulatedDiaryGenerator {
  Future<SimulatedDiaryDraft?> generate({
    required SimulatedDiaryMaterial material,
    required List<String> recentBodies,
  });
}

class SimulatedDiaryQuality {
  const SimulatedDiaryQuality._();

  static const forbiddenBoilerplate = <String>{
    '不是流水账',
    '轻轻收在这里',
    '作为一个AI',
    '作为AI',
    '根据以上资料',
  };

  static bool acceptable(
    String body, {
    required List<String> recentBodies,
  }) {
    final trimmed = body.trim();
    if (trimmed.length < 60 || trimmed.length > 800) return false;
    if (forbiddenBoilerplate.any(trimmed.contains)) return false;
    // Ignore quoted language and technical mentions; reject report perspective,
    // never globally replace the words AI or 用户 in genuine diary prose.
    final voice = trimmed.replaceAll(RegExp(r'“[^”]*”|「[^」]*」|"[^"]*"'), '');
    if (!voice.contains('我')) return false;
    if (RegExp(r'(?:^|[。！？；\n])\s*(?:用户|AI|助手)(?:今天|随后|主动|又|曾|已|在|向|对|与|和|表示|提出|询问|回复|说|进行|要求|分享|讨论|希望|认为)')
        .hasMatch(voice)) return false;
    return recentBodies.take(7).every(
          (recent) => similarity(trimmed, recent) < 0.72,
        );
  }

  static double similarity(String left, String right) {
    final a = _bigrams(_normalize(left));
    final b = _bigrams(_normalize(right));
    if (a.isEmpty || b.isEmpty) return 0;
    final union = <String>{...a, ...b};
    if (union.isEmpty) return 0;
    return a.intersection(b).length / union.length;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s，。！？；：、…“”「」【】（）()\-—_]+'), '');

  static Set<String> _bigrams(String value) {
    if (value.length < 2) return value.isEmpty ? const {} : {value};
    return {
      for (var index = 0; index < value.length - 1; index++)
        value.substring(index, index + 2),
    };
  }
}

class DeepSeekSimulatedDiaryGenerator implements SimulatedDiaryGenerator {
  DeepSeekSimulatedDiaryGenerator({
    SecureConfig? secureConfig,
    DeepSeekClient Function()? clientFactory,
  })  : _secureConfig = secureConfig ?? SecureConfig.instance,
        _clientFactory = clientFactory ?? DeepSeekClient.new;

  final SecureConfig _secureConfig;
  final DeepSeekClient Function() _clientFactory;

  @override
  Future<SimulatedDiaryDraft?> generate({
    required SimulatedDiaryMaterial material,
    required List<String> recentBodies,
  }) async {
    final apiKey = (await _secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) return null;
    final client = _clientFactory();
    try {
      final payload = await client.jsonCompletion(
        apiKey: apiKey,
        endpoint: await _secureConfig.readEndpoint(),
        model: DeepSeekModelProfile.flash,
        thinking: false,
        maxTokens: 1100,
        usageLane: 'simulated_diary',
        messages: [
          const {
            'role': 'system',
            'content': '你替 Android AI Companion 中持续存在的女性小鲸鱼整理一天的私人日记。'
                '只能使用给出的真实派生资料，不得补造用户说过的话、现实经历、网页事实或关系进展。'
                '日记只是展示层，不是新的记忆、人格结论或学习证据。只输出 JSON，不输出 Markdown。'
                '用我称呼自己，用你或对方的真实称呼写对方；资料中的AI和用户只是内部角色标记，'
                '不要沿用旁观者报告口吻。技术讨论中确实提到AI时可以保留，不要机械替换。',
          },
          {
            'role': 'user',
            'content': '把下面一天的资料整理成一篇 120 到 520 个中文字符、2 到 5 个自然段的第一人称日记。'
                '优先抓住一两个具体变化，再写我仍在意什么、我怎样理解它；资料少就诚实写短，不要硬凑成长或圆满结论。'
                '不得逐项复述，不要使用“不是流水账”“轻轻收在这里”“作为AI”等固定元话术。'
                '避开近期日记的句式、开头、结尾和中心话题；但不能为了不同而发明新事实。'
                '只返回 {"body":"日记正文","focus_kind":"shared_moment|care|thread|awareness|quiet_day"}。\n'
                '今日资料=${jsonEncode(material.toPromptJson())}\n'
                '近期日记=${jsonEncode(recentBodies.take(7).toList())}',
          },
        ],
      ).timeout(const Duration(seconds: 24));
      return parse(payload);
    } finally {
      client.close();
    }
  }

  static SimulatedDiaryDraft parse(Map<String, dynamic> payload) {
    final body = _cleanBody(payload['body']);
    final focus = payload['focus_kind']?.toString().trim().toLowerCase() ?? '';
    const allowed = {
      'shared_moment',
      'care',
      'thread',
      'awareness',
      'quiet_day',
    };
    if (body.length < 60 || body.length > 800 || !allowed.contains(focus)) {
      throw const FormatException('日记 JSON 字段不完整或越界');
    }
    return SimulatedDiaryDraft(body: body, focusKind: focus);
  }

  static String _cleanBody(Object? raw) => raw
      ?.toString()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .trim() ??
      '';
}

class SimulatedDiaryAttempt {
  const SimulatedDiaryAttempt(this.draft, this.attempts, this.failureKind);
  final SimulatedDiaryDraft? draft;
  final int attempts;
  final String failureKind;

  static Future<SimulatedDiaryAttempt> run(SimulatedDiaryGenerator generator, {
    required SimulatedDiaryMaterial material,
    required List<String> recentBodies,
  }) async {
    var failure = 'unavailable';
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final draft = await generator.generate(material: material, recentBodies: recentBodies);
        if (draft != null && SimulatedDiaryQuality.acceptable(draft.body, recentBodies: recentBodies)) {
          return SimulatedDiaryAttempt(draft, attempt, '');
        }
        failure = draft == null ? 'unavailable' : 'quality_rejected';
      } on TimeoutException { failure = 'timeout';
      } on FormatException { failure = 'invalid_response';
      } catch (_) { failure = 'generation_failed'; }
    }
    return SimulatedDiaryAttempt(null, 2, failure);
  }
}
