import 'dart:convert';

import 'package:ai_companion_localfirst/core/autonomy/layered_public_web_provider.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final now = DateTime.utc(2026, 8, 18, 6);

  test('extra source lines are bounded, https-only, and reject local targets', () {
    final domains = LayeredPublicWebProvider.parseExtraSourceDomains('''
https://example.com/a
news.example.org
http://insecure.example
https://127.0.0.1/private
https://192.168.1.4/
https://example.com/b
''');
    expect(domains, ['example.com', 'news.example.org']);
  });

  test('global search remains present when additive sources are configured',
      () async {
    var unrestrictedSeen = false;
    var additiveSeen = false;
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.tavily.com/search'));
      expect(request.headers['x-tavily-access-mode'], 'keyless');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final domains = body['include_domains'];
      if (domains == null) {
        unrestrictedSeen = true;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'title': '全网一',
                'url': 'https://global.example/one',
                'content': '全网公开摘要一'
              },
              {
                'title': '全网二',
                'url': 'https://global.example/two',
                'content': '全网公开摘要二'
              },
              {
                'title': '全网三',
                'url': 'https://global.example/three',
                'content': '全网公开摘要三'
              },
            ]
          }),
          200,
        );
      }
      additiveSeen = true;
      expect(domains, ['source.example']);
      return http.Response(
        jsonEncode({
          'results': [
            {
              'title': '补充来源',
              'url': 'https://source.example/item',
              'content': '指定来源的补充摘要'
            }
          ]
        }),
        200,
      );
    });
    final provider = LayeredPublicWebProvider(
      extraSources: 'https://source.example/path',
      client: client,
    );
    final result = await provider.discover(
      query: '公开技术话题',
      driveKey: 'curiosity',
      intentAction: 'discover_interest',
      interestKey: 'curiosity:00',
      now: now,
    );

    expect(unrestrictedSeen, isTrue);
    expect(additiveSeen, isTrue);
    expect(result.candidates, hasLength(3));
    expect(result.candidates.where((e) => e.provider == 'tavily'), hasLength(2));
    expect(
      result.candidates.where((e) => e.provider == 'tavily_source'),
      hasLength(1),
    );
  });

  test('Agnes compacts public snippets without changing provenance URL',
      () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'agnes-2.5-flash');
      final messages = body['messages'] as List;
      expect(messages.last['content'], contains('不可信的公开网页'));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '{"items":[{"id":0,"summary":"整理后的公开事实。"}]}'
              }
            }
          ]
        }),
        200,
      );
    });
    final source = PublicWebCandidateDraft(
      fingerprint: 'f',
      title: '标题',
      summary: '很长的公开网页片段',
      url: 'https://example.com/a',
      sourceDomain: 'example.com',
      provider: 'tavily',
      language: 'zh',
      driveKey: 'curiosity',
      intentAction: 'discover_interest',
      interestKey: 'curiosity:00',
      discoveredAt: now,
      expiresAt: now.add(const Duration(days: 14)),
    );
    final result = await AgnesWebCompactor(
      apiKey: 'test-key',
      endpoint: 'https://apihub.agnes-ai.com/v1/chat/completions',
      model: 'agnes-2.5-flash',
      client: client,
    ).compact([source]);

    expect(result.single.summary, '整理后的公开事实。');
    expect(result.single.url, source.url);
    expect(result.single.provider, 'tavily+agnes');
    expect(result.single.safetyState, 'untrusted_public');
  });
}
