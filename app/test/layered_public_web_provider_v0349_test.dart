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
    var keylessHeaderSeen = false;
    List<String>? additiveDomains;
    final client = MockClient((request) async {
      keylessHeaderSeen = request.headers.entries.any(
        (entry) => entry.key.toLowerCase() == 'x-tavily-access-mode' &&
            entry.value == 'keyless',
      );
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
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      additiveSeen = true;
      additiveDomains = (domains as List).cast<String>();
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
        headers: const {'content-type': 'application/json; charset=utf-8'},
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
    expect(keylessHeaderSeen, isTrue);
    expect(additiveDomains, ['source.example']);
    expect(result.candidates, hasLength(3));
    expect(result.compactionAttempted, isFalse);
    expect(result.compactionSucceeded, isFalse);
    expect(result.candidates.where((e) => e.provider == 'tavily'), hasLength(2));
    expect(
      result.candidates.where((e) => e.provider == 'tavily_source'),
      hasLength(1),
    );
  });

  test('Agnes compacts public snippets without changing provenance URL',
      () async {
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      capturedBody = body;
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
        headers: const {'content-type': 'application/json; charset=utf-8'},
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
    expect(capturedBody?['model'], 'agnes-2.5-flash');
    final messages = capturedBody?['messages'] as List;
    expect(messages.last['content'], contains('不可信的公开网页'));
  });

  test('search URL is extracted and the complete body is summarized', () async {
    final calls = <String>[];
    String agnesPrompt = '';
    final client = MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.host == 'api.tavily.com' &&
          request.url.path == '/search') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'results': <Object?>[
              <String, Object?>{
                'title': '海洋研究',
                'url': 'https://science.example/ocean',
                'content': '这只是搜索片段',
              },
            ],
          }),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      if (request.url.host == 'api.tavily.com' &&
          request.url.path == '/extract') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['urls'], <String>['https://science.example/ocean']);
        expect(body.containsKey('query'), isFalse);
        return http.Response(
          jsonEncode(<String, Object?>{
            'results': <Object?>[
              <String, Object?>{
                'url': 'https://science.example/ocean',
                'raw_content': '正文开头。${List<String>.filled(40, '完整研究材料。').join()}正文结尾。',
              },
            ],
          }),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      agnesPrompt = (messages.last as Map)['content'] as String;
      return http.Response(
        jsonEncode(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'content': jsonEncode(<String, Object?>{
                  'reader_summary': '这是基于实际正文整理的海洋研究概要。',
                  'key_points': <String>['要点一'],
                  'uncertainties': <String>['样本有限'],
                  'topic_tags': <String>['海洋', '研究'],
                }),
              },
            },
          ],
        }),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final result = await LayeredPublicWebProvider(
      tavilyApiKey: 'tavily-test',
      agnesApiKey: 'agnes-test',
      client: client,
    ).discover(
      query: '近期海洋研究',
      driveKey: 'curiosity',
      intentAction: 'discover_interest',
      interestKey: 'curiosity:ocean',
      now: now,
    );

    expect(calls, containsAllInOrder(<String>['/search', '/extract']));
    expect(agnesPrompt, contains('正文开头'));
    expect(agnesPrompt, contains('正文结尾'));
    expect(result.extractionSucceeded, isTrue);
    expect(result.compactionSucceeded, isTrue);
    expect(result.candidates.single.readState, 'verified');
    expect(result.candidates.single.summary, contains('实际正文'));
    expect(result.candidates.single.keyPoints, <String>['要点一']);
    expect(result.candidates.single.searchQuery, '近期海洋研究');
  });
}
