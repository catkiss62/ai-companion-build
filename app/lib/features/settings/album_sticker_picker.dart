import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/models/companion_album.dart';
import '../../core/storage/companion_album_storage.dart';

/// Reads the existing album thumbnail; opening this picker creates no media.
class AlbumStickerPicker extends StatefulWidget {
  const AlbumStickerPicker({super.key, required this.db, required this.collectedHashes});
  final AppDatabase db;
  final Set<String> collectedHashes;
  @override
  State<AlbumStickerPicker> createState() => _AlbumStickerPickerState();
}

class _AlbumStickerPickerState extends State<AlbumStickerPicker> {
  final items = <CompanionAlbumItem>[];
  final previews = <String, Future<File>>{};
  bool loading = false, more = true;
  String? error;
  static const pageSize = 40;
  @override
  void initState() { super.initState(); _next(); }
  Future<void> _next() async {
    if (loading || !more) return;
    setState(() { loading = true; error = null; });
    try {
      final page = await widget.db.companionAlbumStickerPage(
        limit: pageSize, before: items.isEmpty ? null : items.last);
      if (!mounted) return;
      final storage = CompanionAlbumStorage(db: widget.db);
      setState(() {
        items.addAll(page);
        for (final item in page) {
          previews[item.id] = storage.fileFor(item.thumbnailPath);
        }
        more = page.length == pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => error = '相册加载失败，请重试');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('从相册收藏表情'),
    content: SizedBox(width: 440, height: MediaQuery.sizeOf(context).height * .55,
      child: Column(children: [
        const Text('仅显示带“表情包”标签且保留原图的图片，手动添加的标签同样有效。'),
        const SizedBox(height: 12),
        Expanded(child: ListView.builder(
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              if (loading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              if (error != null) return TextButton(onPressed: _next, child: Text(error!));
              if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('暂无可收藏表情。可先在相册中为图片添加“表情包”标签。'));
              return more ? TextButton(onPressed: _next, child: const Text('加载更多')) : const SizedBox.shrink();
            }
            final item = items[index];
            final collected = widget.collectedHashes.contains(item.originalContentSha256);
            return ListTile(
              leading: SizedBox(width: 56, height: 56, child: FutureBuilder<File>(
                future: previews[item.id], builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Icon(Icons.image_outlined);
                  return Image.file(snapshot.data!, width: 56, height: 56,
                    cacheWidth: 168, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
                })),
              title: Text(item.summary.isEmpty ? item.title : item.summary,
                maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: collected ? const Text('已收藏') : null,
              trailing: collected ? const Icon(Icons.check_circle_outline) : const Icon(Icons.add),
              enabled: !collected,
              onTap: collected ? null : () => Navigator.pop(context, item),
            );
          },
        )),
      ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))],
  );
}
