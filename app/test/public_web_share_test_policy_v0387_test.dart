import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublicWebShareTestPolicy v0.38.7', () {
    test('sent and WAIT are model decisions rather than system blocks', () {
      final sent = PublicWebShareTestPolicy.classify(
        sent: true,
        reason: 'share',
      );
      expect(sent.result, 'sent');
      expect(sent.blockCategory, 'none');
      expect(sent.modelDecisionReached, isTrue);

      final wait = PublicWebShareTestPolicy.classify(
        sent: false,
        reason: '模型选择 WAIT',
      );
      expect(wait.result, 'model_wait');
      expect(wait.blockCategory, 'none');
      expect(wait.modelDecisionReached, isTrue);
    });

    test('pre-generation blocks stay privacy-safe stable categories', () {
      final lease = PublicWebShareTestPolicy.classify(
        sent: false,
        reason: '主动心跳正在由另一引擎处理',
      );
      expect(lease.result, 'blocked');
      expect(lease.blockCategory, 'proactive_lease');
      expect(lease.modelDecisionReached, isFalse);

      final apiKey = PublicWebShareTestPolicy.classify(
        sent: false,
        reason: '没有 API Key；本地内在状态已继续运行',
      );
      expect(apiKey.blockCategory, 'api_key');
      expect(apiKey.modelDecisionReached, isFalse);
    });

    test('post-generation guards report that a model decision was reached', () {
      final grounding = PublicWebShareTestPolicy.classify(
        sent: false,
        reason: 'Reality Grounding 拦截了主动生成',
      );
      expect(grounding.result, 'blocked');
      expect(grounding.blockCategory, 'grounding_guard');
      expect(grounding.modelDecisionReached, isTrue);

      final template = PublicWebShareTestPolicy.classify(
        sent: false,
        reason: '主动候选命中重复服务模板，已取消',
      );
      expect(template.blockCategory, 'service_template_guard');
      expect(template.modelDecisionReached, isTrue);
    });

    test('candidate sources distinguish reuse from a local fixture', () {
      expect(
        PublicWebShareTestPolicy.existingReadySource,
        isNot(PublicWebShareTestPolicy.diagnosticSeededSource),
      );
      expect(PublicWebShareTestPolicy.pendingSource, 'pending');
    });
  });
}
