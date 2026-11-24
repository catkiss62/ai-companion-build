/// +475 records have an id but no threadId. Each opens as its own conversation.
class CommissionThread {
  static String key(Map row) {
    final root = row['threadId'];
    return root is String && root.isNotEmpty ? root : row['id'] as String;
  }

  static String display(Map row) {
    final answer = row['answer'];
    final status = switch (row['state']) {
      'stopped' => '这轮委托已停止。',
      'running' || 'interrupted' => '这轮还没有交付结果。',
      _ => '未保存回复。',
    };
    return '你\n${row['goal']}\n\n小鲸鱼\n${answer is String && answer.isNotEmpty ? answer : status}';
  }

  static List<Map<String, Object?>> history(List<Map<String, dynamic>> rows) {
    // Bound only the model context. The user can read every saved turn.
    final messages = <Map<String, Object?>>[];
    for (final row in rows.reversed.take(10).toList().reversed) {
      String clip(String value, int max) =>
          value.length <= max ? value : value.substring(0, max);
      messages.add({
        'role': 'user',
        'content': clip(row['goal'] as String, 1000),
      });
      if (row['answer'] case final String answer) {
        messages.add({'role': 'assistant', 'content': clip(answer, 2500)});
      } else {
        messages.add({'role': 'assistant', 'content': '该轮未完成交付。'});
      }
    }
    return messages;
  }
}
