import 'dart:convert';

import '../ai/generation_cancellation.dart';
import '../models/message_attachment.dart';
import 'mcp_protocol.dart';

class CedarOutcomeMediaCandidate {
  const CedarOutcomeMediaCandidate({
    required this.url,
    required this.fieldName,
  });

  final String url;
  final String fieldName;
}

typedef CedarMediaMaterializer = Future<MessageAttachment> Function(
  CedarOutcomeMediaCandidate candidate,
);
typedef CedarMediaDiscarder = Future<void> Function(
  MessageAttachment attachment,
);

/// Resolves only protocol-shaped Cedar media fields. It intentionally does not
/// scrape arbitrary URLs from prose and never performs public-web discovery.
class CedarOutcomeMediaBridge {
  const CedarOutcomeMediaBridge._();

  static const int maxAttachmentsPerOutcome = 4;
  static const int maxRemoteAttachmentsPerOutcome = 3;
  static const int maxNestedJsonChars = 240000;

  static const Set<String> _directMediaFields = <String>{
    'photo_url',
    'image_url',
    'picture_url',
    'thumbnail_url',
    'preview_url',
    'cover_url',
  };
  static const Set<String> _mediaContainers = <String>{
    'images',
    'photos',
    'pictures',
    'media',
    'thumbnails',
    'previews',
  };
  static const Set<String> _containerUrlFields = <String>{
    'url',
    'src',
    'href',
  };

  static List<CedarOutcomeMediaCandidate> candidates(
    McpToolOutcome outcome, {
    int limit = maxRemoteAttachmentsPerOutcome,
  }) {
    if (outcome.isError || limit <= 0) {
      return const <CedarOutcomeMediaCandidate>[];
    }
    final result = <CedarOutcomeMediaCandidate>[];
    final seen = <String>{};

    void addCandidate(Object? raw, String fieldName) {
      if (result.length >= limit) return;
      if (raw is Iterable) {
        for (final value in raw) {
          addCandidate(value, fieldName);
          if (result.length >= limit) return;
        }
        return;
      }
      if (raw is! String) return;
      final value = raw.trim();
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.scheme.toLowerCase() != 'https' ||
          !uri.hasAuthority ||
          uri.host.trim().isEmpty ||
          !seen.add(uri.toString())) {
        return;
      }
      result.add(CedarOutcomeMediaCandidate(
        url: uri.toString(),
        fieldName: fieldName,
      ));
    }

    String normalizedKey(Object? raw) {
      final source = raw?.toString().trim() ?? '';
      return source
          .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'),
            (match) => '${match.group(1)}_${match.group(2)}',
          )
          .replaceAll(RegExp(r'[-\s]+'), '_')
          .toLowerCase();
    }

    Object? decodeJsonDocument(String raw) {
      final clean = raw.trim();
      if (clean.length < 2 || clean.length > maxNestedJsonChars) return null;
      if (!((clean.startsWith('{') && clean.endsWith('}')) ||
          (clean.startsWith('[') && clean.endsWith(']')))) {
        return null;
      }
      try {
        return jsonDecode(clean);
      } catch (_) {
        return null;
      }
    }

    void visit(Object? value, int depth, {bool mediaContainer = false}) {
      if (value == null || depth > 12 || result.length >= limit) return;
      if (value is Map) {
        for (final entry in value.entries) {
          final key = normalizedKey(entry.key);
          if (_directMediaFields.contains(key)) {
            addCandidate(entry.value, key);
          } else if (mediaContainer && _containerUrlFields.contains(key)) {
            addCandidate(entry.value, key);
          } else {
            visit(
              entry.value,
              depth + 1,
              mediaContainer:
                  mediaContainer || _mediaContainers.contains(key),
            );
          }
          if (result.length >= limit) return;
        }
        return;
      }
      if (value is Iterable) {
        for (final item in value) {
          visit(item, depth + 1, mediaContainer: mediaContainer);
          if (result.length >= limit) return;
        }
        return;
      }
      if (value is String) {
        final decoded = decodeJsonDocument(value);
        if (decoded != null) {
          visit(decoded, depth + 1, mediaContainer: mediaContainer);
        }
      }
    }

    visit(outcome.structuredContent, 0);
    for (final block in outcome.content) {
      if (result.length >= limit) break;
      if (block.kind != McpContentKind.text || block.text.trim().isEmpty) {
        continue;
      }
      visit(block.text, 0);
    }
    return List<CedarOutcomeMediaCandidate>.unmodifiable(result);
  }

  /// Runs a bounded best-effort materialization pass. Ordinary download or
  /// decode failures keep the real textual Outcome; explicit Stop discards
  /// already materialized, not-yet-delivered attachments and propagates.
  static Future<List<MessageAttachment>> materialize({
    required Iterable<CedarOutcomeMediaCandidate> candidates,
    required CedarMediaMaterializer materialize,
    required CedarMediaDiscarder discard,
    GenerationCancellationToken? cancellationToken,
    int limit = maxRemoteAttachmentsPerOutcome,
  }) async {
    if (limit <= 0) return const <MessageAttachment>[];
    final result = <MessageAttachment>[];
    try {
      for (final candidate in candidates.take(limit)) {
        cancellationToken?.throwIfCancelled();
        try {
          final attachment = await materialize(candidate);
          if (cancellationToken?.isCancelled == true) {
            try {
              await discard(attachment);
            } catch (_) {}
            cancellationToken!.throwIfCancelled();
          }
          result.add(attachment);
        } on GenerationCancelledByUserException {
          rethrow;
        } catch (_) {
          // Optional remote media must never erase a successful game Outcome.
        }
      }
      return List<MessageAttachment>.unmodifiable(result);
    } on GenerationCancelledByUserException {
      for (final attachment in result) {
        try {
          await discard(attachment);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
