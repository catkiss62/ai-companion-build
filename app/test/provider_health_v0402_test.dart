import 'package:ai_companion_localfirst/core/diagnostics/provider_health.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw provider failures collapse into fixed redacted categories', () {
    expect(ProviderHealth.errorCategory('tavily_http_401'), 'authorization');
    expect(ProviderHealth.errorCategory('tavily_http_429'), 'rate_limited');
    expect(ProviderHealth.errorCategory('tavily_http_503'), 'server_http');
    expect(ProviderHealth.errorCategory('千问视觉 API 503：busy'), 'server_http');
    expect(ProviderHealth.errorCategory('TimeoutException'), 'timeout');
    const raw = 'https://secret.example/path?token=abc';
    final redacted = ProviderHealth.errorCategory(raw);
    expect(ProviderHealth.errorCategories, contains(redacted));
    expect(redacted, isNot(raw));
    expect(ProviderHealth.safeErrorCategory('secret text'), 'other');
    expect(ProviderHealth.safeProvider('untrusted-provider-name'), 'none');
    expect(
      ProviderHealth.safeContext('screen_observation'),
      'screen_observation',
    );
  });

  test('search diagnostics distinguish primary failure and fallback success', () {
    final now = DateTime.utc(2026, 8, 28);
    final result = PublicWebProviderResult(
      candidates: [
        PublicWebCandidateDraft(
          fingerprint: 'f',
          title: 't',
          summary: 's',
          url: 'https://zh.wikipedia.org/wiki/test',
          sourceDomain: 'zh.wikipedia.org',
          provider: 'wikimedia_zh',
          language: 'zh',
          driveKey: 'curiosity',
          intentAction: 'answer_user_with_tool',
          interestKey: 'user_turn',
          discoveredAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
      ],
      provider: 'wikimedia_zh',
      primaryProvider: 'tavily',
      primaryFailureReason: 'tavily_http_503',
      fallbackProvider: 'wikimedia',
      fallbackEligible: true,
      fallbackAttempted: true,
      fallbackSucceeded: true,
    );

    final event = ProviderHealth.webSearchEvent(
      result: result,
      context: 'user_turn',
      elapsed: const Duration(seconds: 6),
    );
    expect(event.primaryProvider, 'tavily');
    expect(event.primaryOutcome, 'failed');
    expect(event.primaryErrorCategory, 'server_http');
    expect(event.fallbackProvider, 'wikimedia');
    expect(event.fallbackAttempted, isTrue);
    expect(event.fallbackOutcome, 'success');
    expect(event.finalProvider, 'wikimedia');
    expect(event.finalOutcome, 'success');
    expect(event.latencyBucket, '5_to_15s');
  });

  test('compaction reports disabled and missing configuration separately', () {
    const disabled = PublicWebProviderResult(
      candidates: [],
      provider: 'tavily_layered',
    );
    const missingKey = PublicWebProviderResult(
      candidates: [],
      provider: 'tavily_layered',
      compactionEnabled: true,
    );

    expect(
      ProviderHealth.webCompactionEvent(
        result: disabled,
        context: 'autonomous',
        elapsed: Duration.zero,
      ).finalOutcome,
      'not_called',
    );
    expect(
      ProviderHealth.webCompactionEvent(
        result: missingKey,
        context: 'autonomous',
        elapsed: Duration.zero,
      ).finalOutcome,
      'not_configured',
    );
  });
}
