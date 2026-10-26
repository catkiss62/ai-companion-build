import 'dart:convert';

/// Display/model projection only. Canonical platform text is never rewritten.
abstract final class QqMessageText {
  static String project(String raw) => raw.replaceAllMapped(
    RegExp(r'<faceType=[^>]{0,4096}>'), (match) {
      final tag=match[0]!;
      final encoded=RegExp(r'ext="([A-Za-z0-9+/=_-]{1,3000})"').firstMatch(tag)?.group(1);
      if(encoded!=null) {
        try {
          final value=jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(encoded))));
          final text=value is Map?value['text']:null;
          if(text is String && text.trim().isNotEmpty) {
            final label=text.replaceAll(RegExp(r'[\x00-\x1f\x7f]'),' ').trim();
            return '[QQ表情：${label.length>80?label.substring(0,80):label}]';
          }
        }catch(_) { /* Unknown native emoji remains explicitly unknown. */ }
      }
      return '[QQ原生表情，未提供含义]';
    });
}
