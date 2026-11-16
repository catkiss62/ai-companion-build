import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class QqVisionFrames {
  static const cacheVersion = 'qq-vision-material-gif-v1';

  /// Inspect small thumbnails for changes, then keep at most six full cells.
  static Future<({Uint8List bytes, String label, List<int> times})> prepare(
    Uint8List original, {
    required Future<bool> Function() current,
    int maxFrames = 120,
    int maxDecodedPixels = 100000000,
    Duration budget = const Duration(milliseconds: 2500),
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Codec? thumbnails;
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
      codec.dispose();
      codec = null;
      final side = count > 1 ? 320 : 1000;
      codec = w >= h
          ? await descriptor.instantiateCodec(
              targetWidth: math.min(w, side).toInt(),
            )
          : await descriptor.instantiateCodec(
              targetHeight: math.min(h, side).toInt(),
            );
      final first = await codec.getNextFrame();
      kept.add(first.image);
      if (count <= 1) {
        final bytes = await png(first.image);
        await check();
        return (bytes: bytes, label: '', times: const [0]);
      }
      Future<({Uint8List bytes, String label, List<int> times})>
      firstOnly() async {
        await check();
        return (
          bytes: await png(first.image),
          label: '[动图仅看首帧：解码/资源预算降级，未看到完整动作]',
          times: const [0],
        );
      }

      if (count > maxFrames || w * h * count * 2 > maxDecodedPixels)
        return await firstOnly();
      thumbnails = w >= h
          ? await descriptor.instantiateCodec(targetWidth: math.min(w, 24))
          : await descriptor.instantiateCodec(targetHeight: math.min(h, 24));
      final signatures = <Uint8List>[];
      final starts = <int>[];
      var total = 0;
      var estimated = false;
      for (var i = 0; i < count; i++) {
        if (watch.elapsed > budget) return await firstOnly();
        if (i % 16 == 0) {
          await check();
          await Future<void>.delayed(Duration.zero);
        }
        final frame = await thumbnails.getNextFrame();
        try {
          final pixels = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (pixels == null) return await firstOnly();
          signatures.add(
            pixels.buffer.asUint8List(
              pixels.offsetInBytes,
              pixels.lengthInBytes,
            ),
          );
          starts.add(total);
          final duration = frame.duration.inMilliseconds;
          total += duration > 0 ? duration : 100;
          estimated = estimated || duration <= 0;
        } finally {
          frame.image.dispose();
        }
      }
      thumbnails.dispose();
      thumbnails = null;
      final wanted = _keyframes(signatures, starts, total);
      final samples = <({ui.Image image, int at})>[(image: first.image, at: 0)];
      for (var i = 1; i < count; i++) {
        if (watch.elapsed > budget) return await firstOnly();
        if (i % 16 == 0) {
          await check();
          await Future<void>.delayed(Duration.zero);
        }
        final frame = await codec.getNextFrame();
        if (wanted.contains(i)) {
          kept.add(frame.image);
          samples.add((image: frame.image, at: starts[i]));
        } else {
          frame.image.dispose();
        }
      }
      await check();
      final columns = math.min(3, samples.length).toInt(),
          rows = (samples.length / columns).ceil();
      final cellW = math.max(120, first.image.width).toInt(),
          cellH = first.image.height + 24;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
      for (var i = 0; i < samples.length; i++) {
        final x = (i % columns * cellW).toDouble(),
            y = (i ~/ columns * cellH).toDouble();
        canvas.drawImage(
          samples[i].image,
          ui.Offset(x + (cellW - first.image.width) / 2, y),
          ui.Paint(),
        );
        final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 14))
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xff111111)))
          ..addText('${i + 1} · ${(samples[i].at / 1000).toStringAsFixed(2)}s');
        final paragraph = builder.build()
          ..layout(ui.ParagraphConstraints(width: cellW.toDouble()));
        canvas.drawParagraph(
          paragraph,
          ui.Offset(x + 2, y + first.image.height + 2),
        );
        paragraph.dispose();
      }
      final picture = recorder.endRecording();
      ui.Image? sheet;
      try {
        sheet = await picture.toImage(cellW * columns, cellH * rows);
        return (
          bytes: await png(sheet),
          label:
              '[动图抽样${samples.length}帧，按标号/相对时间阅读；${estimated ? '时间为估计；' : ''}可能漏掉短暂变化，不等于完整观看]',
          times: samples.map((s) => s.at).toList(),
        );
      } finally {
        sheet?.dispose();
        picture.dispose();
      }
    } catch (error) {
      if (kept.isEmpty) rethrow;
      await check();
      return (
        bytes: await png(kept.first),
        label: '[动图仅看首帧：后续帧解码失败，未看到完整动作]',
        times: const [0],
      );
    } finally {
      for (final image in kept) {
        image.dispose();
      }
      thumbnails?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  // Keep distinct endpoints and prefer new visual states, using temporal coverage
  // to break ties. A short change can win over a long repeated pose.
  static Set<int> _keyframes(
    List<Uint8List> frames,
    List<int> starts,
    int total,
  ) {
    final chosen = {0};
    final nearest = List<double>.filled(frames.length, 1);
    void include(int index) {
      final reference = frames[index];
      for (var i = 1; i < frames.length; i++) {
        if (chosen.contains(i)) continue;
        var difference = 0;
        final candidate = frames[i];
        for (var j = 0; j < reference.length; j++) {
          difference += (reference[j] - candidate[j]).abs();
        }
        nearest[i] = math.min(
          nearest[i],
          difference / (255 * reference.length),
        );
      }
    }

    include(0);
    final last = frames.length - 1;
    if (nearest[last] >= 0.02) {
      chosen.add(last);
      include(last);
    }
    // Keep the old time-sampling cell count, including its deduplication
    // for long holds. A better selection must not enlarge the model input.
    final samples = math.min(6, frames.length);
    final oldSlots = <int>{};
    for (var i = 0; i < samples; i++) {
      final at = ((total - 1) * i / (samples - 1)).round();
      oldSlots.add(starts.lastIndexWhere((start) => start <= at));
    }
    final limit = oldSlots.length;
    while (chosen.length < limit) {
      var best = -1;
      var bestScore = 0.0;
      for (var i = 1; i < frames.length - 1; i++) {
        if (chosen.contains(i) || nearest[i] < 0.02) continue;
        final gap = chosen
            .map((j) => (starts[i] - starts[j]).abs())
            .reduce(math.min);
        final score = nearest[i] * (1 + gap / total);
        if (score > bestScore) {
          best = i;
          bestScore = score;
        }
      }
      if (best < 0) break;
      chosen.add(best);
      if (chosen.length < limit) include(best);
    }
    return chosen;
  }
}
