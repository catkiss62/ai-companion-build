import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_appraisal_policy.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_deepseek_appraiser.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PublicWebCandidateDraft candidate({String readState = 'verified'}) =>
    PublicWebCandidateDraft(
      fingerprint: 'a'.padRight(64, 'a'),
      title: '海洋生物研究',
      summary: '研究观察了鲸类交流。',
      url: 'https://science.example/whales',
      sourceDomain: 'science.example',
      provider: 'tavily+extract+agnes',
      language: 'zh',
      driveKey: 'curiosity',
      intentAction: 'discover_interest',
      interestKey: 'curiosity:whales',
      discoveredAt: DateTime.utc(2026, 9, 5),
      expiresAt: DateTime.utc(2026, 9, 19),
      readState: readState,
      semanticState: 'pending_appraisal',
      keyPoints: const <String>['鲸类交流具有结构'],
      contentSha256: 'b'.padRight(64, 'b'),
      readAt: DateTime.utc(2026, 9, 5),
      searchQuery: '鲸类交流研究',
    );

const sourceIntent = DesireIntent(
  drive: DriveKey.social,
  score: 0.8,
  reason: 'test',
  wantAction: 'discover_interest',
);

void main() {
  test('DeepSeek independently routes valid knowledge and share value',
      () async {
    final client = DeepSeekClient(
      client: MockClient((request) async => http.Response(
            jsonEncode(<String, Object?>{
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{
                    'content': jsonEncode(<String, Object?>{
                      'items': <Object?>[
                        <String, Object?>{
                          'id': 0,
                          'semantic_state': 'valid',
                          'interest_score': 0.82,
                          'learning_score': 0.76,
                          'share_score': 0.88,
                          'reason': '与搜索目的相符且适合交流',
                        },
                      ],
                    }),
                  },
                },
              ],
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          )),
    );
    final result = await DeepSeekPublicWebAppraiser(
      apiKey: 'test',
      endpoint: 'https://api.deepseek.com/chat/completions',
      client: client,
    ).appraise(
      query: '鲸类交流研究',
      candidates: <PublicWebCandidateDraft>[candidate()],
      sourceIntent: sourceIntent,
      socialExcess: 0,
    );

    expect(result.single.semanticState, 'valid');
    expect(result.single.learningScore, 0.76);
    expect(
      result.single.appraisalState,
      PublicWebAppraisalPolicy.shareCandidate,
    );
  });

  test('malformed DeepSeek response keeps a truthful visit as history only',
      () async {
    final client = DeepSeekClient(
      client: MockClient((request) async => http.Response(
            jsonEncode(<String, Object?>{
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{'content': '{"wrong":true}'},
                },
              ],
            }),
            200,
          )),
    );
    final result = await DeepSeekPublicWebAppraiser(
      apiKey: 'test',
      endpoint: 'https://api.deepseek.com/chat/completions',
      client: client,
    ).appraise(
      query: '鲸类交流研究',
      candidates: <PublicWebCandidateDraft>[candidate()],
      sourceIntent: sourceIntent,
      socialExcess: 0,
    );

    expect(result.single.semanticState, 'history_only');
    expect(result.single.appraisalState, PublicWebAppraisalPolicy.historyOnly);
  });

  test('an unread candidate cannot be promoted by appraisal', () async {
    final result = await DeepSeekPublicWebAppraiser(
      apiKey: '',
      endpoint: 'https://api.deepseek.com/chat/completions',
    ).appraise(
      query: '鲸类交流研究',
      candidates: <PublicWebCandidateDraft>[
        candidate(readState: 'summary_failed'),
      ],
      sourceIntent: sourceIntent,
      socialExcess: 0,
    );

    expect(result.single.appraisalState, PublicWebAppraisalPolicy.discard);
    expect(result.single.semanticState, 'garbled');
  });
}
