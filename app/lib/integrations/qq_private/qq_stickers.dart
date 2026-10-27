import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../core/database/app_database.dart';
import '../../core/stickers/sticker_expression_service.dart';
import '../../core/stickers/sticker_pack.dart';
import '../../core/stickers/sticker_pack_storage.dart';
import '../../core/storage/shared_media_lock.dart';
import 'qq_store.dart';

/// Reuses the installed gallery/caption edits, never main chat attachment
/// creation or its usage counters. QQ receipts own their independent rotation.
class QqStickers {
  QqStickers(this.db,{StickerPackStorage? storage}):storage=storage??StickerPackStorage(db:db);
  final AppDatabase db;
  final StickerPackStorage storage;
  static String choicePrompt(List<StickerReplyCandidate> candidates)=>
    '${StickerExpressionService.replyChoicePrompt(candidates)}\n'
    '本轮表情候选所属包（仅资料）：${jsonEncode({for(final c in candidates)c.id:StickerDisplayLabels.packName(c.pack)})}。'
    '这是当前轮次的局部候选，没有列出某包不表示该包不存在。收到群友的图片不会自动收入表情图库，不虚称已收藏。';
  Future<String> stamp() async=>jsonEncode([for(final key in [StickerPackStorage.modeSetting,
    StickerPackStorage.enabledPacksSetting,StickerPackStorage.captionOverridesSetting])await db.getSetting(key)]);
  static bool explicitGroupPlay(String text) {
    // Mentioning a sticker, complaining about one, or old OCR text is not an
    // invitation. This only bypasses the existing opportunity probability.
    if(RegExp(r'(别|不要|不用|停止|减少|少发).{0,10}(表情|斗图)').hasMatch(text)) return false;
    return RegExp(r'(?:^|[\n，,。！？!?])\s*(?:(?:请|你|小鲸鱼|快|能不能|能|可以|再|要不|给我|给大家|帮我|一起)\s*){0,4}'
      r'(?:(?:发|来|整|丢|甩|回)(?!了|过|的).{0,8}表情包|(?:来)?斗图(?:吧|呀|吗)?[！!？?。\s]*$)').hasMatch(text);
  }
  Future<List<StickerReplyCandidate>> candidates(String seed,String context,{bool group=false}) async {
    final mode=(await db.getSetting(StickerPackStorage.modeSetting)??'natural').toLowerCase();
    if(mode=='off') return [];
    final unit=int.parse(QqStore.hash([seed,'sticker']).substring(0,8),radix:16)/0xffffffff;
    final invited=group?explicitGroupPlay(context):RegExp(r'(表情包|斗图)').hasMatch(context);
    if(!invited && unit>=StickerExpressionService.ordinaryReplyThreshold(mode)) return [];
    final enabled=await storage.enabledPackIds();
    final recent=await (await db.database).query('qq_deliveries',columns:['sticker_key'],
      where:"state='sent' AND sticker_key != ''",orderBy:'updated_at DESC',limit:20);
    final used=recent.map((r)=>r['sticker_key']).toSet();
    final pool=<({StickerPackMeta pack,StickerRecord record})>[];
    for(final pack in await storage.scanPacks()) {
      if(!enabled.contains(pack.id)) continue;
      try {
        for(final r in await storage.readRecords(pack)) {if(StickerAgencyPolicy.isAssistantSelectable(r)) pool.add((pack:pack,record:r));}
      } catch(_) { /* One damaged pack cannot hide the remaining gallery. */ }
    }
    if(group)return groupSelection(seed,context,[for(final item in pool)StickerReplyCandidate('',item.pack,item.record)],used);
    final fresh=pool.where((r)=>!used.contains(r.record.usageKey)).toList();
    final selected=fresh.isEmpty?pool:fresh;
    selected.sort((a,b){
      final score=StickerExpressionService.semanticMatchScore(b.record,context).compareTo(StickerExpressionService.semanticMatchScore(a.record,context));
      return score!=0?score:QqStore.hash([seed,a.record.usageKey]).compareTo(QqStore.hash([seed,b.record.usageKey]));
    });
    return [for(var i=0;i<selected.length && i<8;i++)StickerReplyCandidate('s${i+1}',selected[i].pack,selected[i].record)];
  }
  /// Keep a small enabled pack visible beside a much larger one. This changes
  /// candidate coverage only; the opportunity gate and model's choice remain.
  static List<StickerReplyCandidate> groupSelection(String seed,String context,
      List<StickerReplyCandidate> pool,Set<Object?> used) {
    int score(StickerReplyCandidate c)=>StickerExpressionService.semanticMatchScore(c.record,context)+
      (context.contains(StickerDisplayLabels.packName(c.pack))?3:0);
    int compare(StickerReplyCandidate a,StickerReplyCandidate b) {
      final semantic=score(b).compareTo(score(a));
      return semantic!=0?semantic:QqStore.hash([seed,a.record.usageKey]).compareTo(QqStore.hash([seed,b.record.usageKey]));
    }
    final packs=<String,List<StickerReplyCandidate>>{};
    for(final c in pool) {(packs[c.pack.id]??=[]).add(c);}
    final eligible=<StickerReplyCandidate>[];
    for(final pack in packs.values) {
      final fresh=pack.where((c)=>!used.contains(c.record.usageKey)).toList();
      eligible.addAll(fresh.isEmpty?pack:fresh);
    }
    eligible.sort(compare);
    final selected=<StickerReplyCandidate>[],covered=<String>{};
    for(final c in eligible) {
      if(covered.add(c.pack.id))selected.add(c);
      if(selected.length==8)break;
    }
    final keys=selected.map((c)=>c.record.usageKey).toSet();
    for(final c in eligible) {
      if(selected.length==8)break;
      if(keys.add(c.record.usageKey))selected.add(c);
    }
    return [for(var i=0;i<selected.length;i++)StickerReplyCandidate('s${i+1}',selected[i].pack,selected[i].record)];
  }
  Future<({Uint8List bytes,String filename})> bytes(StickerReplyCandidate candidate) =>SharedMediaLock.run(() async {
    final enabled=await storage.enabledPackIds();
    if(!enabled.contains(candidate.pack.id) || await db.getSetting(StickerPackStorage.modeSetting)=='off') throw StateError('sticker_disabled');
    final record=(await storage.readRecords(candidate.pack)).where((r)=>r.path==candidate.record.path && r.caption==candidate.record.caption && StickerAgencyPolicy.isAssistantSelectable(r));
    if(record.isEmpty) throw StateError('sticker_changed');
    final file=await storage.fileFor(candidate.pack,candidate.record);
    if(await file.length()>10*1024*1024) throw StateError('sticker_too_large');
    return (bytes:await file.readAsBytes(),filename:path.basename(file.path));
  },db:db);
}
