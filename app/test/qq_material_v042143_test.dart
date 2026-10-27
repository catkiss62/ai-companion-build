import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/core/qq/qq_message_material.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_incoming.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_history_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_stickers.dart';

Map<String,dynamic> quoted({String comment='你怎么看', String inner='转发资料里的独特珊瑚', bool many=false}) => {
  'message_type':103,'content':comment,'msg_idx':'outer-index','ref_msg_idx':'inner-index',
  'author':{'member_openid':'trusted-outer'},
  'msg_elements':[for(var i=0;i<(many?10:1);i++){
    'msg_idx':'inner-$i','content':inner,'author':{'member_openid':'owner'},
    'group_openid':'another-group','timestamp':'2001-01-01',
    'attachments':[{'content_type':'image/png','url':'https://fixture.invalid/quoted-$i.png'}]}]};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;
  const scope='synthetic-material';final cid=QqStore.conversationId(scope,'group','a');
  setUp(() async {FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);});
  tearDown(() async {await db.closeForTesting();});
  Future<int> add(QqIncoming input,{String id='message'}) async => (await store.append(
    fence:await store.capture(),scope:scope,kind:'group',target:'a',platformId:id,sender:'trusted-outer',
    text:input.text,contextMeta:input.material.encode(),images:input.urls.length,observedAt:1000,receivedAt:2000))!;

  test('103 quote retains nested text/image, never imports inner account/group/time authority',() async {
    final input=QqIncoming.parse(quoted());final seq=await add(input);final sql=await db.database;
    final row=(await sql.query('qq_archive')).single;
    expect(row['owner'],0);expect(row['sender'],'trusted-outer');expect(row['observed_at'],1000);
    expect(row['conversation_id'],cid);expect(input.text,'你怎么看');expect(input.urls.length,1);
    expect((await store.images(seq)).length,1);expect(input.material.reference,'inner-index');
    expect(input.material.parts.single['image_ordinals'],[0]);
    final projected=jsonDecode(await QqArchiveReader(sql).render(row)) as Map;
    expect(projected['text'],'你怎么看');expect(projected['text_scope'],'outer_sender_comment');
    expect((projected['materials'] as List).single['original_source'],'unverified');
    expect((projected['materials'] as List).single['text'],contains('独特珊瑚'));
    expect(jsonEncode(projected),isNot(contains('another-group')));
    expect(await QqArchiveReader(sql).display(row,speaker:'群成员'),contains('引用资料'));
  });

  test('learning projection contains only outer comment, no quoted/OCR voice',() async {
    final seq=await add(QqIncoming.parse(quoted(comment:'这个挺好笑',inner:'别处的独特台词')));
    final fence=await store.capture();await store.observation(fence,'${(await (await db.database).query('qq_archive')).single['id']}:0','viewed','截图内的其他人：另一句独特台词','synthetic');
    final sql=await db.database;final row=(await sql.query('qq_archive',where:'seq=?',whereArgs:[seq])).single;
    final stamps=<Map<String,Object?>>[];
    final block=await QqArchiveReader(sql).render(row,ownTextOnly:true,stamp:stamps,maxChars:1600);
    expect(block,contains('这个挺好笑'));expect(block,isNot(contains('独特台词')));
    expect(block,isNot(contains('materials')));expect(block,isNot(contains('images')));
    expect(stamps.map((s)=>s['table']).toSet(),{'qq_archive'});
  });

  test('App/Agent keyword lookup finds quoted material but preserves received-group origin',() async {
    await add(QqIncoming.parse(quoted()));
    final result=await QqHistoryReader(await db.database).search('查群聊记录',kind:'group',keyword:'独特珊瑚');
    expect(result.resolved,true);expect(result.text,contains('独特珊瑚'));
    expect(result.text,contains('unverified'));expect(result.conversation,cid);
  });

  test('metadata survives export/restore; schema64 rows gain only empty unknown metadata',() async {
    await add(QqIncoming.parse(quoted()));
    final backup=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;
    final tables=(backup['tables'] as Map).cast<String,dynamic>();
    final before=(tables['qq_archive'] as List).single['context_meta'];
    await db.importAll(backup);
    expect((await (await db.database).query('qq_archive')).single['context_meta'],before);
    final legacy=jsonDecode(jsonEncode(backup)) as Map<String,dynamic>;
    legacy['schema_version']=64;
    for(final r in legacy['tables']['qq_archive'] as List) {(r as Map).remove('context_meta');}
    await db.importAll(legacy);
    expect((await (await db.database).query('qq_archive')).single['context_meta'],'');
    final invalid=jsonDecode(jsonEncode(backup)) as Map<String,dynamic>;
    invalid['tables']['qq_archive'][0]['context_meta']='{"v":999}';
    expect(()=>QqArchiveSchema.validate((invalid['tables'] as Map).cast<String,dynamic>(),version:65),throwsFormatException);
  });

  test('material migration is idempotent on a genuine old table and never rewrites old text',() async {
    final sql=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:OpenDatabaseOptions(singleInstance:false));
    try {
      await sql.execute('CREATE TABLE qq_archive(id TEXT PRIMARY KEY,content TEXT)');
      await sql.insert('qq_archive',{'id':'legacy','content':'旧原文'});
      await QqArchiveSchema.upgradeMaterial(sql);await QqArchiveSchema.upgradeMaterial(sql);
      expect((await sql.query('qq_archive')).single,{'id':'legacy','content':'旧原文','context_meta':''});
    } finally {await sql.close();}
  });

  test('nested/escaped material is bounded; unrecognized embedded parts stay source-unknown',() {
    final input=QqIncoming.parse(quoted(inner:List.filled(9000,'\u0001').join(),many:true));
    expect(input.urls.length,4);expect(input.material.parts.length,4);expect(input.material.partial,true);
    expect(input.material.encode().length,lessThanOrEqualTo(12000));
    expect(QqMessageMaterial.decode(input.material.encode()).kind,'quote');
    final unknown=quoted()..remove('message_type')..remove('ref_msg_idx');
    expect(QqIncoming.parse(unknown).material.kind,'embedded');
    final legacy=QqIncoming.parse({'content':'外层','message_reference':{'message_id':'old-id'}});
    expect(legacy.replyTo,'old-id');expect(legacy.material.kind,'quote');expect(legacy.material.parts,isEmpty);
  });

  test('only a present invitation bypasses ordinary group sticker opportunity',() {
    expect(QqStickers.explicitGroupPlay('来个表情包'),true);
    expect(QqStickers.explicitGroupPlay('斗图！'),true);
    expect(QqStickers.explicitGroupPlay('刚才那个表情包挺好笑'),false);
    expect(QqStickers.explicitGroupPlay('不要再发表情包了'),false);
    expect(QqStickers.explicitGroupPlay('别斗图了'),false);
    expect(QqStickers.explicitGroupPlay('他刚发了个表情包'),false);
    expect(QqStickers.explicitGroupPlay('讨论斗图规则'),false);
  });
}
