import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/public_web_candidate.dart';

abstract class PublicWebProvider {
  String get providerKey;

  Future<PublicWebProviderResult> discover({
    required String query,
    required String driveKey,
    required String intentAction,
    required String interestKey,
    required DateTime now,
  });
}

class WikimediaPublicWebProvider implements PublicWebProvider {
  WikimediaPublicWebProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get providerKey => 'wikimedia_zh';

  @override
  Future<PublicWebProviderResult> discover({
    required String query,
    required String driveKey,
    required String intentAction,
    required String interestKey,
    required DateTime now,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty || normalized.length > 40) {
      return PublicWebProviderResult(
        candidates: const [],
        provider: providerKey,
        failureReason: 'invalid_safe_topic',
      );
    }
    final uri = Uri.https(
      'zh.wikipedia.org',
      '/w/rest.php/v1/search/page',
      <String, String>{'q': normalized, 'limit': '5'},
    );
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'User-Agent': 'AICompanion/0.34.8 (private Android companion)',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return PublicWebProviderResult(
          candidates: const [],
          provider: providerKey,
          failureReason: 'http_${response.statusCode}',
        );
      }
      return PublicWebProviderResult(
        candidates: parseResponse(
          response.body,
          driveKey: driveKey,
          intentAction: intentAction,
          interestKey: interestKey,
          now: now,
        ),
        provider: providerKey,
      );
    } on TimeoutException {
      return PublicWebProviderResult(
        candidates: const [],
        provider: providerKey,
        failureReason: 'timeout',
      );
    } catch (_) {
      return PublicWebProviderResult(
        candidates: const [],
        provider: providerKey,
        failureReason: 'network_or_parse_failure',
      );
    }
  }

  List<PublicWebCandidateDraft> parseResponse(
    String body, {
    required String driveKey,
    required String intentAction,
    required String interestKey,
    required DateTime now,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final rawPages = decoded['pages'];
    if (rawPages is! List) return const [];
    final candidates = <PublicWebCandidateDraft>[];
    for (final raw in rawPages.whereType<Map>()) {
      final key = _bounded(raw['key']?.toString() ?? '', 180);
      final title = _bounded(_plain(raw['title']?.toString() ?? ''), 160);
      if (key.isEmpty || title.isEmpty) continue;
      final url = Uri.https('zh.wikipedia.org', '/wiki/$key').toString();
      final excerpt = _plain(raw['excerpt']?.toString() ?? '');
      final description = _plain(raw['description']?.toString() ?? '');
      final summary = _bounded(
        excerpt.isNotEmpty ? excerpt : description,
        800,
      );
      final fingerprint = sha256.convert(utf8.encode(url)).toString();
      candidates.add(PublicWebCandidateDraft(
        fingerprint: fingerprint,
        title: title,
        summary: summary,
        url: url,
        sourceDomain: 'zh.wikipedia.org',
        provider: providerKey,
        language: 'zh',
        driveKey: driveKey,
        intentAction: intentAction,
        interestKey: interestKey,
        discoveredAt: now,
        expiresAt: now.add(const Duration(days: 14)),
        safetyState: 'untrusted_public',
      ));
      if (candidates.length >= 3) break;
    }
    return candidates;
  }

  static String _plain(String value) => value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit).trimRight();
}
