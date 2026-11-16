import 'package:flutter_test/flutter_test.dart';
import '../lib/core/memory/hybrid_memory_ranking.dart';

void main() {
  test('semantic paraphrase enters without lexical evidence', () {
    expect(
      HybridMemoryRanking.rank(
        lexical: [],
        semantic: {'interview': .65, 'phone': .33},
        limit: 8,
      ),
      ['interview'],
    );
  });
  test('agreement outranks incidental lexical overlap', () {
    expect(
      HybridMemoryRanking.rank(
        lexical: ['incidental', 'relevant'],
        semantic: {'relevant': .8, 'incidental': .3},
        limit: 1,
      ),
      ['relevant'],
    );
  });
  test('weak candidates do not fill empty slots', () {
    expect(
      HybridMemoryRanking.rank(
        lexical: [],
        semantic: {'a': .34, 'b': .22},
        limit: 8,
      ),
      isEmpty,
    );
  });
  test('unavailable vectors preserve lexical ordering', () {
    expect(
      HybridMemoryRanking.rank(
        lexical: ['new_fact', 'old_event'],
        semantic: {},
        limit: 8,
      ),
      ['new_fact', 'old_event'],
    );
  });
}
