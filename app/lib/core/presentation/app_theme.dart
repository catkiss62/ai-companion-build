import 'package:flutter/material.dart';

abstract final class CompanionAppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFB082FF),
      useMaterial3: true,
    );
    const secondaryText = Color(0xFFA9A5B3);
    const helperText = Color(0xFF8B8796);
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: secondaryText),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: secondaryText),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: helperText),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: base.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: secondaryText,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        helperStyle: base.textTheme.bodySmall?.copyWith(color: helperText),
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: helperText),
      ),
    );
  }
}
