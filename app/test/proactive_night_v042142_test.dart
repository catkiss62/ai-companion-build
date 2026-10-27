import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/daily_wake_schedule.dart';
import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_night_policy.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_selection_policy.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';

void main() {
  final now=DateTime(2026,10,27,7,20);
  DesireSnapshot state(double drive)=>DesireSnapshot(drives:{
    ...DesireSnapshot.defaultDrives(),DriveKey.attachment:drive,DriveKey.curiosity:drive,DriveKey.fatigue:.78});
  DesireIntent intent({double score=.9,String source='drive_state',String? thoughtId,DriveKey drive=DriveKey.attachment})=>
    DesireIntent(drive:drive,score:score,reason:'synthetic',wantAction:'reach_out',reasonSource:source,thoughtId:thoughtId);
  CompanionThought thought({String source='conversation_turn:old',DateTime? born,double strength=.95})=>
    CompanionThought(id:'thought',text:'下午游戏的普通回忆',driveKey:'attachment',kind:'fixation',strength:strength,
      bornAt:born??now.subtract(const Duration(days:1)),updatedAt:now,lastFedAt:now,source:source);
  String? blocked(DesireIntent i,{DesireSnapshot? snapshot,CompanionThought? t,DateTime? evidence,DateTime? previous})=>
    ProactiveNightPolicy.blockReason(intent:i,snapshot:snapshot??state(.9),restScore:DesireCorePolicy.fatigueRestScore(.78),now:now,
      thought:t,evidenceAt:evidence,previousSameContactAt:previous);

  for(final wakeMinute in [480,517,540]) {
    test('rest plateau holds continuously until wake $wakeMinute then settles',() {
      final w=DailyWakeSchedule.atMinute(now,wakeMinute);
      for(var minute=240;minute<=wakeMinute;minute++) {
        expect(DesireCorePolicy.circadianFatigueFloor(DailyWakeSchedule.atMinute(now,minute),wakeAt:w),closeTo(.78,1e-9));
      }
      expect(DesireCorePolicy.circadianFatigueFloor(w.add(const Duration(minutes:1)),wakeAt:w),lessThan(.78));
      expect(DesireCorePolicy.circadianFatigueFloor(w.add(DailyWakeSchedule.settlingDuration),wakeAt:w),closeTo(.16,1e-9));
      expect(DesireCorePolicy.circadianFatigueFloor(DateTime(2026,10,27,12),wakeAt:w),closeTo(.16,1e-9));
    });
  }
  test('ordinary drive loses; truly strong present reach beats the same rest candidate',() {
    List<DesireCoreCandidate> candidates(double drive)=>DesireCorePolicy.candidates(drives:state(drive).drives,
      baselines:state(drive).baselines,refractoryUntil:{},thoughts:[],now:now,wildcardAllowed:false);
    final ordinary=candidates(.5);expect(ordinary.first.action,'rest');
    final strong=candidates(.9);final reach=strong.firstWhere((c)=>c.drive==DriveKey.attachment);
    expect(blocked(intent(score:reach.score)),isNull);
    expect(blocked(intent(score:.79)),isNotNull);expect(blocked(intent(),snapshot:state(.5)),isNotNull);
  });
  for(final source in ['conversation_turn:old','self_drive/thread','self_drive/memory:old','inference/old','internal']) {
    test('high old fixation $source cannot qualify through refreshed maintenance timestamps',() {
      final t=thought(source:source);
      expect(ProactiveNightPolicy.currentSource(t,now,now),false);
      expect(blocked(intent(source:source,thoughtId:t.id),t:t,evidence:now),isNotNull);
    });
  }
  test('actual fresh discoveries still need strong thought/drive; old events stay old',() {
    final t=thought(source:'mcp/cedar_game:bar:play-1',born:now);
    expect(blocked(intent(source:t.source,thoughtId:t.id),t:t,evidence:now),isNull);
    expect(blocked(intent(source:t.source,thoughtId:t.id),t:t,evidence:now.subtract(const Duration(hours:12))),isNotNull);
    expect(blocked(intent(source:t.source,thoughtId:t.id),t:t,evidence:now.add(const Duration(seconds:1))),isNotNull);
    final weak=thought(source:t.source,born:now,strength:.3);
    expect(blocked(intent(source:t.source,thoughtId:t.id),t:weak,evidence:now),isNotNull);
    expect(blocked(intent(source:t.source,thoughtId:t.id),snapshot:state(.5),t:t,evidence:now),isNotNull);
  });
  test('same night reason requires new real evidence before another contact',() {
    final previous=now.subtract(const Duration(hours:2));
    expect(blocked(intent(),previous:previous),isNotNull);
    expect(blocked(intent(),previous:previous,evidence:previous),isNotNull);
    expect(blocked(intent(),previous:previous,evidence:now),isNull);
  });
  test('night selection has no waiting, variety, opportunity bonuses or near-tie sampling; daytime retains them',() {
    final t=thought(source:'mcp/cedar_game:bar:play-1');
    final candidates=[intent(score:.91,thoughtId:t.id,source:t.source),
      intent(score:.90,drive:DriveKey.social),
      DesireIntent(drive:DriveKey.fatigue,score:.758,reason:'rest',wantAction:'rest',reasonSource:'drive_state')];
    for(final roll in [0.0,.49,.99]) {
      final result=ProactiveSelectionPolicy.select(candidates:candidates,thoughtsById:{t.id:t},recentIntentKinds:['followup','followup'],
        recentSourceTypes:['memory','memory'],now:now,samplingUnit:roll,night:true,satisfactionLedgerStartedAt:now.subtract(const Duration(days:4)))!;
      expect(result.intent.thoughtId,t.id);expect(result.waitingBoost,0);expect(result.freshnessBalanceBoost,0);
      expect(result.opportunityBoost,0);expect(result.sampledNearTie,false);
    }
    final daytime=ProactiveSelectionPolicy.select(candidates:candidates,thoughtsById:{t.id:t},recentIntentKinds:[],
      recentSourceTypes:['memory','memory'],now:now,satisfactionLedgerStartedAt:now.subtract(const Duration(days:4)))!;
    expect(daytime.opportunityBoost,greaterThan(0));expect(daytime.freshnessBalanceBoost,greaterThan(0));
  });
}
