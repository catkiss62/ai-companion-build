import '../rules/rule_layer_service.dart';
import '../self/dream_store.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';
import 'creative_contract.dart';
import 'creative_store.dart';

class CreativeWorker {
  CreativeWorker(this.db, {this.clientFactory});
  final DeepSeekClient Function(Future<bool> Function() abort)? clientFactory;
  final AppDatabase db;
  static const lease = 'creative_worker_lease_until';
  static const preview = MethodChannel('ai_companion/creative_preview');

  /// One durable step at a time. No global maintenance/chat lease is held.
  Future<void> runOnce() async {
    if (!await db.brainWorkAllowed() || await db.isLocalLeaseHeld('chat_turn_lease')) return;
    if (!await db.tryAcquireLocalLease(lease, holdFor: const Duration(minutes: 5))) return;
    DeepSeekClient? client;
    try {
      final store = CreativeStore(db);
      final works = (await store.list()).where((w) => CreativeContract.active.contains(w['status']));
      if (works.isEmpty) return;
      var work = works.last;
      final fence = await db.captureBrainWorkFence(leaseKey: lease);
      if (fence == null) return;
      Future<bool> checkpoint(Map<String, dynamic> after, {Map<String, String> extra = const {}}) async {
        final ok = await store.write(work, after, extra: extra, fence: fence);
        if (ok) work = after;
        return ok;
      }
      bool current = true;
      final makeClient = clientFactory ?? ((Future<bool> Function() abort) => DeepSeekClient(abortWhen: abort));
      client = makeClient(() async {
        current = await db.brainWorkFenceCurrent(fence) &&
            jsonEncode(await store.get(work['id'] as String)) == jsonEncode(work);
        return !current;
      });
      try {
        if (work['status'] != 'checking' || (work['draft'] as String? ?? '').isEmpty) {
          final attempts = (work['attempts'] as num? ?? 0).toInt();
          if (attempts >= 3) {
            await checkpoint({...work, 'status': 'failed', 'note': '暂时没做好，草稿已保留；可继续或调整委托'});
            return;
          }
          final apiKey = await SecureConfig.instance.readApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            await checkpoint({...work, 'status': 'paused', 'note': '请先设置 DeepSeek API'});
            return;
          }
          if (!await checkpoint({...work, 'status': 'building', 'attempts': attempts + 1,
              'note': attempts == 0 ? '正在制作' : '根据试玩结果修改'})) return;
          final recent = await db.recentMessagesForPrompt(limit: 16);
          final rules = await RuleLayerService(db).resolve(latestUserText: work['brief'] as String,
            session: null, references: const [], nsfwActive: false, nsfwReferenceActive: false);
          final understanding = await DreamStore(db).prompt(freshSourceOnly: false, roleplay: false);
          final source = (work['draft'] as String? ?? '').isNotEmpty ? work['draft'] : work['current'];
          final oldHtml = source is String && source.isNotEmpty
              ? await db.getSetting('${CreativeContract.sourcePrefix}$source') : null;
          final generated = await client.jsonCompletion(
            apiKey: apiKey, endpoint: await SecureConfig.instance.readEndpoint(),
            model: DeepSeekModelProfile.fromApiName(work['model'] as String?),
            thinking: true, effort: ReasoningEffort.fromApiName(work['effort'] as String?),
            maxTokens: 32000, requestTimeout: const Duration(seconds: 180),
            usageLane: 'creative_build', usageExecutionId: '${work['id']}:$attempts',
            messages: [
              {'role': 'system', 'content': CreativeContract.instruction},
              {'role': 'user', 'content': jsonEncode({
                'commission': work['brief'],
                'character_context': CreativeContract.clip('${rules.personalityExecutionAnchor}\n${rules.layers.map((r) => '${r.title}: ${CreativeContract.clip(r.content, 1800)}').join('\n')}', 12000),
                'self_understanding': CreativeContract.clip(understanding, 3000),
                'conversation': recent.map((m) => {'role': m.role, 'content': CreativeContract.clip(m.content, 1000)}).toList(),
                'previous_html': oldHtml, 'previous_errors': work['errors'],
              })},
            ]);
          final html = generated['html'];
          if (html is! String) throw const FormatException('没有返回完整作品');
          CreativeContract.validateHtml(html);
          final checks = generated['checks'];
          if (checks is! List || checks.isEmpty || checks.length > 6 || checks.any((c) => c is! Map || c['selector'] is! String)) {
            throw const FormatException('缺少可以执行的试玩检查');
          }
          final hash = CreativeContract.hash(html);
          if (!await checkpoint({...work, 'draft': hash, 'status': 'checking',
            'title': CreativeContract.clip(generated['title'], 60),
            'intro': CreativeContract.clip(generated['intro'], 180),
            'checks': checks.map((c) => <String, String>{
              for (final k in ['click', 'selector', 'text']) k: CreativeContract.clip(c[k], 300),
            }).toList(), 'note': '正在后台试玩'},
            extra: {'${CreativeContract.sourcePrefix}$hash': html})) return;
        }
        final html = await db.getSetting('${CreativeContract.sourcePrefix}${work['draft']}');
        if (html == null) throw const FormatException('作品草稿丢失');
        final result = await preview.invokeMapMethod<String, dynamic>('preview', {
          'html': html, 'checks': work['checks'],
        });
        if (result?['ok'] != true) {
          await checkpoint({...work, 'status': 'queued', 'errors': result?['errors'] ?? ['预览未完成'],
            'note': '试玩发现问题，准备修复'});
          return;
        }
        var cover = '';
        final path = result?['screenshot'];
        if (path is String) {
          final file = File(path);
          if (await file.exists() && await file.length() < 180000) cover = base64Encode(await file.readAsBytes());
        }
        final versions = <String>{work['draft'] as String,
          ...(work['versions'] as List? ?? []).whereType<String>()}.take(3).toList();
        if (await checkpoint({...work, 'current': work['draft'], 'draft': '',
          'versions': versions, 'status': 'ready', 'note': '做好了，可以打开试玩',
          'cover': cover, 'errors': <Object?>[], 'updated': DateTime.now().millisecondsSinceEpoch})) {
          await store.collectUnusedSources();
        }
      } catch (error) {
        if (current) await checkpoint({...work, 'status': 'failed',
          'note': '制作中断，草稿已保留；可继续重试',
          'errors': [CreativeContract.clip(error.runtimeType, 100)]});
      }
    } finally {
      client?.close();
      await db.releaseLocalLease(lease);
    }
  }
}
