import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadedPublicImage {
  const DownloadedPublicImage({
    required this.file,
    required this.mimeType,
  });

  final File file;
  final String mimeType;
}

/// Bounded HTTPS image downloader shared by chat delivery and the private
/// album. MIME headers from CDNs are only hints: the downloaded bytes must
/// carry a supported image signature before they reach decoding or vision.
class SafePublicImageDownloader {
  const SafePublicImageDownloader._();

  static Future<DownloadedPublicImage> download({
    required http.Client client,
    required String rawUrl,
    required int maxBytes,
    required String filePrefix,
    Duration totalTimeout = const Duration(seconds: 60),
    Duration idleTimeout = const Duration(seconds: 24),
    Directory? temporaryDirectory,
  }) async {
    var uri = Uri.tryParse(rawUrl);
    if (!safePublicHttps(uri)) {
      throw const FormatException('unsafe_image_url');
    }
    final clock = Stopwatch()..start();
    Duration remaining() {
      final left = totalTimeout - clock.elapsed;
      if (left <= Duration.zero) throw TimeoutException('image_download_timeout');
      return left < idleTimeout ? left : idleTimeout;
    }
    for (var redirects = 0; redirects <= 3; redirects++) {
      final abort = Completer<void>();
      void cancelRequest() {
        if (!abort.isCompleted) abort.complete();
      }
      final request = http.AbortableRequest('GET', uri!, abortTrigger: abort.future)
        ..followRedirects = false
        ..headers.addAll(const <String, String>{
          'Accept': 'image/webp,image/png,image/jpeg,image/gif,*/*;q=0.2',
          'User-Agent': 'AICompanion/0.41.49 (private Android companion)',
        });
      StreamIterator<List<int>>? chunks;
      Stream<List<int>>? body;
      var bodyStarted = false;
      try {
        // The same deadline covers headers, redirects and the entire body.
        // Attach to a late response too, even if a custom client ignores abort.
        final response = await client.send(request).then((response) async {
          if (abort.isCompleted) {
            await _cancelStream(response.stream);
            throw TimeoutException('image_download_timeout');
          }
          return response;
        }).timeout(remaining(), onTimeout: () {
          cancelRequest();
          throw TimeoutException('image_download_timeout');
        });
        body = response.stream;
        if (response.isRedirect) {
          final location = response.headers['location'];
          if (location == null || redirects == 3) {
            throw HttpException('image_redirect_rejected');
          }
          final redirected = uri.resolve(location);
          if (!safePublicHttps(redirected)) {
            throw const FormatException('unsafe_image_redirect');
          }
          uri = redirected;
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('image_download_${response.statusCode}');
        }
        final declared = int.tryParse(response.headers['content-length'] ?? '');
        if (declared != null && (declared <= 0 || declared > maxBytes)) {
          throw const FormatException('image_size_rejected');
        }

      final temp = temporaryDirectory ?? await getTemporaryDirectory();
      final staging = File(p.join(
        temp.path,
        '${filePrefix}_${DateTime.now().microsecondsSinceEpoch}.download',
      ));
      final sink = staging.openWrite();
      var bytes = 0;
      var sinkClosed = false;
      try {
        chunks = StreamIterator(body);
        bodyStarted = true;
        while (await chunks.moveNext().timeout(remaining(), onTimeout: () {
          cancelRequest();
          throw TimeoutException('image_download_timeout');
        })) {
          final chunk = chunks.current;
          bytes += chunk.length;
          if (bytes > maxBytes) {
            throw const FormatException('image_size_rejected');
          }
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
        sinkClosed = true;
        if (bytes <= 0) throw const FormatException('empty_image');

        final signature = await staging.openRead(0, 16).fold<BytesBuilder>(
              BytesBuilder(copy: false),
              (builder, chunk) => builder..add(chunk),
            );
        final mime = detectSupportedMime(signature.takeBytes());
        if (mime == null) {
          throw const FormatException('unsupported_image_bytes');
        }
        final extension = switch (mime) {
          'image/png' => '.png',
          'image/webp' => '.webp',
          'image/gif' => '.gif',
          _ => '.jpg',
        };
        final finalFile = await staging.rename(
          p.setExtension(staging.path, extension),
        );
        return DownloadedPublicImage(file: finalFile, mimeType: mime);
      } catch (_) {
        if (!sinkClosed) {
          try {
            await sink.close();
          } catch (_) {}
        }
        if (await staging.exists()) await staging.delete();
        rethrow;
      }
      } finally {
        // Do not drain an error/redirect body: it may never finish. Cancelling
        // only this request keeps the caller's shared HTTP client usable.
        if (!bodyStarted && body != null) await _cancelStream(body);
        cancelRequest();
        if (chunks != null) {
          try {
            await chunks.cancel().timeout(const Duration(seconds: 2));
          } catch (_) {}
        }
      }
    }
    throw HttpException('image_redirect_rejected');
  }

  static Future<void> _cancelStream(Stream<List<int>> stream) async {
    try {
      await stream.listen((_) {}, onError: (Object _) {}).cancel()
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  static String? detectSupportedMime(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 6) {
      final signature = String.fromCharCodes(bytes.take(6));
      if (signature == 'GIF87a' || signature == 'GIF89a') {
        return 'image/gif';
      }
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  static bool safePublicHttps(Uri? uri) {
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      return false;
    }
    final ip = InternetAddress.tryParse(host);
    if (ip == null) return true;
    if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast || host == '::') {
      return false;
    }
    if (ip.type == InternetAddressType.IPv4) {
      final parts = host.split('.').map(int.parse).toList(growable: false);
      return !(parts[0] == 10 ||
          parts[0] == 127 ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 192 && parts[1] == 168));
    }
    return host != '::1' &&
        !host.startsWith('fc') &&
        !host.startsWith('fd') &&
        !host.startsWith('fe8') &&
        !host.startsWith('fe9') &&
        !host.startsWith('fea') &&
        !host.startsWith('feb');
  }
}
