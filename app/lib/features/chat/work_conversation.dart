import 'dart:async';
import '../../core/agent/work_quiz.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../core/agent/work_error.dart';
import '../../core/agent/work_text_reference.dart';

import '../../core/agent/commission_session.dart';
import '../../core/agent/commission_history_search.dart';
import '../../core/agent/work_turn_details.dart';
import '../../core/agent/commission_workspace.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/ai/generation_cancellation.dart';
import '../../core/database/app_database.dart';
import '../../core/diagnostics/model_usage_telemetry.dart';
import '../../core/storage/secure_config.dart';

enum WorkPhase { idle, planning, tool, composing }

class WorkConversation extends ChangeNotifier {
  WorkConversation(this.db, this.config, this.chatBusy);
  final AppDatabase db;
  final SecureConfig config;
  final bool Function() chatBusy;
  late final _client = DeepSeekClient(
    abortWhen: () async => !await db.brainWorkAllowed(),
    onUsage: (event) async {
      if (_details.addUsage(event)) _update();
      await ModelUsageTelemetry.record(db, event);
    },
  );
  final _historySearch = CommissionHistorySearch();
  GenerationCancellationToken? _token;
  bool _disposed = false;
  CommissionWorkspace? _workspace;
  String? _file;
  WorkTextReference? _reference;
  Map<String, Object?>? _turnReference;
  String? draft;
  WorkTextSnapshot? draftBase;
  bool applying = false;
  Future<void> applyDraft(String proposed, WorkTextSnapshot base) async {
    final selected = _reference;
    if (busy || choosingReference || applying || selected == null ||
        draft != proposed || !identical(draftBase, base)) throw StateError('修改稿已失效');
    applying = true;
    _update();
    try {
      final workspace = _workspace, file = _file;
      await selected.apply(base.digest, proposed);
      draft = null;
      draftBase = null;
      _details.receipts.add({'tool': 'work_file_applied', 'target': base.name,
        'state': 'done', 'display': '已写回并重新读取核对'});
      if (workspace != null && file != null) {
        try {
          final row = jsonDecode(await workspace.read(file)) as Map;
          if (row['id'] == _details.executionId) {
            row['receipts'] = _details.receipts;
            row['applied_file'] = base.name;
            await workspace.write(file, jsonEncode(row));
          }
        } catch (_) {
          status = '文件已写回，工作记录未能更新';
        }
      }
    } finally {
      applying = false;
      _update();
    }
  }
  String? get referenceName => _reference?.name;
  int _viewGeneration = 0;
  bool choosingReference = false;

  Future<void> chooseReference() async {
    if (busy || choosingReference) return;
    final view = _viewGeneration;
    choosingReference = true;
    _update();
    try {
      final selected = await WorkTextReference.choose();
      if (selected == null) return;
      if (_disposed || view != _viewGeneration || busy) {
        await selected.forget();
        return;
      }
      draft = null;
      draftBase = null;
      _reference = selected;
    } finally {
      choosingReference = false;
      _update();
    }
  }

  void removeReference() {
    final selected = _reference;
    _reference = null;
    draft = null;
    draftBase = null;
    if (selected != null) unawaited(selected.forget());
    _update();
  }
  WorkTurnDetails _details = WorkTurnDetails();
  String? _failure;
  Map<String, dynamic> get currentTurn => {
    if (_failure != null) 'failureReason': _failure,
    'id': _details.executionId,
    if (_turnReference != null) 'text_reference': _turnReference,
    'goal': goal,
    'answer': answer,
    'steps': steps,
    'status': status,
    ..._details.snapshot(),
  };
  Future<String> readHtml(String name, {String? expectedDigest}) async {
    final workspace = _workspace;
    if (workspace == null) throw StateError('工作区不可用');
    return workspace.readHtml(name, expectedDigest: expectedDigest);
  }

