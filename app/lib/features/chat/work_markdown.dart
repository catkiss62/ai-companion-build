import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/platform/android_bridge.dart';

const workSurface = Color(0xff18181c);
const workRaised = Color(0xff2a2a30);
const workInk = Color(0xfff0eff3);
const workMuted = Color(0xffbab8c2);
const workAccent = Color(0xffcbb8f0);
const workLine = Color(0xff414047);

class WorkMarkdown extends StatefulWidget {
  const WorkMarkdown(this.source, {super.key});
  final String source;

  @override
  State<WorkMarkdown> createState() => _WorkMarkdownState();
}

class _WorkMarkdownState extends State<WorkMarkdown>
    implements MarkdownBuilderDelegate {
  final links = <TapGestureRecognizer>[];
  List<Widget> blocks = [];
  void clearLinks() {
    for (final link in links) {
      link.dispose();
    }
    links.clear();
  }

  @override
  void dispose() {
    clearLinks();
    super.dispose();
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final link = TapGestureRecognizer()
      ..onTap = () async {
        if (href == null) return;
        final opened = await AndroidBridge.instance.openExternalHttpsUrl(href);
        if (!opened && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法打开此链接')));
        }
      };
    links.add(link);
    return link;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) =>
      TextSpan(text: code, style: styleSheet.code);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    render();
  }

  @override
  void didUpdateWidget(WorkMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) render();
  }

  void render() {
    clearLinks();
    const body = TextStyle(
      color: workInk,
      fontSize: 14,
      height: 24 / 14,
      letterSpacing: 0,
    );
    TextStyle heading(double size, double line) => body.copyWith(
      fontSize: size,
      height: line / size,
      fontWeight: size > 14 ? FontWeight.w700 : FontWeight.w600,
    );
    final style = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      h1: heading(21, 30),
      h2: heading(19, 28),
      h3: heading(18, 26),
      h4: heading(14, 24),
      h5: heading(14, 24),
      h6: heading(14, 24),
      strong: const TextStyle(fontWeight: FontWeight.w600, color: workInk),
      a: const TextStyle(
        color: Color(0xffa6baff),
        decoration: TextDecoration.underline,
      ),
      code: const TextStyle(
        color: workInk,
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: workRaised,
      ),
      blockSpacing: 6,
      listIndent: 18,
      listBulletPadding: EdgeInsets.zero,
      listBullet: body,
      blockquote: body.copyWith(color: workMuted),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: workLine, width: 3)),
      ),
      codeblockDecoration: BoxDecoration(
        color: workRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      tableColumnWidth: const FixedColumnWidth(145),
      tableHead: heading(14, 24),
      tableBody: body.copyWith(fontSize: 14),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      tableBorder: const TableBorder(
        horizontalInside: BorderSide(color: workLine),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: workLine)),
      ),
    );
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    final nodes = document.parseLines(
      const LineSplitter().convert(widget.source),
    );
    final renderer = MarkdownBuilder(
      delegate: this,
      selectable: true,
      styleSheet: style,
      imageDirectory: null,
      imageBuilder: (_, title, alt) => Text(alt ?? title ?? '图片', style: body),
      checkboxBuilder: null,
      bulletBuilder: null,
      builders: {'pre': _CodeBlock()},
      paddingBuilders: {},
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
    );
    blocks = [];
    String previous = '';
    for (final node in nodes) {
      final tag = node is md.Element ? node.tag : '';
      if (blocks.isNotEmpty) {
        final headingList =
            const {'h4', 'h5', 'h6'}.contains(previous) &&
            const {'ol', 'ul'}.contains(tag);
        final tall =
            const {'h1', 'h2', 'h3', 'hr'}.contains(tag) || previous == 'hr';
        blocks.add(
          SizedBox(
            height: headingList
                ? 8
                : tall
                ? 32
                : 16,
          ),
        );
      }
      blocks.addAll(renderer.build([node]));
      previous = tag;
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks);
}

class _CodeBlock extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final language =
        code?.attributes['class']?.replaceFirst('language-', '') ?? '';
    final value = (code ?? element).textContent.replaceFirst(
      RegExp(r'\n$'),
      '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language.isEmpty ? '代码' : language,
                  style: const TextStyle(color: workMuted, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: '复制代码',
                iconSize: 17,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('代码已复制')));
                },
                icon: const Icon(Icons.copy_outlined, color: workMuted),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SelectableText(
            value,
            style: const TextStyle(
              color: workInk,
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
