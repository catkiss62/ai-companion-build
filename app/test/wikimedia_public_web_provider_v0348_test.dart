import 'dart:convert';

import 'package:ai_companion_localfirst/core/autonomy/wikimedia_public_web_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final provider = WikimediaPublicWebProvider();
  final now = DateTime.utc(2026, 8, 18, 4);

  test('parses at most three metadata candidates and strips search markup', () {
    final pages = List.generate(5, (index) => {
          'id': index + 1,
          'key': '测试 页面 $index',
          'title': '测试 $index',
          'excerpt': '一段 <span class="searchmatch">公开</span> 摘要 &amp; 资料',
          'description': '备用说明',
        });
    final candidates = provider.parseResponse(
      jsonEncode({'pages': pages}),
      driveKey: 'curiosity',
      intentAction: 'discover_interest',
      interestKey: 'curiosity:01',
      now: now,
    );

    expect(candidates, hasLength(3));
    expect(candidates.first.summary, '一段 公开 摘要 & 资料');
    expect(candidates.first.url, startsWith('https://zh.wikipedia.org/wiki/'));
    expect(candidates.first.sourceDomain, 'zh.wikipedia.org');
    expect(candidates.first.provider, 'wikimedia_zh');
    expect(candidates.first.fingerprint, hasLength(64));
    expect(candidates.first.safetyState, 'untrusted_public');
    expect(candidates.first.expiresAt, now.add(const Duration(days: 14)));
  });

  test('invalid or content-free responses create no candidate', () {
    expect(
      provider.parseResponse(
        jsonEncode({'pages': [{'key': '', 'title': 'missing key'}]}),
        driveKey: 'social',
        intentAction: 'discover_interest',
        interestKey: 'social:00',
        now: now,
      ),
      isEmpty,
    );
    expect(
      provider.parseResponse(
        jsonEncode({'unexpected': []}),
        driveKey: 'social',
        intentAction: 'discover_interest',
        interestKey: 'social:00',
        now: now,
      ),
      isEmpty,
    );
  });

  test('title and summary storage are bounded before database insertion', () {
    final candidates = provider.parseResponse(
      jsonEncode({
        'pages': [
          {
            'key': 'bounded',
            'title': List.filled(200, '题').join(),
            'excerpt': List.filled(900, '摘').join(),
          }
        ]
      }),
      driveKey: 'reflection',
      intentAction: 'discover_interest',
      interestKey: 'reflection:02',
      now: now,
    );
    expect(candidates.single.title.length, 160);
    expect(candidates.single.summary.length, 800);
  });
}
