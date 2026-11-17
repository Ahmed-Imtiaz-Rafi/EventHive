import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light / dark switch for the whole admin area.
/// The admin shell listens to this and rebuilds the Theme, so every admin
/// screen follows the toggle without doing anything itself.
final ValueNotifier<bool> adminDarkMode = ValueNotifier<bool>(false);

/// Admin colour tokens. Read them in any admin screen with
/// `final c = AdminColors.of(context);`
@immutable
class AdminColors extends ThemeExtension<AdminColors> {
  final Color bg; // page background
  final Color surface; // cards, nav bar
  final Color border; // hairlines
  final Color ink; // primary text
  final Color muted; // secondary text
  final Color brand; // navy (light) / soft blue (dark): icons, selection
  final Color brandSoft; // tinted tile behind brand icons
  final Color accent; // amber: attention only
  final Color accentSoft; // tinted amber background

  const AdminColors({
    required this.bg,
    required this.surface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.brand,
    required this.brandSoft,
    required this.accent,
    required this.accentSoft,
  });

  static const light = AdminColors(
    bg: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE2E5EA),
    ink: Color(0xFF0F1B2D),
    muted: Color(0xFF5F6B7A),
    brand: Color(0xFF1B3A6B),
    brandSoft: Color(0xFFE8EEF7),
    accent: Color(0xFF9A6208),
    accentSoft: Color(0xFFFAF0DA),
  );

  static const dark = AdminColors(
    bg: Color(0xFF0E1218),
    surface: Color(0xFF151B24),
    border: Color(0xFF262E3A),
    ink: Color(0xFFE9ECF1),
    muted: Color(0xFF9AA4B2),
    brand: Color(0xFF8FB0E8),
    brandSoft: Color(0xFF1C2740),
    accent: Color(0xFFE3A93E),
    accentSoft: Color(0xFF2B2313),
  );

  static AdminColors of(BuildContext context) =>
      Theme.of(context).extension<AdminColors>() ?? light;

  @override
  AdminColors copyWith({
    Color? bg,
    Color? surface,
    Color? border,
    Color? ink,
    Color? muted,
    Color? brand,
    Color? brandSoft,
    Color? accent,
    Color? accentSoft,
  }) {
    return AdminColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  AdminColors lerp(ThemeExtension<AdminColors>? other, double t) {
    if (other is! AdminColors) return this;
    return AdminColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

/// Builds the admin ThemeData. Typeface: IBM Plex Sans (formal, institutional).
/// Big figures use IBM Plex Sans Condensed with tabular digits, see [numeral].
class AdminTheme {
  AdminTheme._();

  static final ThemeData _light = _build(false);
  static final ThemeData _dark = _build(true);

  static ThemeData of(bool dark) => dark ? _dark : _light;

  /// Style for headline statistics (counts, totals).
  static TextStyle numeral(Color color, {double size = 38}) {
    return GoogleFonts.ibmPlexSans(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: -0.5,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData _build(bool dark) {
    final c = dark ? AdminColors.dark : AdminColors.light;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = GoogleFonts.ibmPlexSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: c.ink, displayColor: c.ink);
    final onFilled = dark ? const Color(0xFF0E1218) : Colors.white;

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.brand,
        onPrimary: onFilled,
        secondary: c.accent,
        onSecondary: onFilled,
        error: dark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E),
        onError: dark ? const Color(0xFF601410) : Colors.white,
        surface: c.surface,
        onSurface: c.ink,
      ),
      textTheme: text,
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: c.brandSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.brand : c.muted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium!.copyWith(
            color: selected ? c.brand : c.muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.bg),
      ),
    );
  }
}
