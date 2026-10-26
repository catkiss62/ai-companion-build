import '../../core/database/app_database.dart';

/// Reading history is not a pending user promise or a fresh observation.
/// This policy leaves reminiscence and genuine future requests available.
abstract final class QqHistoryContextPolicy {
  static bool futureRequest(String text) => RegExp(
    r'之后|以后|晚点|回头|明天|下次|待会|稍后|过会|记得|提醒|等.{0,16}(?:结果|回复|消息)').hasMatch(text);
  static bool inventedFollowup(String title, String detail) =>
    RegExp(r'QQ|qq|群聊|群记录').hasMatch('$title $detail') &&
    RegExp(r'已能|已可|已经.{0,5}(?:查看|做好|接通|完成)|已完成').hasMatch(title) &&
    RegExp(r'(?:后续|以后|要不要|是否).{0,30}(?:未明确|尚未明确|未决定|不确定)').hasMatch(detail);

  static bool allowThread({required String title, required String detail, required String userText, required bool qqReference}) =>
    futureRequest(userText) || (!inventedFollowup(title, detail) && !qqReference);

  static Future<Set<String>> unsupportedTopics(AppDatabase db) async {
    final sql = await db.database;
    final rows = await sql.rawQuery("SELECT t.topic_key,t.title,t.detail,m.content FROM unfinished_threads t "
      "LEFT JOIN messages m ON m.id=t.source_message_id WHERE t.status='active'");
    return {for (final row in rows)
      if (inventedFollowup('${row['title']}', '${row['detail']}') && !futureRequest('${row['content'] ?? ''}')) '${row['topic_key']}'};
  }

  static const proactiveBoundary = '【历史群聊的时间边界】历史对话、念头和摘要中的群聊内容属于当时见闻。'
    '可以自然回想旧事，但没有本轮新的QQ消息证据或读取回执，就不能说刚刚又看了群、顺着代码查到群、群里现在仍在聊。'
    '未明确要求以后处理的查档结果，不是待办或承诺，不据此反复催问是否去群里行动。';
}
