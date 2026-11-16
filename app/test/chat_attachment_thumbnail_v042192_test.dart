import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/features/chat/chat_attachment_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AttachmentStorage extends MessageAttachmentStorage {
  int lookups = 0;
  final result = Completer<File>();

  @override
  Future<File> fileFor(String path) {
    lookups++;
    return result.future;
  }
}

void main() {
  testWidgets(
    'image status and viewport rebuilds keep the same thumbnail footprint',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync();
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/preview.png')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aVf8AAAAASUVORK5CYII=',
          ),
        );
      final storage = _AttachmentStorage();
      final attachment = MessageAttachment(
        id: 'image',
        messageId: 'turn',
        kind: 'image',
        originalPath: 'original',
        thumbnailPath: 'thumbnail',
        mimeType: 'image/png',
        byteSize: 32,
        width: 300,
        height: 900,
        source: 'gallery',
        createdAt: DateTime(2026),
      );

      Future<void> render(MessageAttachment attachment, double viewport) =>
          tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Center(
                  child: SizedBox(
                    width: viewport,
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChatAttachmentThumbnail(
                            attachment: attachment,
                            storage: storage,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

      await render(attachment, 300);
      final thumb = find.byType(ChatAttachmentThumbnail);
      final loadingSize = tester.getSize(thumb);
      expect(loadingSize.height, 320);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      storage.result.complete(file);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(thumb), loadingSize);
      await render(attachment.copyWith(visionStatus: 'completed'), 240);
      expect(tester.getSize(thumb), loadingSize);
      final square = MessageAttachment(
        id: 'square',
        messageId: 'turn',
        kind: 'image',
        originalPath: 'original',
        thumbnailPath: 'thumbnail',
        mimeType: 'image/png',
        byteSize: 32,
        width: 400,
        height: 400,
        source: 'gallery',
        createdAt: DateTime(2026),
      );
      await render(square, 230);
      expect(tester.getSize(thumb), const Size(230, 230));
      expect(storage.lookups, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
