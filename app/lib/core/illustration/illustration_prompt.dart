import 'whale_presets.dart';

class IllustrationPreset {
  const IllustrationPreset({
    required this.positive,
    required this.negative,
    required this.artists,
  });

  final List<String> positive;
  final List<String> negative;
  final List<String> artists;
}

class IllustrationPlan {
  const IllustrationPlan({
    required this.style,
    required this.scene,
    required this.description,
    this.outfit = '',
    this.appearance = '',
    this.camera = '',
    this.subject = '',
  });

  final String style;
  final String scene;
  final String description;
  final String outfit;
  final String appearance;
  final String camera;
  final String subject;

  bool get depictsCompanion => switch (subject) {
    'self' => true,
    'other' || 'unknown' => false,
    _ => whaleIllustrationPresets.containsKey(style) && appearance.isEmpty,
  };

  static const instructions =
      '输出 JSON，字段 style、subject、scene、camera、outfit、appearance、description。'
      'style: cute 可爱插画、mature 成熟插画、chibi Q版插画、free 自由创作。'
      '前三种都描绘同一个蓝发、耳鳍、鲸尾的鲸鱼娘，画风与她的性格状态、年龄或小豆丁无关。'
      '画其他人物、风景、物品或完全换形象时用 free，并自行描述主体。'
      'subject 表示目标角色：画你自己用 self，换装或换画风仍可为 self。画其他人物、风景或物品用 other，身份不明确用 unknown。'
      'scene 用简洁英文逗号标签描述主体、动作、表情、环境、光线。'
      'camera 用独立的英文镜头标签描述景别、视角，可自由选择，给一个一致的构图，例如 medium shot, from above。'
      '镜头、服装分别放 camera、outfit，避免重复写进 scene。默认女仆装时 outfit 留空，换装则写英文服装标签。'
      '临时换发色、发型或其他身份外观时，appearance 写替换后的完整主体特征，含要保留的耳鳍和鲸尾；平时留空。'
      'description 用一句中文描述绘图意图。画面保持非露骨，Q版全年龄。';

  static const styles = {'cute', 'mature', 'chibi', 'free'};
  static final _disallowed = RegExp(
    r'\b(nsfw|nude|nudity|naked|porn|explicit sex|sex act|genitals)\b|色情|裸体|性交',
    caseSensitive: false,
  );

  static IllustrationPlan? fromJson(Map<String, dynamic> data) {
    String field(String key, int limit) {
      final value = data[key];
      if (value is! String) return '';
      final text = value.trim().replaceAll(RegExp(r'[\r\n]+'), ' ');
      return text.length <= limit ? text : '';
    }

    final style = field('style', 16);
    final scene = field('scene', 640);
    final description = field('description', 180);
    final camera = field('camera', 160);
    final outfit = field('outfit', 240);
    final appearance = field('appearance', 300);
    final rawSubject = data['subject'];
    final subject = rawSubject is String
        ? rawSubject.trim()
        : rawSubject == null
        ? ''
        : 'unknown';
    if (!styles.contains(style) ||
        scene.isEmpty ||
        description.isEmpty ||
        _disallowed.hasMatch(
          '$scene $camera $outfit $appearance $description',
        )) {
      return null;
    }
    return IllustrationPlan(
      style: style,
      scene: scene,
      description: description,
      camera: camera,
      outfit: outfit,
      appearance: appearance,
      subject: const {'', 'self', 'other', 'unknown'}.contains(subject)
          ? subject
          : 'unknown',
    );
  }

  Map<String, String> toJson() => {
    'style': style,
    'scene': scene,
    'description': description,
    'camera': camera,
    'outfit': outfit,
    'appearance': appearance,
    'subject': subject,
  };
}

class IllustrationPrompt {
  const IllustrationPrompt(this.positive, this.negative);

  final String positive;
  final String negative;

  static const _quality = 'best quality, amazing quality, very aesthetic';
  static const _clothes = {
    'white maid headdress, frilled headdress, maid',
    'calf-length navy maid dress',
    'dark blue maid dress',
    'pleated white bodice',
    'puff shoulders and fitted long sleeves',
    'fitted navy waist with two rows of gold buttons',
    'gold embroidery along the skirt hem',
    'white ruffled apron with a small blue whale emblem',
    'large white bow at the back',
    'white stockings',
    'navy mary janes',
    'off shoulder',
    'off-shoulder sleeves',
    'boat neck',
    'lace-trimmed straps',
  };
  static const _identity = {
    'very long wavy hair fading from deep navy to pale cyan',
    'blue eyes',
    'curved ahoge',
    'drooping animal ears, short animal ears',
    'slightly drooping tapered ear tips',
    'one thick curved navy cetacean tail growing from the lower back',
    'pale underside',
    'two broad tail flukes',
    '1.15::small flat fin-shaped ears extending sideways from the sides of the head::',
    'short tapered ear tips angled slightly downward',
    'navy outer ears',
    'white scalloped inner ear edge',
    'blue ribbons at the ear bases',
  };
  static const _identityNegatives = {
    'light hair',
    'white hair',
    'big ears',
    'fish ears',
  };
  static const _legacyFraming = {'0.7::close-up::', 'full body'};

  factory IllustrationPrompt.compose(IllustrationPlan plan) {
    final preset = whaleIllustrationPresets[plan.style];
    return IllustrationPrompt(
      _join([
        if (preset != null)
          for (final tag in preset.positive)
            if ((plan.outfit.isEmpty || !_clothes.contains(tag)) &&
                (plan.appearance.isEmpty || !_identity.contains(tag)) &&
                (plan.camera.isEmpty || !_legacyFraming.contains(tag)))
              tag,
        if (plan.appearance.isNotEmpty) plan.appearance,
        if (plan.outfit.isNotEmpty) plan.outfit,
        plan.scene,
        ...?preset?.artists,
        _quality,
        if (plan.camera.isNotEmpty) plan.camera,
      ]),
      _join([
        for (final tag
            in preset?.negative ?? const ['nsfw', 'lowres', 'watermark'])
          if (plan.appearance.isEmpty || !_identityNegatives.contains(tag)) tag,
      ]),
    );
  }

  // Match the standard HTML page's comma ordering and duplicate handling.
  static String _join(Iterable<String> parts) {
    final seen = <String>{};
    return parts
        .expand((part) => part.split(','))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase()))
        .join(', ');
  }
}
