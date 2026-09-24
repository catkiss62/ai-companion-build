import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';

void main() {
  test('reading an existing quiz result is not a fresh share event', () {
    expect(CedarPlatformActionPolicy.isResultSnapshot('sins_virtues_get_result'),
        isTrue);
    expect(CedarPlatformActionPolicy.isResultSnapshot('get_result'), isTrue);
    expect(CedarPlatformActionPolicy.isResultSnapshot('sins_virtues_answer_batch'),
        isFalse);
    expect(CedarPlatformActionPolicy.isResultSnapshot('cast'), isFalse);
  });
}
