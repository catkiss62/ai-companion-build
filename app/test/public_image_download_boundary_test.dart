import 'dart:async';
import 'dart:io';

import 'package:ai_companion_localfirst/core/media/safe_public_image_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Client extends http.BaseClient {
  _Client(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  final requests = <http.BaseRequest>[];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return respond(request);
  }

  @override
  void close() => closed = true;
}

void main() {
  late Directory temp;
  const png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  setUp(() async => temp = await Directory.systemTemp.createTemp('image_bound_'));
  tearDown(() async => temp.delete(recursive: true));

  Future<DownloadedPublicImage> download(
    _Client client, {
    Duration total = const Duration(seconds: 5),
    Duration idle = const Duration(milliseconds: 150),
    int maxBytes = 64,
  }) => SafePublicImageDownloader.download(
    client: client,
    rawUrl: 'https://example.com/image',
    maxBytes: maxBytes,
    filePrefix: 'test',
    totalTimeout: total,
    idleTimeout: idle,
    temporaryDirectory: temp,
  );

  test('a stalled body times out, cancels and removes its partial file', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    final client = _Client((_) async => http.StreamedResponse(body.stream, 200));
    body.add(png);
    await expectLater(download(client), throwsA(isA<TimeoutException>()));
    expect(cancelled, isTrue);
    expect(await temp.list().toList(), isEmpty);
    expect(client.closed, isFalse);
    await expectLater((client.requests.single as http.Abortable).abortTrigger,
        completes);
  });

  test('the total deadline also stops a continuously trickling response', () async {
    Timer? timer;
    final body = StreamController<List<int>>(
      onCancel: () => timer?.cancel(),
    );
    final client = _Client((_) async {
      timer = Timer.periodic(const Duration(milliseconds: 10), (_) => body.add([0]));
      return http.StreamedResponse(body.stream, 200);
    });
    await expectLater(download(client,
      total: const Duration(milliseconds: 160),
      idle: const Duration(milliseconds: 100),
      maxBytes: 100000,
    ), throwsA(isA<TimeoutException>()));
    expect(timer!.isActive, isFalse);
    expect(await temp.list().toList(), isEmpty);
  });

  for (final status in [302, 500, 200]) {
    test('reject/cancel $status without draining a never-ending body', () async {
      var cancelled = false;
      final body = StreamController<List<int>>(onCancel: () => cancelled = true);
      final client = _Client((_) async => http.StreamedResponse(
        body.stream, status,
        headers: status == 200 ? {'content-length': '99999'} : {},
        isRedirect: status == 302,
      ));
      await expectLater(download(client), throwsA(anyOf(
        isA<HttpException>(), isA<FormatException>(),
      )));
      expect(cancelled, isTrue);
      expect(await temp.list().toList(), isEmpty);
    });
  }

  test('redirect body is cancelled and a subsequent valid image still succeeds', () async {
    var cancelled = false;
    var calls = 0;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    final client = _Client((_) async => ++calls == 1
      ? http.StreamedResponse(body.stream, 302, isRedirect: true,
          headers: {'location': '/actual.png'})
      : http.StreamedResponse(Stream.value(png), 200));
    final result = await download(client);
    expect(cancelled, isTrue);
    expect(result.mimeType, 'image/png');
    expect(await result.file.readAsBytes(), png);
    expect(client.requests.last.url.path, '/actual.png');
    expect(client.closed, isFalse);
  });

  test('header timeout aborts; an uncooperative late response is cancelled', () async {
    final response = Completer<http.StreamedResponse>();
    var cancelled = false;
    final client = _Client((_) => response.future);
    await expectLater(download(client), throwsA(isA<TimeoutException>()));
    await expectLater((client.requests.single as http.Abortable).abortTrigger,
        completes);
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    response.complete(http.StreamedResponse(body.stream, 200));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cancelled, isTrue);
    expect(await temp.list().toList(), isEmpty);
  });

  test('body limit is enforced even when Content-Length is absent', () async {
    final client = _Client((_) async => http.StreamedResponse(
      Stream.fromIterable([png, List<int>.filled(100, 0)]), 200,
    ));
    await expectLater(download(client), throwsFormatException);
    expect(await temp.list().toList(), isEmpty);
  });

  test('invalid image bytes are removed and the shared client remains usable', () async {
    var calls = 0;
    final client = _Client((_) async => http.StreamedResponse(
      Stream.value(++calls == 1 ? '<html>error</html>'.codeUnits : png), 200,
    ));
    await expectLater(download(client), throwsFormatException);
    expect(await temp.list().toList(), isEmpty);
    expect((await download(client)).mimeType, 'image/png');
    expect(client.closed, isFalse);
  });
}
