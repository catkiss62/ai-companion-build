import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/features/chat/chat_image_send_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, scale, qwenConfigured) in [
    (320.0, 2.0, true),
    (360.0, 1.0, false),
    (412.0, 1.3, true),
  ]) {
    testWidgets('vision actions fit one row at $width dp, text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync();
      addTearDown(() => directory.deleteSync(recursive: true));
      final preview = File('${directory.path}/preview.png')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aVf8AAAAASUVORK5CYII=',
          ),
        );
      final draft = PreparedImageAttachment(
        id: 'image',
        originalFile: preview,
        thumbnailFile: preview,
        originalExtension: 'png',
        mimeType: 'image/png',
        byteSize: 1,
        width: 1,
        height: 1,
        source: 'gallery',
        createdAt: DateTime(2026),
      );
      ImageVisionRoute? route;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    route = await showDialog<ImageVisionRoute>(
                      context: context,
                      builder: (_) => ChatImageSendDialog(
                        selected: [draft],
                        caption: '',
                        qwenConfigured: qwenConfigured,
                        onCaptionChanged: (_) {},
                      ),
                    ),
                child: const Text('选图'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('选图'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cancel = tester.getRect(find.widgetWithText(TextButton, '取消'));
      final ds = tester.getRect(find.widgetWithText(OutlinedButton, 'DS识图'));
      final qwen = tester.getRect(find.widgetWithText(FilledButton, '千问识图'));
      expect(cancel.center.dy, closeTo(ds.center.dy, 0.01));
      expect(ds.center.dy, closeTo(qwen.center.dy, 0.01));
      expect(cancel.right, lessThan(ds.left));
      expect(ds.right, lessThan(qwen.left));
      expect(ds.width, closeTo(qwen.width, 0.01));
      final description = find.text('这些图片作为一条消息发送，识别完成后一起回复。');
      final hint = find.text(
        qwenConfigured ? '千问未识别成功时使用 DS 识图。' : '填写千问视觉 API Key 后可使用千问识图。',
      );
      expect(tester.getTopLeft(hint).dx, tester.getTopLeft(description).dx);
      if (!qwenConfigured) {
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      }
      await tester.tap(find.text(qwenConfigured ? '千问识图' : 'DS识图'));
      await tester.pump();
      expect(
        route,
        qwenConfigured ? ImageVisionRoute.qwen : ImageVisionRoute.first,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
