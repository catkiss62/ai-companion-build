import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/settings/qq_group_identity_page.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_group_binding.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_display_names.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_readonly_context.dart';
import 'package:ai_companion_localfirst/core/memory/memory_brain.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_group_participation.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_private_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_runtime.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqPrivateConfig config;
  const group='fixture-group',member='MEMBER_OPENID_FROM_PLATFORM';
  setUp(()async{
    FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);
    config=const QqPrivateConfig(appId:'12345',secret:'fixture-only',namespace:'qq138',owner:'owner');
    await config.save();await QqPrivateConfig.bind(config.namespace,config.owner);
    await db.ensureStateLineageId();
    await QqOptions(namespace:config.namespace).save(db:db);
    await store.discover(await store.capture(),QqRuntime.scope(config),'group',group);
  });
  tearDown(()async=>db.closeForTesting());
  Future<void> append(String sender,String text,{String target=group})async{
    await store.append(fence:await store.capture(),scope:QqRuntime.scope(config),kind:'group',target:target,
      platformId:'fixture-$sender-$target',sender:sender,text:text,observedAt:1000,receivedAt:1000);
  }
  Future<void> page(WidgetTester tester)async{
    await tester.pumpWidget(MaterialApp(home:QqGroupIdentityPage(config:config,group:group,database:db)));
    for(var attempt=0;attempt<150 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;attempt++) {
      await Future<void>.delayed(const Duration(milliseconds:20));await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator),findsNothing);
    await tester.pumpAndSettle();
  }
  Future<void> saved(WidgetTester tester)async{
    final notice=find.text('已保存，之后本群会按平台身份认出你。');
    for(var attempt=0;attempt<150 && notice.evaluate().isEmpty;attempt++) {
      await Future<void>.delayed(const Duration(milliseconds:20));await tester.pump();
    }
    expect(notice,findsOneWidget);
  }

  test('close direct and continuing answers retain their common participation direction',(){
    expect(QqGroupParticipation.resolve({'direct':.49,'continuing':.49,'join':.01,'watch':.01}),'direct');
    expect(QqGroupParticipation.resolve({'direct':.25,'continuing':.26,'join':.48,'watch':.01}),'continuing');
  });
  test('close unrelated directions never fall through to a third low-probability route',(){
    expect(QqGroupParticipation.resolve({'direct':.01,'continuing':.01,'join':.49,'watch':.49}),'join');
    expect(QqGroupParticipation.resolve({'direct':.01,'continuing':.01,'join':.48,'watch':.50}),'watch');
    expect(QqGroupParticipation.resolve({'join':.7}),'join');
    expect(()=>QqGroupParticipation.resolve({'direct':0,'join':0,'watch':0}),throwsFormatException);
  });
  test('physical App can preset a known OpenID without any public identity command',()async{
    expect(await QqGroupBinding.confirmLocal(config,group,member,requireObserved:false,db:db),true);
    expect((await QqOptions.read()).ownerMembers[group],member);
    expect(await QqGroupBinding.requests(config),isEmpty);
    expect(await (await db.database).query('qq_archive'),isEmpty);
  });
  test('QQ numbers and nicknames cannot silently become identity credentials',()async{
    for(final value in ['123456789','我的群昵称','小鲸鱼的主人','']) {
      expect(await QqGroupBinding.confirmLocal(config,group,value,requireObserved:false,db:db),false);
    }
    expect((await QqOptions.read()).ownerMembers,isEmpty);
  });
  test('observed selection is group-scoped and does not rewrite historical speaker ownership',()async{
    await append(member,'这是我正常说的一句话');await append('peer','我也改成一样的昵称');
    final rows=await QqGroupBinding.members(config,group,db:db);expect(rows.length,2);
    expect((await QqOptions.read()).ownerMembers,isEmpty);
    await store.discover(await store.capture(),QqRuntime.scope(config),'group','other');
    expect(await QqGroupBinding.confirmLocal(config,'other',member,db:db),false);
    expect(await QqGroupBinding.confirmLocal(config,group,member,db:db),true);
    expect((await QqOptions.read()).ownerMembers[group],member);
    final raw=await (await db.database).query('qq_archive');expect(raw.every((r)=>r['owner']==0),true);
    expect((await QqPrivateConfig.read()).owner,'owner');
  });
  test('rebinding rejects stale local confirmations and removing one group preserves the others',()async{
    await QqOptions.update((fresh)=>fresh.copy(owners:const {group:member,'other':'OTHER_MEMBER_OPENID'}),namespace:config.namespace,db:db);
    expect(await QqGroupBinding.confirmLocal(config,group,null,db:db),true);
    expect((await QqOptions.read()).ownerMembers,{'other':'OTHER_MEMBER_OPENID'});
    await const QqPrivateConfig(appId:'12345',secret:'replacement',namespace:'replacement').save();
    expect(await QqGroupBinding.confirmLocal(config,group,member,requireObserved:false,db:db),false);
    expect(await QqGroupBinding.members(config,group,db:db),isEmpty);
    expect((await QqOptions.read()).ownerMembers,isEmpty);
  });

  test('recent group and private raw are available in App and private QQ without exact keywords',()async{
    final at=DateTime.now().millisecondsSinceEpoch;final fence=await store.capture();final scope=QqRuntime.scope(config);
    for(final kind in ['group','private']) {
      await store.append(fence:fence,scope:scope,kind:kind,target:kind=='group'?group:'owner',platformId:kind,
        sender:kind=='group'?'peer':'owner',owner:kind=='private',text:kind=='group'?'大家决定种一盆铃兰':'我刚刚喝了柠檬水',observedAt:at,receivedAt:at);
    }
    final app=(await MemoryBrain(db).buildContext('现在怎么样')).qqContext;
    final qq=await QqReadOnlyContext(await db.database).build('现在怎么样',qqScope:scope);
    for(final text in [app,qq]) {expect(text,contains('铃兰'));expect(text,contains('柠檬水'));expect(text,contains('GROUP_MEMBER_HISTORY'));}
  });
  test('an explicit QQ group query is not crowded out by newer private messages',()async{
    final at=DateTime.now().subtract(const Duration(hours:3)).millisecondsSinceEpoch;
    final fence=await store.capture();final scope=QqRuntime.scope(config);
    await store.append(fence:fence,scope:scope,kind:'group',target:group,platformId:'older-group',sender:'peer',
      text:'群友在讨论紫色风铃',observedAt:at,receivedAt:at);
    for(var i=1;i<=20;i++) {await store.append(fence:fence,scope:scope,kind:'private',target:'owner',platformId:'private-$i',
      sender:'owner',owner:true,text:'后来单聊无关话题$i',observedAt:at+i,receivedAt:at+i);}
    final app=(await MemoryBrain(db).buildContext('你能看到QQ群的聊天记录吗')).qqContext;
    final qq=await QqReadOnlyContext(await db.database).build('QQ群刚才说了什么',qqScope:scope);
    for(final text in [app,qq]) {expect(text,contains('紫色风铃'));expect(text,isNot(contains('后来单聊')));}
  });
  test('recent projection still honors namespace, high-water and context reset',()async{
    final at=DateTime.now().millisecondsSinceEpoch;final scope=QqRuntime.scope(config);final fence=await store.capture();
    final first=await store.append(fence:fence,scope:scope,kind:'group',target:group,platformId:'before',sender:'peer',text:'旧批',observedAt:at,receivedAt:at);
    await store.append(fence:fence,scope:scope,kind:'group',target:group,platformId:'after',sender:'peer',text:'未来批',observedAt:at+1,receivedAt:at+1);
    await store.append(fence:fence,scope:'other-scope',kind:'group',target:group,platformId:'other',sender:'peer',text:'其他账号',observedAt:at+1,receivedAt:at+1);
    final reader=QqArchiveReader(await db.database);
    final text=await reader.privateContext('现在呢',scope:scope,through:first);
    expect(text,contains('旧批'));expect(text,isNot(contains('未来批')));expect(text,isNot(contains('其他账号')));
    expect(await reader.privateContext('群聊',scope:scope,resetAt:at+2),'');
  });
  test('Chinese display names are scoped presentation data and cannot recognize the owner',()async{
    final sql=await db.database;final scope=QqRuntime.scope(config);final before=await store.capture();
    await sql.transaction((txn)=>QqDisplayNames.write(txn,scope,group:group,name:'好友闲聊群',member:member,nickname:'群友小明'));
    final names=await QqDisplayNames.read(sql,scope);
    expect(names.group(group),'好友闲聊群');expect(names.member(group,member),'群友小明');
    expect((await QqDisplayNames.read(sql,'other')).groups,isEmpty);
    expect((await QqOptions.read()).ownerMembers,isEmpty);expect(await store.current(before),true);
  });
  test('archive UI renders Chinese text and image observations instead of technical JSON',()async{
    final scope=QqRuntime.scope(config);final seq=await store.append(fence:await store.capture(),scope:scope,kind:'group',target:group,
      platformId:'display',sender:member,text:'中文消息 <@SOME_OPENID> 看图',observedAt:1000,receivedAt:1000,images:1,replyTo:'opaque-message-id');
    final sql=await db.database;final image=(await store.images(seq!)).single;
    await store.observation(await store.capture(),image['id'] as String,'viewed','一只可爱的猫','fixture');
    final row=(await sql.query('qq_archive',where:'seq=?',whereArgs:[seq])).single;
    final reader=QqArchiveReader(sql);final ui=await reader.display(row,speaker:'群友小明');
    expect(ui,contains('群友小明'));expect(ui,contains('中文消息 @群成员 看图'));expect(ui,contains('一只可爱的猫'));
    for(final opaque in ['SOME_OPENID','opaque-message-id','provenance_role','conversation_id']) {expect(ui,isNot(contains(opaque)));}
    expect(await reader.render(row),contains('GROUP_MEMBER_HISTORY'));
  });

  testWidgets('selecting normal speech requires explicit App confirmation before binding',(tester)async{
    await tester.runAsync(()async{
    await append(member,'这是我在群里正常说的话');await page(tester);
    await tester.tap(find.text('这是我在群里正常说的话'));await tester.pumpAndSettle();
    expect((await QqOptions.read()).ownerMembers,isEmpty);
    await tester.ensureVisible(find.text('确认本人身份'));await tester.tap(find.text('确认本人身份'));await tester.pumpAndSettle();
    expect(find.text('确认这个群成员是你本人？'),findsOneWidget);
    expect((await QqOptions.read()).ownerMembers,isEmpty);
    await tester.tap(find.text('确认是我'));await saved(tester);await tester.pumpAndSettle();
    expect((await QqOptions.read()).ownerMembers[group],member);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
    });
  });
  testWidgets('manual preset UI rejects a QQ number and accepts a known platform identity',(tester)async{
    await tester.runAsync(()async{
    await page(tester);await tester.tap(find.byType(SwitchListTile));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'123456789');
    await tester.ensureVisible(find.text('确认本人身份'));await tester.tap(find.text('确认本人身份'));await tester.pumpAndSettle();
    expect((await QqOptions.read()).ownerMembers,isEmpty);expect(find.byType(AlertDialog),findsNothing);
    await tester.enterText(find.byType(TextField),member);
    await tester.ensureVisible(find.text('确认本人身份'));await tester.tap(find.text('确认本人身份'));await tester.pumpAndSettle();
    await tester.tap(find.text('确认是我'));await saved(tester);await tester.pumpAndSettle();
    expect((await QqOptions.read()).ownerMembers[group],member);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
    });
  });
}
