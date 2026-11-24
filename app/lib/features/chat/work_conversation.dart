import 'package:flutter/foundation.dart';

import '../../core/agent/commission_session.dart';
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
  GenerationCancellationToken? _token;
  bool _disposed = false;
  CommissionWorkspace? _workspace;
  String? _file;
  WorkTurnDetails _details = WorkTurnDetails();
  Map<String, dynamic> get currentTurn => {
    'id': _details.executionId,
    'goal': goal,
    'answer': answer,
    'steps': steps,
    'status': status,
    ..._details.snapshot(),
  };
  Future<String> readDocument(String name) async {
    final workspace = _workspace;
    if (workspace == null || !name.endsWith('.md')) throw StateError('文件不可用');
    return workspace.read(name);
  }

  List<Map<String, dynamic>> turns = [];
  List<String> steps = [];
  String goal = '', answer = '', status = '';
  bool get busy => _token != null;
  WorkPhase phase = WorkPhase.idle;

  void _update() {
    if (!_disposed) notifyListeners();
  }

  void clear() {
    if (busy) return;
    _workspace = null;
    _file = null;
    turns = [];
    steps = [];
    goal = '';
    answer = '';
    status = '';
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
    if (busy || text.trim().isEmpty) return;
    final token = GenerationCancellationToken();
    _token = token;
    phase = WorkPhase.planning;
    if (goal.isNotEmpty && !lookup) {
      turns = [...turns, currentTurn];
    }
    if (lookup) {
      turns = [];
      _file = null;
      _workspace = null;
    }
    _details = WorkTurnDetails();
    steps = [];
    goal = text.trim();
    answer = '';
    status = '正在规划';
    _update();
    try {
      final workspace =
          source ?? _workspace ?? await CommissionWorkspace.open();
      token.throwIfCancelled();
      _workspace = workspace;
      answer = await CommissionSession.run(
        workspace: workspace,
        goal: goal,
        client: _client,
        config: config,
        db: db,
        details: _details,
        onDetails: _update,
        previousTask: _file,
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
      status = '已完成';
    } catch (e) {
      status = token.isCancelled ? '已停止' : '工作未完成 · $e';
    } finally {
      _token = null;
      phase = WorkPhase.idle;
      _update();
    }
  }

  void stop() => _token?.cancel();

  @override
  void dispose() {
    _disposed = true;
    stop();
    _client.close();
    super.dispose();
  }
}
