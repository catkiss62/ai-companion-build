import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_echo.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'fixture-only');
  int uploads=0;int? ttl=300;
  @override Future<QqMediaUpload> uploadMedia({required bool group,required String target,required Uint8List bytes,
    required String filename,required int fileType,required Future<bool> Function() current})async {
    expect(await current(),true);expect(fileType,1);expect(group,true);expect(filename,'echo.gif');
    uploads++;return QqMediaUpload('temporary-$uploads',ttl:ttl);
  }
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqEchoService echoes;late int now;var serial=0;
  setUp(()async{db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);echoes=QqEchoService(store);now=DateTime.now().millisecondsSinceEpoch;serial=0;});
  tearDown(()async{echoes.clear();await db.closeForTesting();});
  Future<QqBatch> seen(String sender,{String group='a',String hash='same-pixels',int size=3,String role='user'})async {
    final cid=QqStore.conversationId('echo-fixture','group',group);
    final seq=(await store.append(fence:await store.capture(),scope:'echo-fixture',kind:'group',target:group,platformId:'m${++serial}',
      sender:sender,role:role,text:'',images:1,observedAt:now,receivedAt:now))!;
    final b=(await store.claim(await store.capture(conversationId:cid),cid,seq,now))!;
    final image=(await store.images(seq)).single;
    echoes.remember(b,b.rows.single,image,Uint8List(size),'image/gif',hash,now);
    await store.observation(b.fence,image['id'] as String,'viewed','一张正在眨眼的表情图','vision:$hash');
    return b;
  }
  test('one sender and identical platform replay cannot create a multi-person echo',()async {
    final a=await seen('peer');expect(await echoes.candidate(a,now),isNull);echoes.release(a);
    final b=await seen('peer');expect(await echoes.candidate(b,now),isNull);
    final duplicate=await store.append(fence:await store.capture(),scope:'echo-fixture',kind:'group',target:'a',platformId:'m2',
      sender:'other',text:'',images:1,observedAt:now,receivedAt:now);
    expect(duplicate,isNull);expect(await echoes.candidate(b,now),isNull);
  });
  test('two distinct humans can offer an optional same-group image after prior bytes are released',()async {
    final first=await seen('one');echoes.release(first);now+=1000;
    final second=await seen('two');final candidate=(await echoes.candidate(second,now))!;
    expect(candidate.members,2);expect(candidate.bytes.length,3);expect(candidate.hint['candidate'],'e1');
    expect(candidate.prompt,contains('不强制跟图'));expect(candidate.prompt,isNot(contains('temporary-')));
    expect(await echoes.current(candidate),true);
    echoes.release(second);expect(await echoes.candidate(second,now),isNull); // No new raw image, no re-evaluation.
    final exported=jsonEncode(await db.exportAll());expect(exported,isNot(contains('temporary-')));
  });
  test('other groups, different pixels, expired waves and oversized originals do not qualify',()async {
    final first=await seen('one');echoes.release(first);
    final other=await seen('two',group:'b');expect(await echoes.candidate(other,now),isNull);echoes.release(other);
    final different=await seen('two',hash:'different');expect(await echoes.candidate(different,now),isNull);echoes.release(different);
    now+=QqEchoService.window.inMilliseconds+1;
    final late=await seen('two');expect(await echoes.candidate(late,now),isNull);echoes.release(late);
    final large=await seen('three',size:QqEchoService.maxImageBytes+1);expect(await echoes.candidate(large,now),isNull);
  });
  test('withdrawn or changed original cannot be uploaded through an already selected candidate',()async {
    final first=await seen('one');echoes.release(first);final second=await seen('two');
    final selected=(await echoes.candidate(second,now))!;
    final sql=await db.database;await sql.rawUpdate('UPDATE qq_images SET version=version+1 WHERE archive_seq=?',[first.rows.single['seq']]);
    expect(await echoes.current(selected),false);
    final api=_Api();try {await expectLater(echoes.upload(second,selected,api,now,()async=>true),throwsA(anything));expect(api.uploads,0);}
    finally{api.close();}
    await store.forget(await store.capture(conversationId:first.cid),first.cid);
    expect(await echoes.candidate(second,now),isNull);
  });
  test('known TTL is reused conservatively; unknown TTL is never extended',()async {
    final first=await seen('one');echoes.release(first);final second=await seen('two');final selected=(await echoes.candidate(second,now))!;
    final api=_Api()..ttl=120;try {
      expect(await echoes.upload(second,selected,api,now,()async=>true),'temporary-1');
      expect(await echoes.upload(second,selected,api,now+59000,()async=>true),'temporary-1');expect(api.uploads,1);
      api.ttl=null;
      expect(await echoes.upload(second,selected,api,now+60001,()async=>true),'temporary-2');
      expect(await echoes.upload(second,selected,api,now+60002,()async=>true),'temporary-3');
      await expectLater(echoes.upload(second,selected,api,selected.expiresAt,()async=>true),throwsA(anything));
      expect(const QqMediaUpload('token',ttl:0).reusableUntil(now),now);
    }finally{api.close();}
  });
  test('sent or uncertain self echo suppresses same wave, and restart keeps only the receipt',()async {
    final first=await seen('one');echoes.release(first);final second=await seen('two');final selected=(await echoes.candidate(second,now))!;
    await store.mark(second,'send_uncertain',sticker:selected.usageKey);echoes.release(second);
    final third=await seen('three');expect(await echoes.candidate(third,now),isNull);
    echoes.clear();final fourth=await seen('four');echoes.release(fourth);
    final fifth=await seen('five');expect(await echoes.candidate(fifth,now),isNull);
  });
  test('echo control requires one local candidate and never exposes a URL or token',(){
    expect(QqEchoChoice.parse('<qq_echo mode="only">e1</qq_echo>')!.only,true);
    expect(QqEchoChoice.parse('<qq_echo mode="with_text">e1</qq_echo>')!.only,false);
    expect(QqEchoChoice.parse('<qq_echo mode="only">e2</qq_echo>'),isNull);
    expect(QqEchoChoice.parse('<qq_echo mode="only">e1</qq_echo><qq_echo mode="only">e1</qq_echo>'),isNull);
    expect(QqEchoChoice.visible('hello<qq_echo mode="only">e1</qq_echo>'),'hello');
    expect(QqEchoChoice.visible('hello<qq_echo mode="only">'),'hello');
  });
}
