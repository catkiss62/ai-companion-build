import 'dart:async';
import 'dart:io';

import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/features/chat/chat_attachment_gallery.dart';
import 'package:ai_companion_localfirst/features/chat/chat_attachment_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends MessageAttachmentStorage {
  final pending = Completer<File>();
  @override
  Future<File> fileFor(String path) => pending.future;
}

MessageAttachment attachment(String id) => MessageAttachment(
      id: id, messageId: 'batch', kind: 'image', originalPath: id,
      thumbnailPath: id, mimeType: 'image/png', byteSize: 20,
      width: 300, height: 900, source: 'gallery', createdAt: DateTime(2026),
    );

void main() {
  testWidgets('swipe, operation target, status update and new batch identity', (tester) async {
    final storage = _Storage();
    final images = ['a', 'b', 'c'].map(attachment).toList();
    String? opened;
    Future<void> render(List<MessageAttachment> items) => tester.pumpWidget(
      MaterialApp(home: Material(child: Center(child: SizedBox(width: 230,
        child: IntrinsicWidth(child: ChatAttachmentGallery(
          attachments: items, storage: storage, onOpen: (a) => opened = a.id,
          statusBuilder: (a) => Text('status:${a.id}:${a.visionStatus}'),
        )),
      )))),
    );
    await render(images);
    expect(find.text('status:a:pending'), findsOneWidget);
    expect(find.byKey(const ValueKey('image-dot-2')), findsOneWidget);
    final size = tester.getSize(find.byType(PageView));
    expect(size.width, 230);
    await tester.drag(find.byType(PageView), const Offset(-220, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('status:b:pending'), findsOneWidget);
    // The thumbnail's existing tap callback must reference this page's image.
    tester.widget<ChatAttachmentThumbnail>(find.byKey(const ValueKey('b'))).onTap();
    expect(opened, 'b');
    final dotA = tester.widget<Container>(find.byKey(const ValueKey('image-dot-0')));
    final dotB = tester.widget<Container>(find.byKey(const ValueKey('image-dot-1')));
    expect((dotA.decoration! as BoxDecoration).color,
        isNot((dotB.decoration! as BoxDecoration).color));
    await render([images[0], images[1].copyWith(visionStatus: 'completed'), images[2]]);
    expect(find.text('status:b:completed'), findsOneWidget);
    expect(tester.getSize(find.byType(PageView)), size);
    await tester.drag(find.byType(PageView), const Offset(220, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('status:a:pending'), findsOneWidget);
    await render([attachment('x'), attachment('y')]);
    await tester.pump();
    expect(find.text('status:x:pending'), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    await render([]);
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing image stays bounded and does not block next page', (tester) async {
    final storage = _Storage();
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(
      child: ChatAttachmentGallery(attachments: ['a', 'b'].map(attachment).toList(),
        storage: storage, onOpen: (_) {}, statusBuilder: (a) => Text(a.id)),
    ))));
    storage.pending.completeError(const FileSystemException('missing'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MissingChatAttachment), findsWidgets);
    await tester.drag(find.byType(PageView), const Offset(-290, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single image retains its footprint without pagination', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(
      child: ChatAttachmentGallery(attachments: [attachment('one')],
        storage: _Storage(), onOpen: (_) {}),
    ))));
    expect(find.byType(PageView), findsNothing);
    expect(tester.getSize(find.byType(ChatAttachmentThumbnail)).height, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical gesture scrolls chat at narrow width and large text', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: Material(child: Center(child: SizedBox(width: 200, height: 450,
        child: ListView(controller: scroll, children: [
          IntrinsicWidth(child: ChatAttachmentGallery(
            attachments: ['a', 'b', 'c'].map(attachment).toList(), storage: _Storage(),
            onOpen: (_) {}, statusBuilder: (a) => Text('status:${a.id}'),
          )),
          const SizedBox(height: 1200),
        ]),
      ))),
    )));
    await tester.drag(find.byType(PageView), const Offset(0, -140));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(scroll.offset, greaterThan(0));
    expect(find.text('status:a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
