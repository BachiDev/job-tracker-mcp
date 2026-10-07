import 'package:flutter/material.dart';

/// bachi.dev tokens as Material 3 dark ThemeData (PLAN §5).
/// Base zinc-950, raised zinc-900, violet accent, mono accents only.
class AppTheme {
  static const base = Color(0xFF09090B);
  static const raised = Color(0xFF18181B);
  static const heading = Color(0xFFF4F4F5);
  static const body = Color(0xFFD4D4D8);
  static const muted = Color(0xFFA1A1A6);
  static const violet = Color(0xFFA78BFA);
  static const violetDeep = Color(0xFF8B5CF6);
  static const border = Color(0x1AFFFFFF); // white/10
  static const success = Color(0xFF34D399);
  static const error = Color(0xFFF87171);

  static const monoFont = 'JetBrainsMono';
  static const bodyFont = 'Inter';

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: violetDeep,
      brightness: Brightness.dark,
    ).copyWith(
      surface: base,
      surfaceContainerHighest: raised,
      primary: violet,
      onSurface: heading,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      fontFamily: bodyFont,
      cardTheme: const CardThemeData(
        color: raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// Stage pill colors (always with text labels, never color-alone).
Color stageColor(String stage) => switch (stage) {
  'saved' => AppTheme.muted,
  'applied' => const Color(0xFF60A5FA),
  'screening' => const Color(0xFF22D3EE),
  'interview' => AppTheme.violet,
  'offer' => const Color(0xFFFBBF24),
  'accepted' => AppTheme.success,
  'rejected' => AppTheme.error,
  'withdrawn' => AppTheme.muted,
  _ => AppTheme.muted,
};
