import '../ai/deepseek_client.dart';

/// Shared native function-call assembly for both foreground and autonomous
/// Agent turns. Providers may split the function name and JSON arguments over
/// many SSE deltas; there must be only one implementation of that protocol.
class AgentNativeToolCallAccumulator {
  final Map<int, _AgentNativeToolCallBuilder> _builders =
      <int, _AgentNativeToolCallBuilder>{};

  bool get isEmpty => _builders.isEmpty;
  int get length => _builders.length;

  void add(DeepSeekToolCallDelta fragment) {
    _builders
        .putIfAbsent(
          fragment.index,
          () => _AgentNativeToolCallBuilder(fragment.index),
        )
        .add(fragment);
  }

  void addAll(Iterable<DeepSeekToolCallDelta> fragments) {
    for (final fragment in fragments) {
      add(fragment);
    }
  }

  List<DeepSeekToolCall> build({int limit = 2}) {
    final indexes = _builders.keys.toList()..sort();
    return indexes
        .map((index) => _builders[index]!.build())
        .take(limit)
        .toList(growable: false);
  }
}

final class _AgentNativeToolCallBuilder {
  _AgentNativeToolCallBuilder(this.index);

  final int index;
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  void add(DeepSeekToolCallDelta fragment) {
    if (fragment.id.isNotEmpty) id = fragment.id;
    if (fragment.name.isNotEmpty) name = fragment.name;
    if (fragment.argumentsFragment.isNotEmpty) {
      arguments.write(fragment.argumentsFragment);
    }
  }

  DeepSeekToolCall build() => DeepSeekToolCall(
        id: id.isEmpty ? 'call_$index' : id,
        name: name,
        arguments: arguments.toString(),
      );
}
