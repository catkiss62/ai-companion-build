import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/stickers/sticker_pack.dart';
import '../../core/stickers/sticker_pack_storage.dart';

class SelectedUserSticker {
  const SelectedUserSticker({
    required this.pack,
    required this.record,
    required this.file,
  });

  final StickerPackMeta pack;
  final StickerRecord record;
  final File file;
}

class _StickerPickerItem {
  const _StickerPickerItem({
    required this.pack,
    required this.record,
    required this.file,
  });

  final StickerPackMeta pack;
  final StickerRecord record;
  final File file;

  SelectedUserSticker get selection =>
      SelectedUserSticker(pack: pack, record: record, file: file);
}

class StickerPickerSheet extends StatefulWidget {
  const StickerPickerSheet({required this.storage, super.key});

  final StickerPackStorage storage;

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  List<StickerPackMeta> _packs = const <StickerPackMeta>[];
  List<_StickerPickerItem> _items = const <_StickerPickerItem>[];
  String? _packId;
  String? _tag;
  String? _error;
  bool _loading = true;
  OverlayEntry? _preview;
  bool _editing = false;
  bool _saving = false;
  final Map<String, String> _drafts = {};

  String _caption(_StickerPickerItem item) =>
      _drafts[item.record.usageKey] ?? item.record.caption;

