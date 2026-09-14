import 'dart:async';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _BlockingClient extends http.BaseClient {
  final Completer<http.StreamedResponse> _response =
      Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _response.future;

  @override
  void close() {
    if (!_response.isCompleted) {
      _response.completeError(StateError('client_closed'));
    }
    super.close();
  }
}

void main() {
  test('streaming provider wait closes immediately when Stop cancels the turn',
      () async {
    final token = GenerationCancellationToken();
    final client = DeepSeekClient(
      streamClientFactory: _BlockingClient.new,
    );

    final request = client
        .streamChat(
          apiKey: 'test',
          model: DeepSeekModelProfile.flash,
          effort: ReasoningEffort.high,
          messages: const <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': 'test'},
          ],
          cancellationToken: token,
        )
        .drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    token.cancel();

    await expectLater(
      request,
      throwsA(isA<GenerationCancelledByUserException>()),
    );
    client.close();
  });

  test('JSON provider wait closes immediately when Stop cancels the turn',
      () async {
    final token = GenerationCancellationToken();
    final client = DeepSeekClient(
      jsonClientFactory: _BlockingClient.new,
    );

    final request = client.jsonCompletion(
      apiKey: 'test',
      model: DeepSeekModelProfile.flash,
      messages: const <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': 'test'},
      ],
      cancellationToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    token.cancel();

    await expectLater(
      request,
      throwsA(isA<GenerationCancelledByUserException>()),
    );
    client.close();
  });

  test('background provider wait stops when transfer freeze closes the gate',
      () async {
    var frozen = false;
    final client = DeepSeekClient(
      jsonClientFactory: _BlockingClient.new,
      abortWhen: () async => frozen,
    );

    final request = client.jsonCompletion(
      apiKey: 'test',
      model: DeepSeekModelProfile.flash,
      messages: const <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': 'test'},
      ],
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    frozen = true;

    await expectLater(
      request.timeout(const Duration(seconds: 2)),
      throwsA(isA<GenerationSuspendedByRuntimeGateException>()),
    );
    client.close();
  });

  test('durable Stop and transfer freeze use cross-runtime fences', () {
    final runner =
        File('lib/core/ai/durable_generation_runner.dart').readAsStringSync();
    final background = File('lib/background_main.dart').readAsStringSync();
    final database =
        File('lib/core/database/app_database.dart').readAsStringSync();
    final transfer =
        File('lib/features/transfer/transfer_page.dart').readAsStringSync();
    final chat = File('lib/features/chat/chat_controller.dart').readAsStringSync();

    expect(runner, contains("latest?.status == 'cancelled_by_user'"));
    expect(runner, contains('effectiveCancellation.cancel()'));
    expect(background, contains('abortWhen:'));
    expect(background, contains('!await db.brainWorkAllowed()'));
    expect(database, contains('Future<String> acquireTransferFreeze'));
    expect(database, contains('Future<bool> releaseTransferFreeze'));
    expect(database, contains("if (owner != token) return false"));
    expect(database, contains("key == 'transfer_lock' && value != '1'"));
    expect(database, contains('if (owner.isNotEmpty) return'));
    expect(transfer, contains("purpose: 'backup_export'"));
    expect(transfer, contains("purpose: 'backup_restore'"));
    expect(transfer, contains('正在整理聊天、记忆与媒体并生成备份文件'));
    expect(transfer, contains('正在打开系统保存位置'));
    final backupStart = transfer.indexOf('Future<void> _backupExport()');
    final backupEnd = transfer.indexOf('Future<void> _backupImport()', backupStart);
    final backupExport = transfer.substring(backupStart, backupEnd);
    expect(backupExport, isNot(contains('inspectBundle(bundle.filePath)')));
    expect(chat, contains("db.isLocalLeaseHeld('chat_turn_lease')"));
    expect(chat, contains('停止请求已经写入，但旧回复连接尚未退出'));
    expect(chat, contains('!await (db ?? AppDatabase.instance).brainWorkAllowed()'));
    expect(transfer, isNot(contains(
      "_append('保存备份失败：\$e。本机数据和主设备状态没有改变。');\n"
      "    } finally {\n"
      "      if (bundle != null) await _deleteCachePath(bundle.filePath);\n"
      "      await db.setSetting('transfer_lock', '0');",
    )));
  });
}
