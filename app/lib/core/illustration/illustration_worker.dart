import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai/deepseek_client.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/secure_config.dart';
import '../storage/shared_media_lock.dart';
import 'illustration_client.dart';
import 'illustration_job.dart';
import 'illustration_planner.dart';
import 'illustration_prompt.dart';

class IllustrationWorker {
  IllustrationWorker(
    this.db, {
    SecureConfig? secure,
    IllustrationClient? client,
  }) : secure = secure ?? SecureConfig.instance,
       client = client ?? IllustrationClient();

  final AppDatabase db;
  final SecureConfig secure;
  final IllustrationClient client;
  static const _lease = 'illustration_worker_lease_until';

  void start() {
    unawaited(
      drainOne().catchError((Object _) {
        // Durable queue stays available for the next recovery pass.
      }),
    );
  }

  Future<void> drainOne() async {
    final sql = await db.database;
    final pending = await sql.query(
      'settings',
      columns: ['key', 'value'],
      where: 'key LIKE ? AND value LIKE ?',
      whereArgs: ['${IllustrationJob.keyPrefix}%', '{"state":"queued",%'],
      orderBy: 'key',
      limit: 1,
    );
    if (pending.isEmpty || !await db.brainWorkAllowed()) return;
    if (!await db.tryAcquireLocalLease(
      _lease,
      // Two image requests plus planning and local storage must fit the lease.
      holdFor: client.requestTimeout * 2 + const Duration(minutes: 2),
    ))
      return;
    try {
      final key = pending.single['key'] as String;
      final fence = await db.captureBrainWorkFence(
        leaseKey: _lease,
        settingKeys: [
          IllustrationJob.configRevisionKey,
          if (key.startsWith('${IllustrationJob.keyPrefix}diary:'))
            'simulated_phone_switch_changed_at',
        ],
      );
      if (fence == null) return;
      final state = IllustrationJob.decode(await db.getSetting(key));
      if (state == null || state['state'] != 'queued') return;
      await _process(key, state, fence);
    } finally {
      await db.releaseLocalLease(_lease);
    }
  }

