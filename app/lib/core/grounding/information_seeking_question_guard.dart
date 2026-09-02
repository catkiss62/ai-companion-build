import '../database/app_database.dart';

class InformationSeekingQuestionGuardResult {
  const InformationSeekingQuestionGuardResult({
    required this.allowed,
    required this.reason,
    required this.matchCount,
    required this.rhetoricalCount,
  });

  final bool allowed;
  final String reason;
  final int matchCount;
  final int rhetoricalCount;

  bool get hasInformationRequest => matchCount > 0;
  bool get hasRhetoricalQuestion => rhetoricalCount > 0;
}

/// A deliberately narrow final-output guard for questions which clearly ask
/// the user for new information. It is not a punctuation ban: rhetorical,
/// teasing and quoted questions remain available when they do not request an
/// answer. The prompt-side Conversation Move remains the primary control.
class InformationSeekingQuestionGuard {
  const InformationSeekingQuestionGuard._();

  static final _informationPatterns = <RegExp>[
    RegExp(r'(发生了?什么|出了什么事|遇到什么事|怎么了|咋了)[^。！？\n]{0,24}[？?]'),
    RegExp(
      r'(为什么|为啥|怎么会|什么|谁|哪(?:里|个|种|些|边|步)?|多少|多久|多长|几次|几点)[^。！？\n]{0,28}[？?]',
    ),
    RegExp(r'(是不是|有没有|能不能|可不可以|愿不愿意|要不要)[^。！？\n]{0,28}[？?]'),
    RegExp(r'你(想不想|愿不愿意|能不能|可不可以|觉得)[^。！？\n]{0,28}[？?]'),
    RegExp(r'(能和我说说|可以告诉我|跟我说说|告诉我)[^。！？\n]{0,20}[？?]'),
  ];
  static const _rhetoricalMarkers = <String>[
    '难道',
    '该不会',
    '不会吧',
    '莫非',
    '终于',
    '笑死',
    '你猜',
    '凭什么',
    '什么鬼',
    '关我什么',
    '谁让',
    '这合理吗',
    '还有天理吗',
  ];

  static InformationSeekingQuestionGuardResult evaluate({
    required String text,
    required bool askAuthorized,
  }) {
    if (text.trim().isEmpty) {
      return const InformationSeekingQuestionGuardResult(
        allowed: true,
        reason: 'empty',
        matchCount: 0,
        rhetoricalCount: 0,
      );
    }
    var matches = 0;
    var rhetorical = 0;
    for (final segment in _segments(text)) {
      if (_rhetoricalMarkers.any(segment.contains)) {
        if (segment.contains('?') || segment.contains('？')) rhetorical += 1;
        continue;
      }
      if (_informationPatterns.any((pattern) => pattern.hasMatch(segment))) {
        matches += 1;
      }
    }
    return InformationSeekingQuestionGuardResult(
      allowed: askAuthorized || matches == 0,
      reason: matches == 0
          ? rhetorical > 0
              ? 'rhetorical_only'
              : 'no_information_request'
          : askAuthorized
              ? 'authorized_information_request'
              : 'unauthorized_information_request',
      matchCount: matches,
      rhetoricalCount: rhetorical,
    );
  }

  static Iterable<String> _segments(String value) sync* {
    final buffer = StringBuffer();
    for (var index = 0; index < value.length; index += 1) {
      final char = value[index];
      buffer.write(char);
      if (const {'。', '！', '？', '!', '?', '\n'}.contains(char)) {
        final segment = buffer.toString().trim();
        if (segment.isNotEmpty) yield segment;
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) yield tail;
  }
}

class InformationSeekingQuestionGuardTelemetry {
  const InformationSeekingQuestionGuardTelemetry._();

  static Future<void> note(
    AppDatabase db, {
    required InformationSeekingQuestionGuardResult result,
    required String action,
  }) async {
    try {
      const prefix = 'information_question_guard';
      final total = int.tryParse(
            await db.getSetting('${prefix}_match_count') ?? '',
          ) ??
          0;
      await db.setSetting(
        '${prefix}_match_count',
        '${total + result.matchCount}',
      );
      final actionCount = int.tryParse(
            await db.getSetting('${prefix}_${action}_count') ?? '',
          ) ??
          0;
      await db.setSetting(
        '${prefix}_${action}_count',
        '${actionCount + 1}',
      );
      await db.setSetting('${prefix}_last_reason', result.reason);
      await db.setSetting(
        '${prefix}_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Output diagnostics must never block a valid generation transaction.
    }
  }
}
