import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/illustration/illustration_client.dart';
import '../../core/illustration/illustration_job.dart';
import '../../core/storage/media_blob_storage.dart';

/// Shows the asynchronous result even while the committed text is already open.
class IllustrationResultView extends StatefulWidget {
  const IllustrationResultView({
    required this.source,
    required this.ownerId,
    this.attachmentVisible = false,
    super.key,
  });

  final IllustrationSource source;
  final String ownerId;
  final bool attachmentVisible;

  @override
  State<IllustrationResultView> createState() => _IllustrationResultViewState();
}

class _IllustrationResultViewState extends State<IllustrationResultView> {
  late Stream<Map<String, dynamic>?> _state;
  String? _imageId;
  Future<({File thumbnail, File original})?>? _imageFiles;

  @override
  void initState() {
    super.initState();
    _state = _watch();
  }

  @override
  void didUpdateWidget(covariant IllustrationResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.ownerId != widget.ownerId) {
      _state = _watch();
    }
  }

  Stream<Map<String, dynamic>?> _watch() async* {
    final key = IllustrationJob.keyFor(widget.source, widget.ownerId);
    final db = AppDatabase.instance;
    try {
      while (mounted) {
        final state = IllustrationJob.decode(await db.getSetting(key));
        yield state;
        if (state?['state'] != 'queued') return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (_) {
      yield null;
    }
  }

  Future<({File thumbnail, File original})?> _files(String blobId) async {
    final db = AppDatabase.instance;
    final blob = await db.mediaBlobById(blobId);
    if (blob == null) return null;
    final storage = MediaBlobStorage(db: db);
    final thumbnail = await storage.fileFor(blob.thumbnailPath);
    final original = await storage.fileFor(blob.originalPath);
    if (!await thumbnail.exists() || !await original.exists()) return null;
    return (thumbnail: thumbnail, original: original);
  }

  Future<({File thumbnail, File original})?> _filesFor(String id) {
    if (_imageId != id || _imageFiles == null) {
      _imageId = id;
      _imageFiles = _files(id);
    }
    return _imageFiles!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachmentVisible) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _state,
      builder: (context, snapshot) {
        final state = snapshot.data;
        switch (state?['state']) {
          case 'queued':
            return _label('她在画图…');
          case 'failed':
            final failure = IllustrationFailure(
              state?['error']?.toString() ?? '',
            );
            if (failure.code == 'source_missing')
              return const SizedBox.shrink();
            return _label('配图失败 · ${failure.label}');
          case 'completed':
            final id = state?['blob_id'];
            if (id is! String || id.isEmpty) return const SizedBox.shrink();
            return FutureBuilder<({File thumbnail, File original})?>(
              future: _filesFor(id),
              builder: (context, files) {
                final image = files.data;
                if (image == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        child: InteractiveViewer(
                          child: Image.file(
                            image.original,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        image.thumbnail,
                        width: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(value, style: const TextStyle(fontSize: 12)),
  );
}