  Future<Uint8List> screenshot(String name,String digest) async {
    final workspace = _workspace;
    if(workspace==null) throw StateError('工作区不可用');
    return WorkQuiz.image(workspace,name,digest);
  }

  Future<String> readDocument(String name) async {
    final workspace = _workspace;
    if (workspace == null || !name.endsWith('.md')) throw StateError('文件不可用');
    return workspace.read(name);
  }

  List<Map<String, dynamic>> turns = [];
  List<String> steps = [];
  String goal = '', answer = '', status = '';
  bool get busy => _token != null || applying;
  WorkPhase phase = WorkPhase.idle;

  void _update() {
    if (!_disposed) notifyListeners();
  }

  void clear() {
    if (busy) return;
    _historySearch.clear();
    _viewGeneration++;
    _turnReference = null;
    removeReference();
    _workspace = null;
    _file = null;
    turns = [];
    steps = [];
    goal = '';
    answer = '';
    status = '';
    _failure = null;
    _update();
  }

  Future<void> open(CommissionWorkspace workspace, String file) async {
    if (busy) return;
    final rows = await workspace.conversation(file);
    if (_disposed || busy) return;
    clear();
    _workspace = workspace;
    _file = file;
    turns = rows;
    _update();
  }

  Future<void> send(
    String text, {
    bool lookup = false,
    CommissionWorkspace? source,
  }) async {
    if (busy || choosingReference || text.trim().isEmpty) return;
    draft = null;
    draftBase = null;
    final token = GenerationCancellationToken();
    _token = token;
    phase = WorkPhase.planning;
    if (goal.isNotEmpty && !lookup) {
      turns = [...turns, currentTurn];
    }
    _turnReference = null;
    if (lookup) {
      removeReference();
      turns = [];
      _file = null;
      _workspace = null;
    }
    _details = WorkTurnDetails();
    steps = [];
    goal = text.trim();
    answer = '';
    status = '正在规划';
    _failure = null;
    _update();
    try {
      final workspace =
          source ?? await CommissionWorkspace.open();
      token.throwIfCancelled();
      if (_workspace != null && !_workspace!.sameLocation(workspace)) {
        turns = [];
        _file = null;
        _historySearch.clear();
      }
      _workspace = workspace;
      final snapshot = await _reference?.read();
      token.throwIfCancelled();
      _turnReference = snapshot?.receipt;
      String? proposal;
      answer = await CommissionSession.run(
        reference: snapshot,
        proposeEdit: snapshot == null ? null : (text) { proposal = text; },
        workspace: workspace,
        goal: goal,
        client: _client,
        config: config,
        db: db,
        details: _details,
        onDetails: _update,
        previousTask: _file,
        historySearch: _historySearch,
        recentContext: lookup,
        cancel: token,
        chatBusy: chatBusy,
        onRecordCreated: (name) => _file = name,
        onPhase: (value) {
          phase = switch (value) {
            CommissionPhase.tool => WorkPhase.tool,
            CommissionPhase.composing => WorkPhase.composing,
            CommissionPhase.planning => WorkPhase.planning,
          };
          _update();
        },
        progress: (message) {
          status = message;
          if (steps.isEmpty || steps.last != message) steps.add(message);
          _update();
        },
      );
      if (proposal != null && !token.isCancelled) {
        draftBase = snapshot;
        draft = proposal;
      }
      status = _details.researchEnd == 'evidence_incomplete' ? '已交付 · 部分依据待核实' : '已完成';
    } catch (e) {
      _failure = token.isCancelled ? null : workErrorReason(e);
      status = token.isCancelled ? '已停止' : '工作未完成 · $_failure';
    } finally {
      _details.finish();
      _token = null;
      phase = WorkPhase.idle;
      _update();
    }
  }

  void stop() => _token?.cancel();

  @override
  void dispose() {
    _disposed = true;
    removeReference();
    _historySearch.clear();
    stop();
    _client.close();
    super.dispose();
  }
}
