import 'package:flutter/material.dart';

import '../core/personality/personality_catalog.dart';

List<String> activeTrialCapsuleLabels({
  String personalityBaseKey = '',
  String specialStyleKey = '',
}) => [
      if (PersonalityCatalog.isKnownBase(personalityBaseKey))
        PersonalityCatalog.base(personalityBaseKey).label,
      if (PersonalityCatalog.isKnownSpecial(specialStyleKey))
        PersonalityCatalog.special(specialStyleKey).label,
    ];

class ActiveTrialCapsule extends StatelessWidget {
  const ActiveTrialCapsule({
    super.key,
    required this.labels,
    this.onTap,
  });

  final List<String> labels;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = labels
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final capsule = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.62,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.94),
        shape: StadiumBorder(
          side: BorderSide(color: colors.primary.withValues(alpha: 0.72)),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        visible.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.normal,
            ),
      ),
    );
    if (onTap == null) return capsule;
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: capsule),
    );
  }
}
