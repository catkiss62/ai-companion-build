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

class WorkMarkdown extends StatelessWidget {
  const WorkMarkdown(this.source, {super.key});
  final String source;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      color: workInk,
      fontSize: 15.5,
      height: 1.58,
      letterSpacing: 0,
    );
    TextStyle heading(double size) => body.copyWith(
      fontSize: size,
      height: 1.34,
      fontWeight: FontWeight.w600,
    );
    return MarkdownBody(
      data: source,
      selectable: true,
      fitContent: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        h1: heading(22),
        h2: heading(19),
        h3: heading(17),
        h4: heading(16),
        h5: heading(15.5),
        h6: heading(15.5),
        strong: const TextStyle(fontWeight: FontWeight.w700, color: workInk),
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
        blockSpacing: 12,
        listIndent: 21,
        listBullet: body,
        blockquote: body.copyWith(color: workMuted),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 3, 4, 3),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: workLine, width: 3)),
        ),
        codeblockDecoration: BoxDecoration(
          color: workRaised,
          borderRadius: BorderRadius.circular(10),
        ),
        tableColumnWidth: const FixedColumnWidth(145),
        tableHead: heading(14),
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
      ),
      imageBuilder: (uri, title, alt) =>
          Text(alt ?? title ?? '图片', style: body),
      onTapLink: (_, url, _) async {
        if (url == null) return;
        final opened = await AndroidBridge.instance.openExternalHttpsUrl(url);
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法打开此链接')));
        }
      },
      builders: {'pre': _CodeBlock()},
    );
  }
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
