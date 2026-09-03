import 'package:flutter/material.dart';

const chatDialoguePurple = Color(0xFFD4BBFC);
const chatDialogueGold = Color(0xFFFDE68A);
const chatDialoguePink = Color(0xFFF1B7C5);

enum ChatDialogueColorOption {
  purple('purple', '浅紫', chatDialoguePurple),
  gold('gold', '浅黄', chatDialogueGold),
  pink('pink', '浅粉', chatDialoguePink);

  const ChatDialogueColorOption(this.key, this.label, this.color);

  static const settingKey = 'chat_dialogue_color';

  final String key;
  final String label;
  final Color color;

  static ChatDialogueColorOption fromSetting(String? value) =>
      ChatDialogueColorOption.values.firstWhere(
        (option) => option.key == value,
        orElse: () => ChatDialogueColorOption.purple,
      );
}

class ChatDialogueColorScope extends InheritedWidget {
  const ChatDialogueColorScope({
    required this.option,
    required super.child,
    super.key,
  });

  final ChatDialogueColorOption option;

  static ChatDialogueColorOption of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ChatDialogueColorScope>()
          ?.option ??
      ChatDialogueColorOption.purple;

  @override
  bool updateShouldNotify(ChatDialogueColorScope oldWidget) =>
      option != oldWidget.option;
}

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

/// Splits immersive prose by paragraph role rather than treating every quoted
/// phrase as dialogue. A spoken paragraph starts with a dialogue quote; quotes
/// embedded later in narration inherit narration styling. This also gives the
/// streaming renderer a stable answer from the first visible character.
List<DialogueTextSegment> splitNovelDialogueText(String text) {
  if (text.isEmpty) return const [];
  final segments = <DialogueTextSegment>[];
  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final visible = index == lines.length - 1 ? line : '$line\n';
    final trimmed = line.trimLeft();
    segments.add(DialogueTextSegment(
      visible,
      // Only corner quotes declare dialogue. Curly/ASCII quotes are quoted
      // content and inherit the paragraph's narration role.
      isDialogue: trimmed.startsWith('「'),
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
    final base = DefaultTextStyle.of(context).style.merge(style).copyWith(
          color: Colors.white,
        );
    final action = base.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.normal,
    );
    final dialogue = base.copyWith(
      color: ChatDialogueColorScope.of(context).color,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
    );
    final sourceStartsWithAction = RegExp(r'(^|\n)\s*[（(]', multiLine: true)
        .hasMatch(text);
    final visibleText = stripActionDelimitersForDisplay(text);
    final segments = splitDialogueText(visibleText);
    final hasExplicitDialogue = segments.any((segment) => segment.isDialogue);
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            TextSpan(
              text: segment.text,
              // A fully unquoted assistant reply is ordinary dialogue, not
              // one giant action. This is also the native-overlay contract.
              style: segment.isDialogue
                  ? dialogue
                  : hasExplicitDialogue || sourceStartsWithAction
                      ? action
                      : dialogue,
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
          color: Colors.white,
          fontStyle: FontStyle.normal,
          fontWeight: FontWeight.normal,
        );
    final dialogue = base.copyWith(
      color: ChatDialogueColorScope.of(context).color,
    );
    final segments = splitNovelDialogueText(text);
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            TextSpan(
              text: segment.text,
              style: segment.isDialogue ? dialogue : base,
            ),
        ],
      ),
    );
  }
}
