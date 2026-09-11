import 'tts_text_processor.dart';

/// Incrementally separates immersive narration from quoted dialogue without
/// waiting for the complete model response. Only closed sentences/lines are
/// emitted during streaming; [finish] is reserved for a verified terminal
/// response, so an interrupted tail is never spoken accidentally.
class TtsStructuredStreamParser {
  final StringBuffer _buffer = StringBuffer();
  TtsSpeechRole? _role;

  List<TtsPreparedUnit> add(String delta) {
    if (delta.isEmpty) return const <TtsPreparedUnit>[];
    final ready = <TtsPreparedUnit>[];
    for (final rune in delta.runes) {
      final character = String.fromCharCode(rune);
      if (character == '\r') continue;
      if (_role == null) {
        if (character.trim().isEmpty) continue;
        if (_isDialogueOpen(character)) {
          _role = TtsSpeechRole.dialogue;
          continue;
        }
        _role = TtsSpeechRole.narration;
        if (_isNarrationOpen(character)) continue;
      }

      if (character == '\n') {
        _emit(ready);
        continue;
      }
      if ((_role == TtsSpeechRole.dialogue && _isDialogueClose(character)) ||
          (_role == TtsSpeechRole.narration &&
              _isNarrationClose(character))) {
        _emit(ready);
        continue;
      }
      _buffer.write(character);
      if (_isSentenceBoundary(character)) _emit(ready, keepRole: true);
    }
    return ready;
  }

  List<TtsPreparedUnit> finish() {
    final ready = <TtsPreparedUnit>[];
    _emit(ready);
    return ready;
  }

  void reset() {
    _buffer.clear();
    _role = null;
  }

  void _emit(List<TtsPreparedUnit> target, {bool keepRole = false}) {
    final text = _buffer.toString().trim();
    final role = _role;
    _buffer.clear();
    if (text.isNotEmpty && role != null) {
      target.add(TtsPreparedUnit(text: text, role: role));
    }
    if (!keepRole) _role = null;
  }

  static bool _isSentenceBoundary(String value) =>
      const <String>{'。', '！', '？', '!', '?', '；', ';'}.contains(value);

  static bool _isDialogueOpen(String value) =>
      const <String>{'「', '“', '"'}.contains(value);

  static bool _isDialogueClose(String value) =>
      const <String>{'」', '”', '"'}.contains(value);

  static bool _isNarrationOpen(String value) =>
      const <String>{'（', '('}.contains(value);

  static bool _isNarrationClose(String value) =>
      const <String>{'）', ')'}.contains(value);
}
