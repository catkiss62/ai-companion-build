import 'package:ai_companion_localfirst/core/mcp/cedar_semantic_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool opens(String? intent, {bool explicit = false, bool narrow = false,
      bool recent = false, bool configured = true, bool active = false}) =>
      CedarSemanticRoutePolicy.directRequest(
        configured: configured, explicitRequest: explicit,
        intent: intent, recentAssistant: recent,
      ) || CedarSemanticRoutePolicy.contextualRequest(
        configured: configured, sessionActive: active,
        explicitRequest: explicit, narrowCandidate: narrow,
        intent: intent, recentAssistant: recent,
      );

  test('semantic action can enter without keyword; chat and delay veto keywords', () {
    expect(opens('act_now'), isTrue);
    expect(opens('chat', explicit: true, narrow: true), isFalse);
    expect(opens('defer', explicit: true), isFalse);
    expect(opens('chat', narrow: true), isFalse);
  });

  test('short acceptance needs recent assistant context; disabled never opens', () {
    expect(opens('accept', recent: true), isTrue);
    expect(opens('accept'), isFalse);
    expect(opens('accept', recent: true, configured: false), isFalse);
  });

  test('Jev unavailable leaves narrow DeepSeek planner only', () {
    expect(opens(null, narrow: true), isTrue);
    expect(opens(null, explicit: true), isTrue);
    expect(opens(null), isFalse);
    expect(opens('act_now', active: true), isFalse);
  });
}
