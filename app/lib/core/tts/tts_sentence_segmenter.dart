/// Incremental splitter that mirrors Meju A2 `processText()` sentence
/// boundaries.
///
/// A2 splits only on:
///   。 ！ ？ ； . ! ? ;
/// Normal sentences still do not split on commas, ideographic commas, newlines
/// or ellipsis. The upgraded local engine rejects Chinese input above 300
/// phones, so an exceptional punctuation-free run is capped at 72 characters,
/// preferring a nearby comma/colon/space. Layout line breaks are normalized to
/// ordinary spaces before boundary scanning. Delimiters themselves are not spoken.
///
/// The original A2 removes bracketed blocks before splitting. For streaming
/// input we preserve the same effect by ignoring sentence punctuation while it
/// is inside one of those removable bracket pairs; TtsTextProcessor removes
/// the bracketed block itself before generation.
class TtsSentenceSegmenter {
  static const int maxSafeChunkChars = 72;
  static const int _preferredSplitFloor = 36;

  String _buffer = '';
  String _fenceCarry = '';
  bool _inFence = false;
  final List<String> _bracketStack = <String>[];

  List<String> add(String delta) {
    if (delta.isEmpty) return const [];
    _consume(delta);
    return _drain(finalFlush: false);
  }

  List<String> flush() {
    if (_fenceCarry.isNotEmpty && !_inFence) {
      _buffer += _fenceCarry;
    }
    _fenceCarry = '';
    final ready = _drain(finalFlush: true);
    reset();
    return ready;
  }

  void reset() {
    _buffer = '';
    _fenceCarry = '';
    _inFence = false;
    _bracketStack.clear();
  }

  void _consume(String delta) {
    var text = _fenceCarry + delta;
    _fenceCarry = '';
    var offset = 0;

    while (offset < text.length) {
      final fence = text.indexOf('```', offset);
      if (fence < 0) {
        var tail = text.substring(offset);
        var trailingTicks = 0;
        for (var i = tail.length - 1; i >= 0 && trailingTicks < 2; i--) {
          if (tail[i] != '`') break;
          trailingTicks++;
        }
        if (trailingTicks > 0) {
          _fenceCarry = tail.substring(tail.length - trailingTicks);
          tail = tail.substring(0, tail.length - trailingTicks);
        }
        if (!_inFence) _appendOutsideFence(tail);
        break;
      }

      if (!_inFence && fence > offset) {
        _appendOutsideFence(text.substring(offset, fence));
      }
      _inFence = !_inFence;
      offset = fence + 3;
    }
  }

  void _appendOutsideFence(String text) {
    for (final rune in text.runes) {
      final c = String.fromCharCode(rune);
      // v0.29.1 polish: visual paragraph/layout breaks are not A2 sentence
      // boundaries. Normalize them before boundary scanning so streaming and
      // full-message playback behave identically and the legacy text frontend
      // never receives a raw line separator that could become extra prosody.
      if (_isLayoutBreak(c)) {
        if (_buffer.isNotEmpty && !_buffer.endsWith(' ')) _buffer += ' ';
        continue;
      }
      _trackBracket(c);
      _buffer += c;
    }
  }

  bool _isLayoutBreak(String c) =>
      c == '\n' || c == '\r' || c == '\u2028' || c == '\u2029';

  void _trackBracket(String c) {
    const pairs = <String, String>{
      '(': ')',
      '（': '）',
      '<': '>',
      '{': '}',
      '[': ']',
      '【': '】',
    };
    final close = pairs[c];
    if (close != null) {
      _bracketStack.add(close);
      return;
    }
    if (_bracketStack.isNotEmpty && c == _bracketStack.last) {
      _bracketStack.removeLast();
    }
  }

  List<String> _drain({required bool finalFlush}) {
    final out = <String>[];
    while (true) {
      final natural = _findA2Boundary(_buffer);
      final safety = _findSafetyBoundary(_buffer);
      final _Boundary? boundary;
      if (natural == null) {
        boundary = safety;
      } else if (safety == null || natural.start <= safety.start) {
        boundary = natural;
      } else {
        boundary = safety;
      }
      if (boundary == null) break;
      final chunk = _buffer.substring(0, boundary.start).trim();
      _buffer = _buffer.substring(boundary.end);
      if (chunk.isNotEmpty) out.add(chunk);
    }

    if (finalFlush) {
      final rest = _buffer.trim();
      if (rest.isNotEmpty) out.add(rest);
      _buffer = '';
    }
    return out;
  }

  _Boundary? _findA2Boundary(String text) {
    final stack = <String>[];
    const pairs = <String, String>{
      '(': ')',
      '（': '）',
      '<': '>',
      '{': '}',
      '[': ']',
      '【': '】',
    };

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      final close = pairs[c];
      if (close != null) {
        stack.add(close);
        continue;
      }
      if (stack.isNotEmpty && c == stack.last) {
        stack.removeLast();
        continue;
      }
      if (stack.isNotEmpty || !_isA2Delimiter(c)) continue;

      var end = i + 1;
      while (end < text.length && _isA2Delimiter(text[end])) {
        end++;
      }
      return _Boundary(i, end);
    }
    return null;
  }

  bool _isA2Delimiter(String c) =>
      c == '。' || c == '！' || c == '？' || c == '；' ||
      c == '.' || c == '!' || c == '?' || c == ';';

  _Boundary? _findSafetyBoundary(String text) {
    if (text.length <= maxSafeChunkChars) return null;
    final hardCut = _avoidSplittingSurrogate(text, maxSafeChunkChars);
    final stack = <String>[];
    const pairs = <String, String>{
      '(': ')',
      '（': '）',
      '<': '>',
      '{': '}',
      '[': ']',
      '【': '】',
    };
    var preferred = -1;
    for (var i = 0; i < hardCut; i++) {
      final c = text[i];
      final close = pairs[c];
      if (close != null) {
        stack.add(close);
        continue;
      }
      if (stack.isNotEmpty && c == stack.last) {
        stack.removeLast();
        continue;
      }
      if (stack.isEmpty && i >= _preferredSplitFloor && _isSafetyDelimiter(c)) {
        preferred = i;
      }
    }
    return preferred >= 0
        ? _Boundary(preferred, preferred + 1)
        : _Boundary(hardCut, hardCut);
  }

  int _avoidSplittingSurrogate(String text, int requested) {
    var cut = requested.clamp(1, text.length - 1).toInt();
    final current = text.codeUnitAt(cut);
    final previous = text.codeUnitAt(cut - 1);
    if (current >= 0xDC00 && current <= 0xDFFF &&
        previous >= 0xD800 && previous <= 0xDBFF) {
      cut--;
    }
    return cut;
  }

  bool _isSafetyDelimiter(String c) =>
      c == '，' || c == ',' || c == '、' || c == '：' || c == ':' || c == ' ';
}

class _Boundary {
  const _Boundary(this.start, this.end);
  final int start;
  final int end;
}
