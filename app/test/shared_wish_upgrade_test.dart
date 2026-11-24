import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/background_cost_policy.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_parts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('an old full list archives only confirmed solo goals and survives restore', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    await db.setSetting(BackgroundCostPolicy.enabledKey, '0');
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    CompanionWish old(String id, String goal, String route) => CompanionWish(
      id: id, goal: goal, reason: '旧记录', route: route, criterion: '原来的完成条件',
      gameId: route == 'game' ? 'arcade' : '', createdAt: yesterday, updatedAt: yesterday,
    );
    final solo = old('a', '想自己在街机厅赢一次', 'game');
    final joint = old('b', '想和主人再玩一次街机', 'game');
    final user = old('c', '想看看你提到的小猫', 'user');
    final unclear = old('d', '想再看一眼海边的落日', 'aspiration');
    final completed = old('e', '以前完成的一件事', 'game').copyWith(state: 'completed');
    final held = old('f', '我先放一放这个愿望', 'game').copyWith(state: 'paused', manualHold: true);
    final all = [solo,joint,user,unclear,completed,held];
    final store = WishStore(db);
    await store.save(all, expected: '', fence: (await db.captureBrainWorkFence())!);
    await db.insertMessage(ChatMessage(id:'fact',role:'user',content:'今天聊起那只猫',createdAt:now));
    final engine = WishEngine(db,reviewer:(material) async {
      expect(material['can_generate'],false);
      return {'solo_archive':[
        for(final w in [solo,user,completed,held]) {'id':w.id,'quote':w.goal,'solo':true},
        {'id':joint.id,'quote':joint.goal,'solo':true},
      ]};
    });
    expect(await engine.maybeRefresh(now:now),true);
    final beforeRestore = await db.getSetting(WishStore.stateKey);
    final backup = jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;
    await db.importAll(backup);
    await store.initialize();
    expect(await db.getSetting(WishStore.stateKey),beforeRestore);
    final saved = await store.load();
    expect(saved.first.state,'archived_solo');
    expect(saved.first.goal,solo.goal);
    expect(saved.skip(1).map((w)=>w.toJson()), all.skip(1).map((w)=>w.toJson()));
    expect(jsonDecode((await db.getSetting(WishStore.activeKey))!),hasLength(3));
    expect(await store.setUserState(solo.id,'active'),true);
    expect(await store.setUserState(held.id,'active'),false); // Four active.
    final restored = (await store.load()).first;
    expect(restored.protectSoloArchive,true);
    final afterReview = WishPolicy.apply(wishes:[CompanionWish.fromJson(restored
        .copyWith(lastIntentionSource:'new_evidence').toJson())],
      payload:{'solo_archive':[{'id':restored.id,'quote':restored.goal,'solo':true}]},
      evidence:[], catalogIds:{}, now:now, canGenerate:false);
    expect(afterReview.single.active,true);
  });

  test('QQ output removes only projected native faces',() {
    expect(QqReplyParts.cleanFaces('😄[QQ表情：微笑] [备注]'),'😄 [备注]');
    expect(QqReplyParts.cleanFaces('[QQ表情]'),'');
  });
}
