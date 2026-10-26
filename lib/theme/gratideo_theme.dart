import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gratideo's two looks: Morning Gold (day) and Night Watch (night).
/// Tokens come from the design spec; the app picks one by the clock.
class GColors extends ThemeExtension<GColors> {
  const GColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.gold,
    required this.goldText,
    required this.hairline,
    required this.primary,
    required this.onPrimary,
    required this.isNight,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color gold; // shapes, dots, accents
  final Color goldText; // labels that must read as text
  final Color hairline;
  final Color primary; // main button
  final Color onPrimary;
  final bool isNight;

  static const day = GColors(
    background: Color(0xFFFBF7EE),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF1B2640),
    muted: Color(0xFF5B6478),
    gold: Color(0xFFB08433),
    goldText: Color(0xFF8A6420),
    hairline: Color(0xFFECE4D3),
    primary: Color(0xFF1B2640),
    onPrimary: Color(0xFFFFFFFF),
    isNight: false,
  );

  static const night = GColors(
    background: Color(0xFF0E1014),
    surface: Color(0xFF181B22),
    ink: Color(0xFFECE6D9),
    muted: Color(0xFFA39C8F),
    gold: Color(0xFFE3A857),
    goldText: Color(0xFFE3A857),
    hairline: Color(0xFF272B34),
    primary: Color(0xFFE3A857),
    onPrimary: Color(0xFF1A1206),
    isNight: true,
  );

  @override
  GColors copyWith({Color? background}) => this;

  @override
  GColors lerp(ThemeExtension<GColors>? other, double t) => this;
}

extension GThemeX on BuildContext {
  GColors get g => Theme.of(this).extension<GColors>()!;
  TextStyle get display => Theme.of(this).textTheme.headlineLarge!;
  TextStyle get scripture => Theme.of(this).textTheme.titleLarge!;
  TextStyle get body => Theme.of(this).textTheme.bodyLarge!;
  TextStyle get label => Theme.of(this).textTheme.labelSmall!;
  TextStyle get small => Theme.of(this).textTheme.bodySmall!;
}

ThemeData buildTheme(GColors c) {
  final base = c.isNight ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final sans = GoogleFonts.dmSansTextTheme(base.textTheme).apply(bodyColor: c.ink, displayColor: c.ink);
  final text = sans.copyWith(
    headlineLarge: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w600, height: 1.25, color: c.ink, letterSpacing: -0.3),
    headlineMedium: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600, height: 1.25, color: c.ink),
    titleLarge: GoogleFonts.playfairDisplay(fontSize: 21, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, height: 1.38, color: c.ink),
    bodyLarge: GoogleFonts.dmSans(fontSize: 15, height: 1.4, color: c.ink),
    bodyMedium: GoogleFonts.dmSans(fontSize: 14, height: 1.4, color: c.ink),
    bodySmall: GoogleFonts.dmSans(fontSize: 12, height: 1.33, color: c.muted),
    labelSmall: GoogleFonts.dmSans(fontSize: 11, height: 1.45, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: c.goldText),
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    colorScheme: base.colorScheme.copyWith(primary: c.primary, onPrimary: c.onPrimary, surface: c.surface, onSurface: c.ink, secondary: c.gold),
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarTheme(backgroundColor: c.background, foregroundColor: c.ink, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(color: c.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.hairline))),
    dividerColor: c.hairline,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.isNight ? c.surface : c.background,
      hintStyle: TextStyle(color: c.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.hairline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.hairline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.gold, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: c.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.goldText, textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600))),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.isNight ? const Color(0xFF12141A) : c.surface,
      selectedItemColor: c.isNight ? c.gold : c.ink,
      unselectedItemColor: c.muted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w500),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.isNight ? const Color(0xFF15181F) : c.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
    sliderTheme: SliderThemeData(activeTrackColor: c.gold, thumbColor: c.gold, inactiveTrackColor: c.hairline),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.gold : c.hairline),
    ),
  );
}

/// Day runs 5:00 to 17:59; night the rest. Settings can force one.
GColors colorsFor(DateTime now, String mode) {
  if (mode == 'day') return GColors.day;
  if (mode == 'night') return GColors.night;
  return (now.hour >= 5 && now.hour < 18) ? GColors.day : GColors.night;
}
