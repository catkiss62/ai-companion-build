import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../database/brain_work_fence.dart';
import '../diagnostics/model_usage_telemetry.dart';
import 'model_dialogue_gateway.dart';
import 'model_dialogue_context.dart';
import 'model_dialogue_models.dart';
import 'model_dialogue_prompt.dart';
import 'model_dialogue_repository.dart';

class ModelDialogueController extends ChangeNotifier {
  ModelDialogueController({required this.roomId,required this.repository,
    Future<ModelDialogueConfiguration> Function()? configurationLoader,ModelDialogueGateway? gateway}) {
    loadConfiguration=configurationLoader??()=>ModelDialogueConfiguration.load(repository.db);
    this.gateway=gateway??ModelDialogueGateway(DeepSeekClient(
      abortWhen:() async => _disposed||_cancellation?.isCancelled==true||
        _ticket==null||!await repository.isCurrent(_ticket!),
      onUsage:(event)=>ModelUsageTelemetry.record(repository.db,event)));
  }
  final String roomId;
  final ModelDialogueRepository repository;
  late final Future<ModelDialogueConfiguration> Function() loadConfiguration;
  late final ModelDialogueGateway gateway;
  ModelDialogueRoom? room;
  List<ModelDialogueMessage> messages=const [];
  bool loading=true,busy=false;
  String preview='',speaking='',error='',notice='';
  int attempt=0;
  bool _disposed=false;
  GenerationCancellationToken? _cancellation;
  ModelDialogueTicket? _ticket;
  Timer? _renewTimer,_previewTimer;

  void _notify(){if(!_disposed)notifyListeners();}
  Future<void> initialize() async {
    try {await repository.recoverOrphan(roomId);await reload();}
    catch(_){error='房间读取失败，请重新打开。';}
    loading=false;_notify();
  }
  Future<void> reload() async {
    room=await repository.roomById(roomId);
    messages=room==null?const []:await repository.messagesForRoom(roomId);
    if(room==null)error='这个对谈房间不存在或已删除。';
    _notify();
  }

  /// One click is one participant turn. There is no unattended continuation.
  /// Return true once user text has been durably accepted, even if HTTP fails.
  Future<bool> advance({String userText=''}) async {
    if(_disposed||busy||loading||room==null||room!.ended)return false;
    busy=true;preview='';speaking='';error='';notice='';attempt=0;
    final cancellation=GenerationCancellationToken();_cancellation=cancellation;
    var accepted=false,leased=false;
    _notify();
    try {
      final config=await loadConfiguration();cancellation.throwIfCancelled();config.validate();
      final current=await repository.roomById(roomId);
      if(current==null||current.ended)throw StateError('room_not_ready');
      for(final speaker in modelDialogueSpeakers) {
        if(!config.forSpeaker(speaker).matches(current)) {
          throw const ModelDialogueConfigurationError('这个房间的模型或接口配置已变化，请新建房间对谈。');
        }
      }
      leased=await repository.db.tryAcquireLocalLease('chat_turn_lease',holdFor:const Duration(minutes:3));
      cancellation.throwIfCancelled();
      if(!leased)throw const ModelDialogueConfigurationError('其他聊天正在生成，请稍后再继续。');
      final fence=await repository.db.captureBrainWorkFence(leaseKey:'chat_turn_lease');
      cancellation.throwIfCancelled();if(fence==null)throw const BrainWorkInvalidated();
      final background=current.memoryContext.isEmpty||userText.trim().isNotEmpty
          ? await ModelDialogueContext(repository.db).build('${current.topic}\n$userText')
          : null;
      cancellation.throwIfCancelled();
      final ticket=await repository.begin(roomId:roomId,fence:fence,userText:userText,memoryContext:background);
      _ticket=ticket;accepted=true;
      room=ticket.room;messages=ticket.history;speaking=ticket.speaker;
      cancellation.throwIfCancelled();_notify();
      var renewing=false;
      _renewTimer=Timer.periodic(const Duration(seconds:35),(_) async {
        if(renewing||_disposed||cancellation.isCancelled)return;
        renewing=true;
        try {
          if(!await repository.db.renewLocalLease('chat_turn_lease',holdFor:const Duration(minutes:3),workFence:fence)) {
            cancellation.cancel();
          }
        } catch(_){cancellation.cancel();} finally {renewing=false;}
      });
      final output=await gateway.generate(endpoint:config.forSpeaker(ticket.speaker),
        messages:ModelDialoguePrompt.build(ticket.room,ticket.history,ticket.speaker),
        cancellation:cancellation,requestId:ticket.requestId,
        onAttempt:(value){if(!_disposed&&!cancellation.isCancelled){attempt=value;preview='';_notify();}},
        onPreview:(value){
          if(_disposed||cancellation.isCancelled)return;
          preview=value;
          _previewTimer??=Timer(const Duration(milliseconds:40),(){_previewTimer=null;_notify();});
        });
      cancellation.throwIfCancelled();
      final saved=await repository.commit(ticket,output,cancellation);
      cancellation.throwIfCancelled();
      if(!saved)throw const BrainWorkInvalidated();
    } on GenerationCancelledByUserException {
      if(notice.isEmpty)notice='已停止，未完成的模型输出未加入对谈。';
    } on GenerationSuspendedByRuntimeGateException {
      error='运行状态已变化，本次对谈已停止。重新打开房间后可继续。';
    } on BrainWorkInvalidated {
      error='数据或运行权限已变化，本次结果未写入。请重新打开房间。';
    } on ModelDialogueConfigurationError catch(e){error=e.message;}
      on ModelDialogueRequestFailure catch(e){error=e.toString();}
      on FormatException {error='输入过长或房间参数无效，请检查后再试。';}
      catch(_){error='本次对谈未完成，请重新打开房间后重试。';}
    finally {
      _renewTimer?.cancel();_renewTimer=null;
      _previewTimer?.cancel();_previewTimer=null;
      final ticket=_ticket;_ticket=null;
      if(ticket!=null) {try{await repository.cancelTicket(ticket);}catch(_) {}}
      if(leased) {try{await repository.db.releaseLocalLease('chat_turn_lease');}catch(_) {}}
      _cancellation=null;preview='';busy=false;attempt=0;
      if(!_disposed){try{await reload();}catch(_){error='房间暂时无法读取，请重新打开。';}_notify();}
    }
    return accepted;
  }
  Future<void> pause() async {
    _cancellation?.cancel();
    _renewTimer?.cancel();
    final ticket=_ticket;
    if(ticket!=null){try{await repository.cancelTicket(ticket);}catch(_) {}}
    if(busy)notice='已停止，未完成的模型输出未加入对谈。';
    _notify();
  }
  Future<bool> end() async {
    await pause();
    try {
      final result=await repository.end(roomId);
      if(!result)error='当前正在备份或恢复，暂时无法结束房间。';
      await reload();return result;
    } catch(_) {error='当前状态暂时无法结束房间，请重新打开后再试。';_notify();return false;}
  }
  @override void dispose() {
    _disposed=true;_cancellation?.cancel();_renewTimer?.cancel();_previewTimer?.cancel();
    final ticket=_ticket;
    if(ticket!=null)unawaited(repository.cancelTicket(ticket).then((_) {}).catchError((_) {}));
    gateway.close();super.dispose();
  }
}
