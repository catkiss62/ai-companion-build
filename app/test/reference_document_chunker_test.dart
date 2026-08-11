import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/reference/reference_document_chunker.dart';

void main() {
  test('keeps short persona paragraphs as retrieval chunks', () {
    const chunker = ReferenceDocumentChunker(maxChars: 120);
    final chunks = chunker.chunk(
      name: 'Yuki',
      aliases: const ['有希'],
      raw: '【性格】\n安静，但熟悉以后会主动吐槽。\n\n【说话】\n口语自然，偶尔说短句。',
    );
    expect(chunks.length, 2);
    expect(chunks.first.tags, contains('Yuki'));
    expect(chunks.first.tags, contains('有希'));
  });

  test('splits long content without dropping text', () {
    const chunker = ReferenceDocumentChunker(maxChars: 40);
    final source = List.generate(8, (i) => '第$i句有一些人物资料。').join();
    final chunks = chunker.chunk(name: '测试', raw: source);
    expect(chunks.length, greaterThan(1));
    expect(chunks.map((e) => e.content).join(), source);
  });
}
