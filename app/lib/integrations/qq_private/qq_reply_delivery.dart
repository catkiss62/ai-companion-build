import 'dart:math';
import 'package:qq_private_bridge/qq_private_bridge.dart';

/// One platform message has one local receipt. Unknown delivery never falls
/// back to a second send; only an explicit type rejection permits splitting.
class QqReplyDelivery {
  const QqReplyDelivery(this.api, {this.pause, this.interval});
  final QqApi api;
  final Future<void> Function(Duration)? pause;
  final Duration Function()? interval;
  static final _random = Random();

  Future<void> send({required bool group, required String target, required String messageId,
    required String text, required String fileInfo, List<String>? messages, required Future<bool> Function() current,
    required Future<void> Function() beforeSend,
    required Future<void> Function(int sequence, String text, bool image) sent}) async {
    final chunks = [for(final message in messages??[if(text.isNotEmpty)text]) ...splitQqText(message)];
    var sequence = 0, delivered = 0;
    Future<void> part(String content, String media) async {
      if (!await current()) throw StateError('context_invalidated');
      if(delivered>0) {
        final wait=interval?.call()??Duration(milliseconds:1000+_random.nextInt(1001));
        if(pause!=null) {await pause!(wait);} else {await Future<void>.delayed(wait);}
        if(!await current()) throw StateError('context_invalidated');
      }
      await beforeSend();
      if(!await current()) throw StateError('context_invalidated');
      final seq = ++sequence;
      await api.sendMessage(group: group, target: target, messageId: messageId, sequence: seq, text: content, fileInfo: media);
      await sent(seq, content, media.isNotEmpty);
      delivered++;
    }
    if (fileInfo.isEmpty) {
      for (final chunk in chunks) { await part(chunk, ''); }
      return;
    }
    for (final chunk in chunks.take(chunks.isEmpty ? 0 : chunks.length - 1)) { await part(chunk, ''); }
    final caption = chunks.isEmpty ? '' : chunks.last;
    try {
      await part(caption, fileInfo);
    } on QqApiException catch (error) {
      if (caption.isEmpty || error.uncertain || !const {'api_22006', 'api_340069'}.contains(error.code)) rethrow;
      await part(caption, '');
      await part('', fileInfo);
    }
  }
}
