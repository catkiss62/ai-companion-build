import 'dart:convert';
import 'dart:io';

/// Private, short-lived resume coordinates. Message bodies and credentials are
/// never stored here. SQLite still owns message deduplication and reply state.
class QqGatewayCheckpoint {
  QqGatewayCheckpoint(this.file, this.scope);
  final File file;
  final String scope;
  static const lifetime = Duration(minutes: 4);

  Future<({String session, int sequence})?> read(DateTime now) async {
    try {
      if (!await file.exists() || await file.length() > 4096) return null;
      final row = jsonDecode(await file.readAsString());
      if (row is! Map || row['scope'] != scope) return null;
      final session = row['session'], sequence = row['seq'], at = row['at'];
      if (session is! String ||
          session.isEmpty ||
          session.length > 512 ||
          sequence is! int ||
          sequence < 0 ||
          at is! int) return null;
      final age = now.millisecondsSinceEpoch - at;
      return age >= 0 && age < lifetime.inMilliseconds
          ? (session: session, sequence: sequence)
          : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> write(String session, int sequence, DateTime now) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
        jsonEncode({
          'scope': scope,
          'session': session,
          'seq': sequence,
          'at': now.millisecondsSinceEpoch
        }),
        flush: true);
    await temporary.rename(file.path);
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
