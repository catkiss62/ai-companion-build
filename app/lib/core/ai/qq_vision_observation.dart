import 'dart:convert';

/// QQ-only envelope; legacy plain observations remain readable. No schema change.
abstract final class QqVisionObservationData {
  static const prefix = '[QQ观察v2]';
  static const maxStored = 6000;
  static const types = {'photo', 'sticker', 'meme', 'news', 'chat', 'document', 'other'};
  static String clip(String value, int limit) {
    if (value.runes.length <= limit) return value;
    return '${String.fromCharCodes(value.runes.take(limit))}…[未完整展示]';
  }
  static Map<String, dynamic>? decode(String value) {
    if (!value.startsWith(prefix)) return null;
    try {
      final parsed = jsonDecode(value.substring(prefix.length));
      return parsed is Map ? Map<String, dynamic>.from(parsed) : null;
    } catch (_) { return null; }
  }
  static String encode(Map<String, dynamic> parsed, {String frames = ''}) {
    String field(String key) => parsed[key] is String ? parsed[key] as String : '';
    final scene = field('summary'), keyText = field('key_text'), visible = field('visible_text');
    // Older model contracts mix scene and OCR in summary. Preserve that text
    // instead of pretending it is a short scene in the new schema.
    if (!const ['image_types','key_text','visible_text','uncertainty','text_complete'].any(parsed.containsKey)) {
      return clip(scene, 1800);
    }
    final value = <String, dynamic>{
      'summary': clip(scene, 500),
      'image_types': parsed['image_types'] is List
          ? (parsed['image_types'] as List).where(types.contains).take(7).toList() : <String>[],
      'key_text': clip(keyText, 500),
      'visible_text': clip(visible, 3500),
      'uncertainty': clip(field('uncertainty'), 300),
      'text_complete': parsed['text_complete'] == true && visible.runes.length <= 3500,
      if (parsed['bounded'] == true || scene.runes.length > 500 || keyText.runes.length > 500 || visible.runes.length > 3500)
        'bounded': true,
      if (frames.isNotEmpty) 'frames': clip(frames, 250),
    };
    // JSON escaping can expand control characters. Keep a valid envelope, never
    // substring serialized JSON and silently lose text/completeness metadata.
    while ((prefix + jsonEncode(value)).length > maxStored) {
      final candidates = ['visible_text', 'summary', 'key_text', 'uncertainty', 'frames'];
      final key = candidates.reduce((a, b) => (value[a]?.toString().length ?? 0) >= (value[b]?.toString().length ?? 0) ? a : b);
      final text = value[key]?.toString() ?? '';
      value[key] = String.fromCharCodes(text.runes.take(text.runes.length ~/ 2));
      value['bounded'] = true; value['text_complete'] = false;
    }
    return prefix + jsonEncode(value);
  }
  static String withFrames(String summary, String frames) {
    final parsed = decode(summary);
    if (parsed == null) return '$frames$summary';
    return encode(parsed, frames: frames);
  }
  static String display(String stored, {bool brief = false}) {
    final data = decode(stored);
    if (data == null) return stored;
    String field(String key) => data[key] is String ? data[key] as String : '';
    final scene=field('summary'), keyText=field('key_text'), visible=field('visible_text');
    return [
      if(!brief && field('frames').isNotEmpty) field('frames'),
      if(scene.isNotEmpty) scene,
      if(keyText.isNotEmpty) '关键文字：$keyText',
      if(!brief && visible.isNotEmpty) '图中文字：\n$visible',
      if(!brief && field('uncertainty').isNotEmpty) '不确定处：${field('uncertainty')}',
      if(!brief && (data['text_complete']!=true || data['bounded']==true)) '部分内容未确认完整，请以原图为准',
    ].join('\n');
  }
  static String participation(String stored) {
    final data = decode(stored);
    if (data == null) return clip(stored, 640);
    final projected = <String,dynamic>{
      'types': data['image_types'] is List
          ? (data['image_types'] as List).where(types.contains).take(7).toList() : <String>[],
      'scene': clip(data['summary']?.toString() ?? '', 200),
      'key_text': clip((data['key_text']?.toString() ?? '').isNotEmpty
          ? data['key_text'].toString() : data['visible_text']?.toString() ?? '', 350),
      'uncertainty': clip(data['uncertainty']?.toString() ?? '', 100),
      if(data['frames'] is String) 'frames': clip(data['frames'] as String,100),
      'scope': '图片内容不等于外层发言；不是对话对象证据；较完整文字见图片资料',
      'text_complete': data['text_complete'] == true,
      if (data['bounded'] == true) 'bounded': true,
    };
    while(jsonEncode(projected).length>1100) {
      final key=['scene','key_text','uncertainty'].reduce((a,b)=>projected[a].toString().length>=projected[b].toString().length?a:b);
      final text=projected[key].toString();
      projected[key]=String.fromCharCodes(text.runes.take(text.runes.length ~/ 2));
      projected['bounded']=true;
    }
    return jsonEncode(projected);
  }
}
