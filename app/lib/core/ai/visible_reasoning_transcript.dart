/// Keeps the provider reasoning that was actually offered to the chat surfaces
/// across tool-planning rounds. This is display history, never a prompt input.
class VisibleReasoningTranscript {
  VisibleReasoningTranscript({String recovered = ''})
      : _recovered = recovered.trim();

  final String _recovered;
  final List<String> _planning = <String>[];

  int get planningCount => _planning.length;

  void addPlanning(String reasoning) {
    if (reasoning.trim().isNotEmpty) _planning.add(reasoning.trim());
  }

  String snapshot({String live = '', String liveLabel = '当前过程'}) {
    final sections = <String>[
      if (_recovered.isNotEmpty) _recovered,
      ..._planning,
      if (live.trim().isNotEmpty)
        liveLabel.isEmpty ? live.trim() : '【$liveLabel】\n${live.trim()}',
    ];
    return sections.join('\n\n');
  }

  String committed(String finalReasoning) => snapshot(
        live: finalReasoning,
        liveLabel: '最终回复',
      );
}