  void _beginEdit() {
    _hidePreview();
    setState(() {
      _drafts.clear();
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _drafts.clear();
      _editing = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.storage.saveCaptionEdits(Map.of(_drafts));
      if (!mounted) return;
      setState(() {
        _items = [
          for (final item in _items)
            _StickerPickerItem(
              pack: item.pack,
              file: item.file,
              record: _drafts.containsKey(item.record.usageKey)
                  ? item.record.withCaption(_drafts[item.record.usageKey]!)
                  : item.record,
            ),
        ];
        _drafts.clear();
        _editing = false;
      });
    } catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('保存失败'),
            content: Text('草稿仍保留，可重试。$error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editItem(_StickerPickerItem item) async {
    _hidePreview();
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StickerCaptionDialog(
        file: item.file,
        initial: _caption(item),
        baseline: item.record.caption,
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (value == item.record.caption) {
        _drafts.remove(item.record.usageKey);
      } else {
        _drafts[item.record.usageKey] = value;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final enabledIds = await widget.storage.enabledPackIds();
      final packs = (await widget.storage.scanPacks())
          .where((pack) => enabledIds.contains(pack.id))
          .toList(growable: false);
      final items = <_StickerPickerItem>[];
      for (final pack in packs) {
        final records = await widget.storage.readRecords(pack);
        for (final record in records) {
          if (!StickerAgencyPolicy.isVisible(record)) {
            continue;
          }
          items.add(
            _StickerPickerItem(
              pack: pack,
              record: record,
              file: await widget.storage.fileFor(pack, record),
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _packs = packs;
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取表情包失败：$error';
      });
    }
  }

  List<_StickerPickerItem> get _packItems => _packId == null
      ? _items
      : _items.where((item) => item.pack.id == _packId).toList(growable: false);

  String _tagLabel(String tag) =>
      _packs.any((pack) => pack.id.startsWith('user-') && pack.name == tag)
      ? tag
      : StickerDisplayLabels.tagName(tag);

  List<String> get _tags {
    final tags =
        _packItems
            .map((item) => StickerAgencyPolicy.categoryKey(item.record))
            .toSet()
            .toList()
          ..sort(
            (a, b) => StickerDisplayLabels.tagName(
              a,
            ).compareTo(StickerDisplayLabels.tagName(b)),
          );
    final custom = _packs
        .where((pack) => pack.id.startsWith('user-'))
        .map((pack) => pack.name)
        .toList();
    tags.sort((a, b) {
      final ia = custom.indexOf(a), ib = custom.indexOf(b);
      if (ia >= 0 || ib >= 0) {
        return (ia < 0 ? -1 : ia).compareTo(ib < 0 ? -1 : ib);
      }
      return StickerDisplayLabels.tagName(
        a,
      ).compareTo(StickerDisplayLabels.tagName(b));
    });
    return tags;
  }

  List<_StickerPickerItem> get _visibleItems {
    final packItems = _packItems;
    final tag = _tag;
    return tag == null
        ? packItems
        : packItems
              .where(
                (item) => StickerAgencyPolicy.categoryKey(item.record) == tag,
              )
              .toList(growable: false);
  }

  void _showPreview(_StickerPickerItem item) {
    _hidePreview();
    final overlay = Overlay.of(context, rootOverlay: true);
    _preview = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.22),
          child: Center(
            child: Material(
              elevation: 14,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 240,
                  maxWidth: 300,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Image.file(
                          item.file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 220,
                            height: 220,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _caption(item),
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_preview!);
  }

  void _hidePreview() {
    _preview?.remove();
    _preview = null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('sticker-picker-barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: _editing || _saving ? null : () => Navigator.pop(context),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.54)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: _sheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : _packs.isEmpty
            ? const Center(child: Text('还没有启用的表情包，请先到设置中导入并开启。'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _editing
                                ? '修改表情包 · 确认后点击保存才生效'
                                : '选择表情包 · 长按预览，单击放入输入框',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (!_editing)
                          TextButton(
                            onPressed: _beginEdit,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB895E4),
                            ),
                            child: const Text('修改表情包'),
                          ),
                        if (_editing) ...[
                          TextButton(
                            onPressed: _saving ? null : _save,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDA8EBB),
                            ),
                            child: Text(_saving ? '保存中' : '保存'),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _cancelEdit,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDA8EBB),
                            ),
                            child: const Text('退出'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('全部大类 ${_items.length}'),
                          selected: _packId == null,
                          onSelected: (_) => setState(() {
                            _packId = null;
                            _tag = null;
                          }),
                        ),
                        for (final pack in _packs) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              '${StickerDisplayLabels.packName(pack)} ${_items.where((item) => item.pack.id == pack.id).length}',
                            ),
                            selected: _packId == pack.id,
                            onSelected: (_) => setState(() {
                              _packId = pack.id;
                              _tag = null;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('全部小类 ${_packItems.length}'),
                          selected: _tag == null,
                          onSelected: (_) => setState(() => _tag = null),
                        ),
                        for (final tag in _tags) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              '${_tagLabel(tag)} ${_packItems.where((item) => StickerAgencyPolicy.categoryKey(item.record) == tag).length}',
                            ),
                            selected: _tag == tag,
                            onSelected: (_) => setState(() => _tag = tag),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 18),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _visibleItems.length,
                      itemBuilder: (context, index) {
                        final item = _visibleItems[index];
                        return GestureDetector(
                          onTap: _saving
                              ? null
                              : _editing
                              ? () => _editItem(item)
                              : () => Navigator.pop(context, item.selection),
                          onLongPressStart: _editing
                              ? null
                              : (_) => _showPreview(item),
                          onLongPressEnd: (_) => _hidePreview(),
                          onLongPressCancel: _hidePreview,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Image.file(
                                item.file,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StickerCaptionDialog extends StatefulWidget {
  const _StickerCaptionDialog({
    required this.file,
    required this.initial,
    required this.baseline,
  });
  final File file;
  final String initial;
  final String baseline;
  @override
  State<_StickerCaptionDialog> createState() => _StickerCaptionDialogState();
}

class _StickerCaptionDialogState extends State<_StickerCaptionDialog> {
  late final TextEditingController input = TextEditingController(
    text: widget.initial,
  );
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: '返回图库',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Image.file(
              widget.file,
              height: MediaQuery.sizeOf(context).height * 0.24,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sticker-caption-input'),
              controller: input,
              minLines: 2,
              maxLines: 4,
              maxLength: 240,
              decoration: InputDecoration(labelText: '表情描述', errorText: error),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    input.text = widget.baseline;
                    setState(() => error = null);
                  },
                  child: const Text('重置'),
                ),
                TextButton(
                  onPressed: () {
                    try {
                      Navigator.pop(
                        context,
                        StickerPackStorage.validateCaption(input.text),
                      );
                    } catch (_) {
                      setState(() => error = '请输入1–240字的描述');
                    }
                  },
                  child: const Text('确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
