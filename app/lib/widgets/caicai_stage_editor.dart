import 'package:flutter/material.dart';
import 'caicai_live2d_stage.dart';

/// Lives over the chat stage. Preview is transactional; cancel restores the snapshot.
class CaicaiStageEditor extends StatefulWidget {
  const CaicaiStageEditor({super.key, required this.mode, required this.initial});
  final String mode;
  final Map<Object?, Object?> initial;
  @override
  State<CaicaiStageEditor> createState() => _CaicaiStageEditorState();
}
class _CaicaiStageEditorState extends State<CaicaiStageEditor> {
  late double _scale, _x, _y;
  late Rect _head;
  double _startScale = 1;
  Offset _start = Offset.zero, _origin = Offset.zero;
  Rect _startHead = Rect.zero;
  bool _resizeHead = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _scale = (widget.initial['scale'] as num?)?.toDouble() ?? 1;
    _x = (widget.initial['x'] as num?)?.toDouble() ?? 0;
    _y = (widget.initial['y'] as num?)?.toDouble() ?? 0;
    final a = widget.initial['headRect'] as List? ?? [.3,.1,.7,.4];
    _head = Rect.fromLTRB((a[0] as num).toDouble(), (a[1] as num).toDouble(),
      (a[2] as num).toDouble(), (a[3] as num).toDouble());
  }
  Future<void> _preview(String command, Object value) async {
    try { await CaicaiLive2DService.command(command, value); }
    catch (e) { if (mounted) setState(() => _error = '预览失败：$e'); }
  }
  Future<void> _finish(bool save) async {
    setState(() => _saving = true);
    try {
      await CaicaiLive2DService.command('finishEdit', save);
      CaicaiLive2DService.editor.value = null;
    } catch (e) { if (mounted) setState(() { _saving = false; _error = '保存失败：$e'; }); }
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final size = box.biggest;
    final headMode = widget.mode == 'head';
    final rect = Rect.fromLTRB(_head.left*size.width, _head.top*size.height,
      _head.right*size.width, _head.bottom*size.height);
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _start = d.localFocalPoint; _origin = Offset(_x,_y); _startScale = _scale; _startHead = _head;
          _resizeHead = (d.localFocalPoint-rect.bottomRight).distance < 56;
        },
        onScaleUpdate: (d) {
          final delta = d.localFocalPoint-_start;
          setState(() {
            if (headMode) {
              if (_resizeHead) {
                _head = Rect.fromLTRB(_startHead.left,_startHead.top,
                  (_startHead.right+delta.dx/size.width).clamp(_startHead.left+.06, _startHead.left+1.5).toDouble(),
                  (_startHead.bottom+delta.dy/size.height).clamp(_startHead.top+.06, _startHead.top+1.5).toDouble());
              } else if (d.pointerCount > 1) {
                _head = Rect.fromCenter(center: _startHead.center,
                  width: (_startHead.width*d.scale).clamp(.06,1.5).toDouble(), height: (_startHead.height*d.scale).clamp(.06,1.5).toDouble());
              } else {
                _head = _startHead.shift(Offset(delta.dx/size.width,delta.dy/size.height));
              }
              _preview('previewHeadBox', [_head.left,_head.top,_head.right,_head.bottom]);
            } else {
              _scale = (_startScale*d.scale).clamp(.35,6).toDouble();
              final focal = Offset(_start.dx*2/size.width-1,1-_start.dy*2/size.height);
              _x = focal.dx-(focal.dx-_origin.dx)*_scale/_startScale+2*delta.dx/size.width;
              _y = focal.dy-(focal.dy-_origin.dy)*_scale/_startScale-2*delta.dy/size.height;
              _preview('previewStage', {'scale':_scale,'x':_x,'y':_y});
            }
          });
        },
        child: headMode ? CustomPaint(painter: _HeadBoxPainter(rect)) : const SizedBox.expand(),
      ),
      Positioned(left: 12, right: 12, bottom: 16, child: Card(child: Padding(
        padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(headMode ? '摸头区域：拖动框，双指或拖右下角缩放' : '拖动调整位置，双指缩放'),
          if (_error != null) Text(_error!),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: _saving ? null : () => _finish(false), child: const Text('取消')),
            FilledButton(onPressed: _saving ? null : () => _finish(true), child: const Text('确认')),
          ]),
        ]),
      ))),
    ]);
  });
}
class _HeadBoxPainter extends CustomPainter {
  const _HeadBoxPainter(this.rect);
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(rect, Paint()..color=Colors.pinkAccent.withValues(alpha:.16));
    canvas.drawRect(rect, Paint()..color=Colors.pinkAccent..style=PaintingStyle.stroke..strokeWidth=3);
    canvas.drawCircle(rect.bottomRight, 12, Paint()..color=Colors.pinkAccent);
  }
  @override
  bool shouldRepaint(_HeadBoxPainter old) => old.rect != rect;
}
