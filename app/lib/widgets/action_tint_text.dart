import 'package:flutter/material.dart';

class ActionTextSegment {
  const ActionTextSegment(this.text, {required this.isAction});
  final String text;
  final bool isAction;
}

class DialogueTextSegment {
  const DialogueTextSegment(this.text, {required this.isDialogue});
  final String text;
  final bool isDialogue;
}

List<DialogueTextSegment> splitDialogueText(String text) {
  if (text.isEmpty) return const [];
  final matches =
      RegExp(r'「[^」\n]*」|“[^”\n]*”|"[^"\n]*"').allMatches(text);
  final segments = <DialogueTextSegment>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      segments.add(DialogueTextSegment(
        text.substring(cursor, match.start),
        isDialogue: false,
      ));
    }
    segments.add(DialogueTextSegment(
      text.substring(match.start, match.end),
      isDialogue: true,
    ));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(DialogueTextSegment(
      text.substring(cursor),
      isDialogue: false,
    ));
  }
  return segments;
}

List<ActionTextSegment> splitActionText(String text) {
  if (text.isEmpty) return const [];
  final matches = RegExp(r'（[^（）\n]*）|\([^()\n]*\)').allMatches(text);
  final segments = <ActionTextSegment>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      segments.add(ActionTextSegment(
        text.substring(cursor, match.start),
        isAction: false,
      ));
    }
    segments.add(ActionTextSegment(
      text.substring(match.start, match.end),
      isAction: true,
    ));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(ActionTextSegment(text.substring(cursor), isAction: false));
  }
  return segments;
}

class ActionTintText extends StatelessWidget {
  const ActionTintText({super.key, required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final action = base.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.normal,
    );
    final dialogue = base.copyWith(
      color: Theme.of(context).colorScheme.tertiary,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
    );
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final segment in splitDialogueText(text))
            TextSpan(
              text: segment.text,
              style: segment.isDialogue ? dialogue : action,
            ),
        ],
      ),
    );
  }
}
