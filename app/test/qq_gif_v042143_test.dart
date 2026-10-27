import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_vision_frames.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Six synthetic solid-color frames; no user image or third-party asset.
  final regular=base64Decode('R0lGODlhIAAYAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQICgAAACwAAAAAIAAYAAAILwABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJjQEBACH5BAgKAAAALAAAAAAgABgAgQD/AAAAAAAAAAAAAAgvAAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNq3Mixo8ePIEOKHEmypMmNAQEAIfkECAoAAAAsAAAAACAAGACBAAD/AAAAAAAAAAAACC8AAQgcSLCgwYMIEypcyLChw4cQI0qcSLGixYsYM2rcyLGjx48gQ4ocSbKkyY0BAQAh+QQICgAAACwAAAAAIAAYAIH//wAAAAAAAAAAAAAILwABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJjQEBACH5BAgKAAAALAAAAAAgABgAgf8A/wAAAAAAAAAAAAgvAAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNq3Mixo8ePIEOKHEmypMmNAQEAIfkECAoAAAAsAAAAACAAGACBAP//AAAAAAAAAAAACC8AAQgcSLCgwYMIEypcyLChw4cQI0qcSLGixYsYM2rcyLGjx48gQ4ocSbKkyY0BAQA7');
  final variable=base64Decode('R0lGODlhIAAYAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQIZAAAACwAAAAAIAAYAAAILwABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJjQEBACH5BAgKAAAALAAAAAAgABgAgQD/AAAAAAAAAAAAAAgvAAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNq3Mixo8ePIEOKHEmypMmNAQEAIfkECAoAAAAsAAAAACAAGACBAAD/AAAAAAAAAAAACC8AAQgcSLCgwYMIEypcyLChw4cQI0qcSLGixYsYM2rcyLGjx48gQ4ocSbKkyY0BAQAh+QQICgAAACwAAAAAIAAYAIH//wAAAAAAAAAAAAAILwABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJjQEBACH5BAgKAAAALAAAAAAgABgAgf8A/wAAAAAAAAAAAAgvAAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNq3Mixo8ePIEOKHEmypMmNAQEAIfkECAoAAAAsAAAAACAAGACBAP//AAAAAAAAAAAACC8AAQgcSLCgwYMIEypcyLChw4cQI0qcSLGixYsYM2rcyLGjx48gQ4ocSbKkyY0BAQA7');
  final still=base64Decode('iVBORw0KGgoAAAANSUhEUgAAACAAAAAYCAIAAAAUMWhjAAAAJElEQVR4nGP8z0BbwERj80ctGLVg1IJRC0YtGLVg1IJRC6gEAPHIAS8Wxt4fAAAAAElFTkSuQmCC');

  test('six frames become one static sheet with source colors and ordered times',() async {
    final result=await QqVisionFrames.prepare(regular,current:()async=>true,budget:const Duration(seconds:10));
    expect(result.label,contains('抽样6帧'));expect(result.times,[0,100,200,300,400,500]);
    final codec=await ui.instantiateImageCodec(result.bytes);
    ui.Image? image;
    try {
      expect(codec.frameCount,1);image=(await codec.getNextFrame()).image;
      expect(image.width,lessThanOrEqualTo(1000));expect(image.height,lessThanOrEqualTo(1000));
      final pixels=(await image.toByteData(format:ui.ImageByteFormat.rawRgba))!;
      final bytes=pixels.buffer.asUint8List(pixels.offsetInBytes,pixels.lengthInBytes);
      var red=false,cyan=false;
      for(var i=0;i<bytes.length;i+=4) {
        red=red || bytes[i]==255 && bytes[i+1]==0 && bytes[i+2]==0;
        cyan=cyan || bytes[i]==0 && bytes[i+1]==255 && bytes[i+2]==255;
      }
      expect(red,true);expect(cyan,true); // First and last real frames survive.
    } finally {image?.dispose();codec.dispose();}
  });
  test('variable frame durations select by time rather than six fixed indices',() async {
    final result=await QqVisionFrames.prepare(variable,current:()async=>true,budget:const Duration(seconds:10));
    expect(result.times,[0,1100,1400]);expect(result.label,contains('可能漏掉短暂变化'));
  });
  for(final limit in ['count','pixels','time']) {
    test('animation $limit bound explicitly degrades to first frame',() async {
      final result=await QqVisionFrames.prepare(regular,current:()async=>true,
        maxFrames:limit=='count'?2:120,maxDecodedPixels:limit=='pixels'?10:100000000,
        budget:limit=='time'?Duration.zero:const Duration(seconds:10));
      expect(result.times,[0]);expect(result.label,contains('仅看首帧'));expect(result.bytes,isNotEmpty);
    });
  }
  test('static picture retains one-image semantics and no animation claim',() async {
    final result=await QqVisionFrames.prepare(still,current:()async=>true);
    expect(result.label,'');expect(result.times,[0]);
    final codec=await ui.instantiateImageCodec(result.bytes);final image=(await codec.getNextFrame()).image;
    expect(image.width,32);expect(image.height,24);image.dispose();codec.dispose();
  });
  test('cancelled source cannot return a sheet even when frames have decoded',() async {
    var checks=0;
    await expectLater(QqVisionFrames.prepare(regular,current:()async=>++checks<2,
      budget:const Duration(seconds:10)),throwsStateError);
  });
  test('invalid image bytes fail before any vision request',() async {
    await expectLater(QqVisionFrames.prepare(base64Decode('AAECAwQ='),current:()async=>true),throwsA(anything));
  });
}
