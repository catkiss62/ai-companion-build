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

/// Maps AI Companion's 19 semantic emotions plus the presentation-only normal
/// state to Sen's matching 20 stable IDs. `romantic_shy` is the single extra
/// Sen state and is reserved for the explicit undressed or NSFW presentation.
String senLive2DEmotionFor(
  String chatEmotionKey, {
  required String outfit,
  bool nsfwActive = false,
}) {
  if (outfit == 'undressed' || nsfwActive) return 'romantic_shy';
  final mapped = switch (chatEmotionKey.trim().toLowerCase()) {
    'nervous' => 'tense',
    'crying' => 'sad',
    'embarrassed' => 'ashamed',
    final value => value,
  };
  return senLive2DEmotionKeys.contains(mapped) ? mapped : 'normal';
}
