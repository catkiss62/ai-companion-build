class ReferenceChunkDraft {
  const ReferenceChunkDraft({
    required this.section,
    required this.title,
    required this.content,
    required this.tags,
    required this.weight,
  });

  final String section;
  final String title;
  final String content;
  final List<String> tags;
  final double weight;

  Map<String, Object?> toMap() => {
        'section': section,
        'title': title,
        'content': content,
        'tags': tags.join('|'),
        'weight': weight,
      };
}

/// Keeps the user's original character/persona text intact while producing
/// small deterministic retrieval chunks. No LLM is required to import data.
class ReferenceDocumentChunker {
  const ReferenceDocumentChunker({this.maxChars = 900});

  final int maxChars;

  List<ReferenceChunkDraft> chunk({
    required String name,
    required String raw,
    List<String> aliases = const [],
    String section = 'character',
  }) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];
    final blocks = normalized
        .split(RegExp(r'\n\s*\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final sourceBlocks = blocks.isEmpty ? [normalized] : blocks;
    final chunks = <ReferenceChunkDraft>[];
    final tags = <String>{name, ...aliases}.where((e) => e.trim().isNotEmpty).toList();
    var index = 0;
    for (final block in sourceBlocks) {
      for (final piece in _splitLong(block)) {
        index++;
        final title = _guessTitle(piece, fallback: '$name · $index');
        chunks.add(ReferenceChunkDraft(
          section: section,
          title: title,
          content: piece,
          tags: tags,
          weight: index <= 2 ? 0.66 : 0.58,
        ));
      }
    }
    return chunks;
  }

  List<String> _splitLong(String block) {
    if (block.length <= maxChars) return [block];
    final sentences = <String>[];
    var sentenceBuffer = StringBuffer();
    const endings = {'。', '！', '？', '!', '?', '；', ';'};
    for (final rune in block.runes) {
      final ch = String.fromCharCode(rune);
      sentenceBuffer.write(ch);
      if (endings.contains(ch)) {
        sentences.add(sentenceBuffer.toString());
        sentenceBuffer = StringBuffer();
      }
    }
    if (sentenceBuffer.isNotEmpty) sentences.add(sentenceBuffer.toString());
    final out = <String>[];
    var buffer = StringBuffer();
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      if (buffer.length + sentence.length > maxChars && buffer.isNotEmpty) {
        out.add(buffer.toString().trim());
        buffer = StringBuffer();
      }
      if (sentence.length > maxChars) {
        if (buffer.isNotEmpty) {
          out.add(buffer.toString().trim());
          buffer = StringBuffer();
        }
        for (var start = 0; start < sentence.length; start += maxChars) {
          final end = (start + maxChars).clamp(0, sentence.length).toInt();
          out.add(sentence.substring(start, end).trim());
        }
      } else {
        buffer.write(sentence);
      }
    }
    if (buffer.isNotEmpty) out.add(buffer.toString().trim());
    return out.where((e) => e.isNotEmpty).toList();
  }

  String _guessTitle(String text, {required String fallback}) {
    final firstLine = text.split('\n').first.trim();
    final cleaned = firstLine.replaceAll(RegExp(r'^[#【\[\-\s]+|[】\]]+$'), '').trim();
    if (cleaned.isNotEmpty && cleaned.length <= 38) return cleaned;
    return fallback;
  }
}
