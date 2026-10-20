import 'dart:async';
import 'dart:convert';

/// Bounds only an explicitly completed, single-choice text stream. Usage-only
/// events still pass through. Keepalives never restart the terminal deadline.
class RelayTextTailGuard {
  const RelayTextTailGuard({this.grace = const Duration(seconds: 2)});
  final Duration grace;

  Stream<String> bind(Stream<String> source, {required void Function() onDeadline}) {
    late StreamController<String> output;
    StreamSubscription<String>? input;
    Timer? timer;
    var ended = false;
    var disabled = false;
    final text = StringBuffer();
    void disable() { disabled = true; timer?.cancel(); timer = null; }
    void inspect(String line) {
      if (disabled || !line.trimLeft().startsWith('data:')) return;
      final payload = line.trimLeft().substring(5).trim();
      if (payload == '[DONE]') { timer?.cancel(); return; }
      final value = jsonDecode(payload);
      if (value is! Map) { disable(); return; }
      if (value['error'] != null) { disable(); return; }
      final choices = value['choices'];
      if (choices == null || choices is List && choices.isEmpty) return;
      if (choices is! List || choices.length != 1 || choices.first is! Map) {
        disable(); return;
      }
      final choice = choices.first as Map;
      if (choice['index'] != null && choice['index'] != 0) { disable(); return; }
      final delta = choice['delta'];
      if (delta != null && delta is! Map) { disable(); return; }
      final data = delta is Map ? delta : const {};
      if (data['tool_calls'] != null || data['function_call'] != null) { disable(); return; }
      final content = data['content'];
      final reasoning = data['reasoning_content'];
      if (timer != null && ((content is String && content.isNotEmpty) ||
          (reasoning is String && reasoning.isNotEmpty))) { disable(); return; }
      if (content is String) text.write(content);
      // Machine-looking output stays on the existing protocol/failure path.
      final body = text.toString().trim();
      if (RegExp(r'DSML|<tool|<invoke|<function|"(?:tool_calls?|params_json|room_id)"\s*:',
          caseSensitive: false).hasMatch(body)) { disable(); return; }
      final finish = choice['finish_reason'];
      if (finish != null && finish != 'stop') { disable(); return; }
      if (finish != 'stop' || body.isEmpty || timer != null) return;
      timer = Timer(grace, () {
        if (ended || disabled) return;
        ended = true;
        onDeadline();
        output.add('data: [DONE]');
        unawaited(output.close());
        unawaited(input?.cancel());
      });
    }
    output = StreamController<String>(
      onListen: () {
        input = source.listen((line) {
          if (ended) return;
          // Inspection precedes delivery; the stop event itself is never lost.
          try { inspect(line); } catch (_) { disable(); }
          output.add(line);
        }, onError: (Object error, StackTrace stack) {
          if (ended) return;
          timer?.cancel(); output.addError(error, stack);
        }, onDone: () {
          if (ended) return;
          ended = true; timer?.cancel(); unawaited(output.close());
        });
      },
      onPause: () => input?.pause(),
      onResume: () => input?.resume(),
      onCancel: () async { ended = true; timer?.cancel(); await input?.cancel(); },
    );
    return output.stream;
  }
}