  Future<void> _process(
    String key,
    Map<String, dynamic> state,
    BrainWorkFence fence,
  ) async {
    final source = IllustrationSource.values
        .where((s) => s.name == state['source'])
        .firstOrNull;
    final ownerId = state['owner_id'];
    if (source == null ||
        ownerId is! String ||
        ownerId.isEmpty ||
        key != IllustrationJob.keyFor(source, ownerId))
      return;
    final diary = source == IllustrationSource.diary;
    Future<bool> current() => db.brainWorkFenceCurrent(fence);
    Future<bool> write() =>
        db.setSettingsAtomically({key: jsonEncode(state)}, workFence: fence);
    Future<void> fail(String error) async {
      state['state'] = 'failed';
      state['error'] = error;
      state.remove('intent');
      state.remove('context');
      if (await write() && state['received'] == true) {
        try {
          await _discardFile(await _stageFile(key, state['at']));
        } catch (_) {
          /* A failure report does not depend on temp cleanup. */
        }
      }
    }

    final connection = await secure.readIllustration();
    final admitted =
        connection.active &&
        (source != IllustrationSource.proactive || connection.autonomous) &&
        (state['autonomous'] != true || connection.autonomous) &&
        (!diary ||
            (connection.diary &&
                await db.getSetting('simulated_phone_enabled') != '0'));
    if (!admitted) {
      await fail(
        connection.enabled && !connection.configured
            ? 'configuration'
            : 'disabled',
      );
      return;
    }
    if (diary) {
      final entries = await db.getSetting(IllustrationJob.diaryEntriesKey);
      if (!IllustrationJob.diaryContains(entries, ownerId)) {
        await fail('source_missing');
        return;
      }
    } else if (await db.messageById(ownerId) == null) {
      await fail('source_missing');
      return;
    }

    final storedPlan = state['plan'];
    var plan = storedPlan is Map<String, dynamic>
        ? IllustrationPlan.fromJson(storedPlan)
        : null;
    if (plan == null) {
      // Persist dispatch before the optional planning request. An interrupted
      // planner is not endlessly retried by the heartbeat.
      if (state['planning_started'] == true) {
        await fail('planning');
        return;
      }
      state['planning_started'] = true;
      if (!await write()) return;
      plan = await _plan(state, source, current);
      if (!await current()) return;
      if (plan == null) {
        await fail('planning');
        return;
      }
      state['plan'] = plan.toJson();
      if (!await write()) return;
    }

    final chosenPlan = plan;
    final prompt = IllustrationPrompt.compose(chosenPlan);
    final File stage;
    try {
      stage = await _stageFile(key, state['at']);
      await stage.parent.create(recursive: true);
    } catch (_) {
      await fail('storage_unavailable');
      return;
    }
    if (!await stage.exists() && state['received'] == true) {
      await fail('storage');
      return;
    }
    var attempts = (state['attempts'] as num?)?.toInt() ?? 0;
    var error = state['last_request_error'] as String? ?? 'network';
    final seed =
        (state['seed'] as num?)?.toInt() ?? IllustrationClient.newSeed();
    while (!await stage.exists() && attempts < 2) {
      state['attempts'] = ++attempts;
      state['seed'] = seed;
      if (!await write() || !await current()) return;
      IllustrationBytes image;
      try {
        image = await client.generate(connection, prompt, seed: seed);
      } on IllustrationFailure catch (failure) {
        if (!await current()) return;
        error = failure.code;
        state['last_request_error'] = error;
        if (!await write()) return;
        continue;
      }
      // Reserve the fact that we received bytes before any local write. A
      // local failure cannot turn into a second billed generation.
      state['received'] = true;
      if (!await write()) return;
      final writing = File('${stage.path}.writing');
      try {
        await writing.writeAsBytes(image.bytes, flush: true);
        await writing.rename(stage.path);
      } on FileSystemException {
        await fail('storage');
        return;
      } finally {
        await _discardFile(writing);
      }
    }
    if (!await stage.exists()) {
      await fail(error);
      return;
    }
    if (!await current()) return;
    var committed = false;
    try {
      final bytes = await stage.readAsBytes();
      final type = IllustrationClient.imageType(bytes);
      if (type == null) throw const IllustrationFailure('storage');
      final storage = MessageAttachmentStorage(db: db);
      final draft = await storage.prepareImageBytes(
        bytes: bytes,
        source: 'assistant_illustration:${source.name}',
        mimeType: type,
      );
      try {
        committed = await SharedMediaLock.run(() async {
          if (!await current()) return false;
          final attachment = await storage.commitDraft(
            draft,
            messageId: ownerId,
          );
          final terminal = <String, Object?>{
            'state': 'completed',
            'source': source.name,
            'owner_id': ownerId,
            'at': state['at'],
            'attempts': attempts,
            'seed': seed,
            'description': chosenPlan.description,
            'style': chosenPlan.style,
            'depicts_companion': chosenPlan.depictsCompanion,
            'positive': prompt.positive,
            'negative': prompt.negative,
            'blob_id': attachment.blobId,
          };
          return db.commitIllustration(
            source: source,
            ownerId: ownerId,
            attachment: attachment,
            description: chosenPlan.description,
            depictsCompanion: chosenPlan.depictsCompanion,
            terminal: jsonEncode(terminal),
            fence: fence,
          );
        }, db: db);
        if (committed) await _discardFile(stage);
      } finally {
        await storage.discardDraft(draft);
      }
    } catch (_) {
      if (committed || !await current()) return;
      final failures = ((state['storage_failures'] as num?)?.toInt() ?? 0) + 1;
      state['storage_failures'] = failures;
      if (failures < 2) {
        await write(); // Next wake retries local binding only.
      } else {
        await fail('storage');
      }
    }
  }

  static Future<File> _stageFile(String key, Object? at) async {
    final support = await getApplicationSupportDirectory();
    final hash = sha256.convert(utf8.encode('$key:$at'));
    return File(p.join(support.path, 'illustration_pending', '$hash.image'));
  }

  static Future<void> _discardFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup cannot roll a committed image or a terminal failure back.
    }
  }

  Future<IllustrationPlan?> _plan(
    Map<String, dynamic> state,
    IllustrationSource source,
    Future<bool> Function() current,
  ) async {
    final planner = DeepSeekClient(abortWhen: () async => !await current());
    try {
      return await IllustrationPlanner.request(
        db: db,
        secure: secure,
        client: planner,
        source: source.name,
        intent: state['intent'] as String? ?? '',
        context: state['context'] as String? ?? '',
        current: current,
      );
    } catch (_) {
      return null;
    } finally {
      planner.close();
    }
  }
}
