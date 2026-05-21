import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Nepal-inspired colour palette
//   Primary   – deep mountain teal  #1B5E6B
//   Secondary – warm earthy ochre   #A0632A
//   Tertiary  – highland sage       #4A7C59
//   Error     – sunset crimson      #C62828
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // Raw palette constants used across the app for one-off overrides
  static const Color mountainTeal = Color(0xFF1B5E6B);
  static const Color earthOchre = Color(0xFFA0632A);
  static const Color highlandSage = Color(0xFF4A7C59);
  static const Color snowWhite = Color(0xFFF5F7F6);
  static const Color mistGray = Color(0xFFEAEDEB);
  static const Color charcoal = Color(0xFF1A1F1E);

  // Per-category accent colours — referenced in home & destination card
  static const Map<String, Color> categoryColours = {
    'trekking': Color(0xFF2E7D32),
    'cultural': Color(0xFF6A1B9A),
    'culture': Color(0xFF6A1B9A),
    'village': Color(0xFF558B2F),
    'nature': Color(0xFF00695C),
    'adventure': Color(0xFFE65100),
    'relaxation': Color(0xFF0277BD),
    'pilgrimage': Color(0xFF5D4037),
    'wildlife': Color(0xFF4E342E),
    'boating': Color(0xFF1565C0),
    'photography': Color(0xFF00838F),
    'spiritual': Color(0xFF7B1FA2),
    'scenic': Color(0xFF2E7D32),
  };

  static Color categoryColour(String cat) =>
      categoryColours[cat.toLowerCase()] ?? mountainTeal;

  // ── Light theme ────────────────────────────────────────────────────────────
  static ThemeData get theme {
    const seed = mountainTeal;

    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      secondary: earthOchre,
      tertiary: highlandSage,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: snowWhite,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: cs.surfaceTint,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // ── Typography ────────────────────────────────────────────────────────
      textTheme: TextTheme(
        // Display
        displayLarge: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: charcoal,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: charcoal,
        ),
        // Headline
        headlineLarge: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: charcoal,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: charcoal,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: charcoal,
        ),
        // Title
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: charcoal,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: charcoal,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: charcoal,
        ),
        // Body
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.55,
          color: charcoal.withValues(alpha: 0.85),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: charcoal.withValues(alpha: 0.80),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: charcoal.withValues(alpha: 0.65),
        ),
        // Label
        labelLarge: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        labelMedium: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelSmall: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: const Color(0xFFDDE3E0), width: 1),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: mistGray,
        selectedColor: cs.primaryContainer,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),

      // ── Input ─────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: charcoal.withValues(alpha: 0.40),
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD0D8D4), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD0D8D4), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFCDD5D1), width: 1),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),

      // ── NavigationBar ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: selected ? 26 : 24);
        }),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        indicatorColor: cs.primaryContainer,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4EAE7),
        space: 1,
        thickness: 1,
      ),

      // ── Bottom sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const seed = mountainTeal;
    const surface = Color(0xFF101817);
    const elevatedSurface = Color(0xFF172321);
    const outline = Color(0xFF31413E);

    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      secondary: earthOchre,
      tertiary: highlandSage,
    ).copyWith(
      surface: surface,
      surfaceContainerHighest: elevatedSurface,
      outlineVariant: outline,
    );

    final baseText = ThemeData.dark(useMaterial3: true).textTheme;
    final textTheme = baseText
        .apply(
          bodyColor: cs.onSurface,
          displayColor: cs.onSurface,
        )
        .copyWith(
          headlineLarge: baseText.headlineLarge?.copyWith(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
          headlineMedium: baseText.headlineMedium?.copyWith(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
          headlineSmall: baseText.headlineSmall?.copyWith(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
          titleLarge: baseText.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
          titleMedium: baseText.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          bodyMedium: baseText.bodyMedium?.copyWith(
            height: 1.55,
            color: cs.onSurface.withValues(alpha: 0.82),
          ),
          bodySmall: baseText.bodySmall?.copyWith(
            height: 1.5,
            color: cs.onSurfaceVariant,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: elevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: outline, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevatedSurface,
        selectedColor: cs.primaryContainer,
        labelStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
        side: BorderSide(color: outline),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: outline, width: 1),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: elevatedSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        indicatorColor: cs.primaryContainer,
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
