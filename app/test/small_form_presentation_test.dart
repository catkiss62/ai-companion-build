import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final voice in [false, true]) {
    test(
      'final Q reply holds its portrait through ${voice ? 'native audio' : 'text'}',
      () async {
        const system = MethodChannel('ai_companion/system');
        const speech = MethodChannel('ai_companion/tts');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final directory = await Directory.systemTemp.createTemp(
          'small-form-presentation-',
        );
        final paths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(directory.path);
        FlutterSecureStorage.setMockInitialValues({
          'deepseek_api_key': 'fixture',
        });
        messenger.setMockMethodCallHandler(
          system,
          (call) async =>
              call.method == 'runtimeProcessEpoch' ? 'fixture-process' : null,
        );
        final audioDraining = Completer<void>();
        final audioFinished = Completer<void>();
        final speechCalls = <String>[];
        messenger.setMockMethodCallHandler(speech, (call) async {
          speechCalls.add(call.method);
          switch (call.method) {
            case 'claimPlayback':
              return 1;
            case 'initialize':
            case 'prepareLanguage':
            case 'configureAutoAffinity':
            case 'status':
              return {'available': true, 'initialized': true};
            case 'generate':
              return Uint8List.fromList([1, 2, 3]);
            case 'beginAudioStream':
            case 'enqueueAudio':
              return true;
            case 'finishAudioStream':
              audioDraining.complete();
              await audioFinished.future;
              return true;
            default:
              return null;
          }
        });
        final db = await AppDatabase.createForTesting(databaseFactoryFfi);
        final client = DeepSeekClient(
          streamClientFactory: () => MockClient((_) async {
            final delta = jsonEncode({
              'choices': [
                {
                  'delta': {'content': '<emotion>正常</emotion>\n「唔，这句还没说完。」'},
                  'finish_reason': 'stop',
                },
              ],
            });
            return http.Response.bytes(
              utf8.encode('data: $delta\n\ndata: [DONE]\n\n'),
              200,
              headers: {'content-type': 'text/event-stream; charset=utf-8'},
            );
          }),
        );
        final chat = ChatController(
          db: db,
          client: client,
          secureConfig: SecureConfig.forTesting(const FlutterSecureStorage()),
          externalRecoveryOrchestrator: true,
        );
        try {
          await db.setSettingsAtomically({
            PlayfulFormState.settingKey: const PlayfulFormState(
              qForm: true,
              heat: 6,
            ).encode(),
            'tts_enabled': voice ? '1' : '0',
            'auto_tts': voice ? '1' : '0',
            'tts_reading_scope': 'full_text',
            'emotion_sound_enabled': '0',
            'auto_memory': '0',
            'daily_continuity_enabled': '0',
          });
          expect(
            await chat.sendText('继续说吧').timeout(const Duration(seconds: 20)),
            isTrue,
          );
          final reply = chat.latestDialogueMessage!;
          final state = await PlayfulFormStore(db).load();
          expect(chat.error, isNull);
          expect(state.qForm, isFalse);
          expect(reply.formContext.form, 'q');
          expect(reply.formContext.afterForm, 'normal');
          if (voice) {
            await audioDraining.future.timeout(
              const Duration(seconds: 5),
              onTimeout: () =>
                  fail('Native speech did not finish queuing: $speechCalls'),
            );
          }
          expect(
            chat.holdsSmallForm(state.manualRevision, presentingText: !voice),
            isTrue,
          );
          chat.smallFormTextPresented(reply.id);
          if (voice) {
            expect(
              chat.holdsSmallForm(state.manualRevision, presentingText: false),
              isTrue,
            );
            final released = Completer<void>();
            chat.addListener(() {
              if (!released.isCompleted &&
                  !chat.holdsSmallForm(
                    state.manualRevision,
                    presentingText: false,
                  )) {
                released.complete();
              }
            });
            audioFinished.complete();
            await released.future.timeout(const Duration(seconds: 5));
          }
          expect(
            chat.holdsSmallForm(state.manualRevision, presentingText: true),
            isFalse,
          );
        } finally {
          if (!audioFinished.isCompleted) audioFinished.complete();
          await chat.stopSpeech();
          chat.dispose();
          await db.setSetting('active_brain', '0');
          // Let the scheduled post-turn drain release its local database work.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          client.close();
          await db.closeForTesting();
          messenger.setMockMethodCallHandler(system, null);
          messenger.setMockMethodCallHandler(speech, null);
          PathProviderPlatform.instance = paths;
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
