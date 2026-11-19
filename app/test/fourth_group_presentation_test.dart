import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/models/chat_message.dart';
import '../lib/core/models/message_attachment.dart';
import '../lib/features/chat/chat_controller.dart';
import '../lib/features/phone/simulated_phone_page.dart';

void main() {
  test(
    'cross-engine comparison notices earlier attachments, content changes and order',
    () {
      final at = DateTime(2026);
      MessageAttachment image(String id) => MessageAttachment(
        id: id,
        messageId: 'a',
        kind: 'image',
        originalPath: id,
        thumbnailPath: id,
        mimeType: 'image/png',
        byteSize: 1,
        width: 1,
        height: 1,
        source: 'chat',
        createdAt: at,
      );
      ChatMessage row(String id, List<MessageAttachment> items) => ChatMessage(
        id: id,
        role: 'assistant',
        content: '相同正文',
        createdAt: at,
        attachments: items,
      );
      final before = [
        row('a', [image('x'), image('y')]),
        row('b', []),
      ];
      bool matches(List<MessageAttachment> items) =>
          ChatController.sameExternalMessages(before, [
            row('a', items),
            row('b', []),
          ]);
      expect(matches([image('x'), image('y')]), true);
      expect(matches([image('y'), image('x')]), false);
      expect(
        matches([image('x').copyWith(visionSummary: '已识别'), image('y')]),
        false,
      );
      expect(matches([image('x'), image('y'), image('z')]), false);
    },
  );

  testWidgets(
    'diary opens the original list and both lists offer a calendar action',
    (tester) async {
      for (final page in [
        const DiaryPage(entries: []),
        const NotesPage(entries: []),
      ]) {
        await tester.pumpWidget(MaterialApp(home: page));
        expect(find.byType(PhoneCalendarPage), findsNothing);
        expect(find.byIcon(Icons.calendar_month), findsOneWidget);
        if (page is DiaryPage) expect(find.text('日记还没有写下来'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'transparent overlays keep the visual stage visible, an opaque page covers it',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      bool visible = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Builder(
            builder: (context) {
              visible = TickerMode.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      Route<void> cover(bool opaque) => PageRouteBuilder<void>(
        opaque: opaque,
        pageBuilder: (_, __, ___) => const SizedBox(),
      );
      nav.currentState!.push(cover(false));
      await tester.pumpAndSettle();
      expect(visible, true);
      nav.currentState!.push(cover(true));
      await tester.pumpAndSettle();
      expect(visible, false);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(visible, true);
    },
  );
}
