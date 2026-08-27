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
  final segments = <DialogueTextSegment>[];
  var cursor = 0;
  var index = 0;
  while (index < text.length) {
    if (text[index] != '「') {
      index++;
      continue;
    }

    final start = index;
    var depth = 1;
    index++;
    while (index < text.length && text[index] != '\n') {
      if (text[index] == '「') {
        depth++;
      } else if (text[index] == '」') {
        depth--;
        index++;
        if (depth == 0) break;
        continue;
      }
      index++;
    }

    // Preserve the established streaming behavior: an unmatched outer quote
    // is tinted through the current end of the stream. A malformed quote that
    // crosses a newline is left as ordinary text instead of swallowing the
    // following action block.
    final reachedEnd = index == text.length;
    if (depth != 0 && !reachedEnd) continue;
    final end = index;
    if (start > cursor) {
      segments.add(DialogueTextSegment(
        text.substring(cursor, start),
        isDialogue: false,
      ));
    }
    segments.add(DialogueTextSegment(
      text.substring(start, end),
      isDialogue: true,
    ));
    cursor = end;
  }
  if (cursor < text.length) {
    segments.add(DialogueTextSegment(
      text.substring(cursor),
      isDialogue: false,
    ));
  }
  return segments;
}

/// Novel prose accepts the quote pairs commonly emitted by long-form models.
/// Normal chat intentionally keeps using [splitDialogueText], whose contract
/// only treats Chinese corner quotes as spoken dialogue.
List<DialogueTextSegment> splitNovelDialogueText(String text) {
  if (text.isEmpty) return const [];
  const openers = <String, String>{
    '「': '」',
    '“': '”',
    '"': '"',
  };
  final segments = <DialogueTextSegment>[];
  var cursor = 0;
  var index = 0;
  while (index < text.length) {
    final opener = text[index];
    final outerCloser = openers[opener];
    if (outerCloser == null) {
      index++;
      continue;
    }

    final start = index;
    final expectedClosers = <String>[outerCloser];
    index++;
    var crossedNewline = false;
    while (index < text.length && expectedClosers.isNotEmpty) {
      final character = text[index];
      if (character == '\n') {
        crossedNewline = true;
        break;
      }
      // Check the current closer first because ASCII double quotes use the
      // same character for both sides.
      if (character == expectedClosers.last) {
        expectedClosers.removeLast();
        index++;
        continue;
      }
      final nestedCloser = openers[character];
      if (nestedCloser != null) expectedClosers.add(nestedCloser);
      index++;
    }

    final reachedEnd = index == text.length;
    if (expectedClosers.isNotEmpty && (!reachedEnd || crossedNewline)) {
      index = start + 1;
      continue;
    }
    final end = index;
    if (start > cursor) {
      segments.add(DialogueTextSegment(
        text.substring(cursor, start),
        isDialogue: false,
      ));
    }
    segments.add(DialogueTextSegment(
      text.substring(start, end),
      isDialogue: true,
    ));
    cursor = end;
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
/// quoted dialogue. Unlike normal chat presentation it never removes
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
          for (final segment in splitNovelDialogueText(text))
            TextSpan(
              text: segment.text,
              style: segment.isDialogue ? dialogue : base,
            ),
        ],
      ),
    );
  }
}
