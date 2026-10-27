import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class QqVisionFrames {
  static const cacheVersion = 'qq-vision-material-gif-v1';

  /// Decode at most two bounded cycles: durations first, then at most six
  /// time-spaced samples. No real-time playback, subprocess, or stored GIF.
  static Future<({Uint8List bytes, String label, List<int> times})> prepare(
      Uint8List original, {required Future<bool> Function() current,
      int maxFrames = 120, int maxDecodedPixels = 100000000,
      Duration budget = const Duration(milliseconds: 2500)}) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    final kept = <ui.Image>[];
    final watch = Stopwatch()..start();
    Future<void> check() async {
      if (!await current()) throw StateError('context_invalidated');
    }
    Future<Uint8List> png(ui.Image image) async {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > 6 * 1024 * 1024) {
        throw const FormatException('image_decode_failed');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    try {
      await check();
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width, h = descriptor.height;
      if (w <= 0 || h <= 0 || w * h > 24000000) {
        throw const FormatException('image_dimensions_rejected');
      }
      // Static images retain the established 1000px path. For animation the
      // target is chosen after inspecting frameCount without decoding pixels.
      codec = await descriptor.instantiateCodec();
      final count = codec.frameCount;
      codec.dispose(); codec = null;
      final side = count > 1 ? 320 : 1000;
      codec = w >= h
          ? await descriptor.instantiateCodec(targetWidth: math.min(w, side).toInt())
          : await descriptor.instantiateCodec(targetHeight: math.min(h, side).toInt());
      final first = await codec.getNextFrame(); kept.add(first.image);
      if (count <= 1) {
        final bytes=await png(first.image);await check();
        return (bytes:bytes,label:'',times:const [0]);
      }
      Future<({Uint8List bytes, String label, List<int> times})> firstOnly() async {
        await check();
        return (bytes: await png(first.image), label: '[动图仅看首帧：解码/资源预算降级，未看到完整动作]', times: const [0]);
      }
      if (count > maxFrames || w * h * count * 2 > maxDecodedPixels) return await firstOnly();
      final durations = <int>[first.duration.inMilliseconds > 0 ? first.duration.inMilliseconds : 100];
      var estimated = first.duration.inMilliseconds <= 0;
      for (var i = 1; i < count; i++) {
        if (watch.elapsed > budget) return await firstOnly();
        if (i % 16 == 0) {await check(); await Future<void>.delayed(Duration.zero);}
        final frame = await codec.getNextFrame();
        durations.add(frame.duration.inMilliseconds > 0 ? frame.duration.inMilliseconds : 100);
        estimated = estimated || frame.duration.inMilliseconds <= 0;
        frame.image.dispose();
      }
      final total = durations.fold<int>(0, (a, b) => a + b);
      final wanted = <int, int>{};
      for (var sample = 0; sample < math.min(6, count); sample++) {
        final target = ((total - 1) * sample / (math.min(6, count) - 1)).round();
        var start = 0;
        for (var i = 0; i < count; i++) {
          if (target < start + durations[i]) {wanted[i] = start; break;}
          start += durations[i];
        }
      }
      final samples = <({ui.Image image, int at})>[];
      for (var i = 0; i < count; i++) {
        if (watch.elapsed > budget) return await firstOnly();
        if (i % 16 == 0) {await check(); await Future<void>.delayed(Duration.zero);}
        final frame = await codec.getNextFrame();
        if (wanted.containsKey(i)) {kept.add(frame.image); samples.add((image: frame.image, at: wanted[i]!));}
        else {frame.image.dispose();}
      }
      await check();
      final columns = math.min(3, samples.length).toInt(), rows = (samples.length / columns).ceil();
      final cellW = math.max(120, first.image.width).toInt(), cellH = first.image.height + 24;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
      for (var i = 0; i < samples.length; i++) {
        final x = (i % columns * cellW).toDouble(), y = (i ~/ columns * cellH).toDouble();
        canvas.drawImage(samples[i].image, ui.Offset(x + (cellW - first.image.width) / 2, y), ui.Paint());
        final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 14))
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xff111111)))
          ..addText('${i + 1} · ${(samples[i].at / 1000).toStringAsFixed(2)}s');
        final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: cellW.toDouble()));
        canvas.drawParagraph(paragraph, ui.Offset(x + 2, y + first.image.height + 2));
        paragraph.dispose();
      }
      final picture = recorder.endRecording();
      ui.Image? sheet;
      try {
        sheet = await picture.toImage(cellW * columns, cellH * rows);
        return (bytes: await png(sheet),
          label: '[动图抽样${samples.length}帧，按标号/相对时间阅读；${estimated ? '时间为估计；' : ''}可能漏掉短暂变化，不等于完整观看]',
          times: samples.map((s) => s.at).toList());
      } finally {sheet?.dispose(); picture.dispose();}
    } catch (error) {
      if (kept.isEmpty) rethrow;
      await check();
      return (bytes: await png(kept.first),
        label: '[动图仅看首帧：后续帧解码失败，未看到完整动作]', times: const [0]);
    } finally {
      for (final image in kept) {image.dispose();}
      codec?.dispose(); descriptor?.dispose(); buffer.dispose();
    }
  }
}
