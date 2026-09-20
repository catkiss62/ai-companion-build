const senLive2DEmotionKeys = <String>{
  'normal',
  'happy',
  'excited',
  'affection',
  'shy',
  'romantic_shy',
  'flustered',
  'tense',
  'worried',
  'confused',
  'helpless',
  'afraid',
  'angry',
  'sad',
  'disgust',
  'serious',
  'surprised',
  'confident',
  'playful',
  'ashamed',
  'calm',
};

const senLive2DOutfitKeys = <String>{
  'maid',
  'white_shirt',
  'bunny',
  'undressed',
};

/// Maps the existing AI Companion presentation envelope to Sen's stable IDs.
/// `romantic_shy` remains a visual-only state for the explicit undressed view.
String senLive2DEmotionFor(String chatEmotionKey, {required String outfit}) {
  if (outfit == 'undressed') return 'romantic_shy';
  final mapped = switch (chatEmotionKey.trim().toLowerCase()) {
    'nervous' => 'tense',
    'crying' => 'sad',
    'embarrassed' => 'ashamed',
    final value => value,
  };
  return senLive2DEmotionKeys.contains(mapped) ? mapped : 'normal';
}
