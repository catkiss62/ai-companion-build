import 'dart:io';
import 'work_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkHtmlCard extends StatefulWidget {
  const WorkHtmlCard({super.key, required this.title, required this.load});
  final String title;
  final Future<String> Function() load;
  @override
  State<WorkHtmlCard> createState() => _WorkHtmlCardState();
}

class _WorkHtmlCardState extends State<WorkHtmlCard> {
  Future<String>? document;
  bool source = false;

  Widget page(String html) => AndroidView(viewType: 'ai_companion/work_html',
      creationParams: {'html': html}, creationParamsCodec: const StandardMessageCodec());

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        icon: Icon(document == null ? Icons.expand_more : Icons.expand_less),
        label: Text(widget.title),
        onPressed: () => setState(() {
          document = document == null ? widget.load() : null;
        }),
      ),
      if (document != null)
        FutureBuilder<String>(future: document, builder: (context, snap) {
          if (snap.hasError) return const Text('无法读取此版本的作品，可收起后重试');
          if (!snap.hasData) return const LinearProgressIndicator();
          final html = snap.requireData;
          return Column(children: [
            Wrap(alignment: WrapAlignment.center, children: [
              if (Platform.isAndroid)
                TextButton(onPressed: () => setState(() => source = !source),
                  child: Text(source ? '预览' : '源码')),
              WorkCopyButton('源码', html),
              if (Platform.isAndroid)
                TextButton.icon(icon: const Icon(Icons.fullscreen), label: const Text('全屏'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(appBar: AppBar(title: Text(widget.title)),
                      body: SafeArea(child: page(html)))))),
              ]),
            if (Platform.isAndroid && !source) SizedBox(height: 320, child: page(html))
            else ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(child: SelectableText(html))),
          ]);
        }),
    ],
  );
}
