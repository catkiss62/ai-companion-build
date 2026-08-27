import 'package:flutter/material.dart';

/// Matches the dialogue gold used by index.html's novel renderer.
const chatDialogueGold = Color(0xFFFDE68A);

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
  final matches = RegExp(
    r'「[^」\n]*(?:」|$)',
  ).allMatches(text);
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

/// Removes legacy action delimiters for presentation without changing the
/// stored source used by segment parsing, TTS or historical compatibility.
/// An unmatched opening delimiter at the start of a streaming line is hidden
/// immediately so it does not flash and then disappear when the line closes.
String stripActionDelimitersForDisplay(String text) {
  var result = text.replaceAllMapped(
    RegExp(r'（([^（）\n]*)）|\(([^()\n]*)\)'),
    (match) => match.group(1) ?? match.group(2) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'(^|\n)[（(](?=[^）)\n]*(?:$|\n))', multiLine: true),
    (match) => match.group(1) ?? '',
  );
  // Removing action brackets must not remove the established visual pause
  // between an action/state line and the following corner-quoted dialogue.
  return result.replaceAllMapped(
    RegExp(r'([^\n])\n(?=「)'),
    (match) => '${match.group(1)}\n\n',
  );
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
      color: chatDialogueGold,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
    );
    final visibleText = stripActionDelimitersForDisplay(text);
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final segment in splitDialogueText(visibleText))
            TextSpan(
              text: segment.text,
              style: segment.isDialogue ? dialogue : action,
            ),
        ],
      ),
    );
  }
}

/// Immersive-room prose keeps ordinary narration upright and only colors
/// corner-quoted dialogue. Unlike normal chat presentation it never removes
/// parentheses or treats the whole narration as an action block.
class NovelTintText extends StatelessWidget {
  const NovelTintText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style).copyWith(
          fontStyle: FontStyle.normal,
          fontWeight: FontWeight.normal,
        );
    final dialogue = base.copyWith(color: chatDialogueGold);
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final segment in splitDialogueText(text))
            TextSpan(
              text: segment.text,
              style: segment.isDialogue ? dialogue : base,
            ),
        ],
      ),
    );
  }
}
