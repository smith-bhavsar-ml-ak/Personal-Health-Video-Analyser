import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system tokens — dark (default)
abstract class AppColors {
  // Surfaces — dark
  static const background      = Color(0xFF0A0A0F);
  static const surface         = Color(0xFF111118);
  static const surfaceElevated = Color(0xFF16161F);
  static const surfaceTooltip  = Color(0xFF1C1C28);

  // Borders — dark
  static const border      = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const borderHover = Color(0x24FFFFFF); // rgba(255,255,255,0.14)

  // Brand (shared light+dark)
  static const primary    = Color(0xFF6366F1); // indigo
  static const primaryDim = Color(0xFF4F46E5);
  static const health     = Color(0xFF10B981); // emerald
  static const healthDim  = Color(0xFF059669);
  static const warning    = Color(0xFFF59E0B); // amber
  static const error      = Color(0xFFEF4444); // red
  static const info       = Color(0xFF38BDF8); // sky blue

  // Text — dark
  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);

  // Chart / exercise colors
  static const chart1 = Color(0xFF6366F1); // squat
  static const chart2 = Color(0xFF10B981); // jumping_jack
  static const chart3 = Color(0xFF38BDF8); // bicep_curl
  static const chart4 = Color(0xFFF59E0B); // lunge
  static const chart5 = Color(0xFFEC4899); // plank
}

/// Light-mode surface/text tokens (brand colors are identical).
abstract class AppColorsLight {
  static const background      = Color(0xFFF8FAFC); // slate-50
  static const surface         = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF1F5F9); // slate-100
  static const surfaceTooltip  = Color(0xFFE2E8F0); // slate-200

  static const border      = Color(0x14000000); // rgba(0,0,0,0.08)
  static const borderHover = Color(0x28000000); // rgba(0,0,0,0.16)

  static const textPrimary   = Color(0xFF0F172A); // slate-900
  static const textSecondary = Color(0xFF64748B); // slate-500
  static const textMuted     = Color(0xFF94A3B8); // slate-400
}

abstract class AppTheme {
  // ── Dark ────────────────────────────────────────────────────────────────────

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    bg:         AppColors.background,
    surf:       AppColors.surface,
    surfEl:     AppColors.surfaceElevated,
    surfTip:    AppColors.surfaceTooltip,
    bord:       AppColors.border,
    bordHov:    AppColors.borderHover,
    txtPri:     AppColors.textPrimary,
    txtSec:     AppColors.textSecondary,
    txtMut:     AppColors.textMuted,
  );

  // ── Light ───────────────────────────────────────────────────────────────────

  static ThemeData get light => _build(
    brightness: Brightness.light,
    bg:         AppColorsLight.background,
    surf:       AppColorsLight.surface,
    surfEl:     AppColorsLight.surfaceElevated,
    surfTip:    AppColorsLight.surfaceTooltip,
    bord:       AppColorsLight.border,
    bordHov:    AppColorsLight.borderHover,
    txtPri:     AppColorsLight.textPrimary,
    txtSec:     AppColorsLight.textSecondary,
    txtMut:     AppColorsLight.textMuted,
  );

  // ── Builder ──────────────────────────────────────────────────────────────────

  static ThemeData _build({
    required Brightness brightness,
    required Color bg, required Color surf, required Color surfEl,
    required Color surfTip, required Color bord, required Color bordHov,
    required Color txtPri, required Color txtSec, required Color txtMut,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      cardColor: surf,
      dividerColor: bord,
      colorScheme: ColorScheme(
        brightness:              brightness,
        surface:                 surf,
        surfaceContainerHighest: surfTip,
        surfaceContainerHigh:    surfEl,
        surfaceContainer:        surfEl,
        surfaceContainerLow:     bg,
        surfaceContainerLowest:  bg,
        primary:                 AppColors.primary,
        onPrimary:               Colors.white,
        primaryContainer:        AppColors.primary.withValues(alpha: 0.12),
        onPrimaryContainer:      AppColors.primary,
        secondary:           AppColors.health,
        onSecondary:         Colors.white,
        tertiary:            AppColors.health,
        onTertiary:          Colors.white,
        error:               AppColors.error,
        onError:             Colors.white,
        onSurface:           txtPri,
        onSurfaceVariant:    txtSec,
        outline:             bord,
        outlineVariant:      bordHov,
        shadow:              Colors.black,
        scrim:               Colors.black,
        inverseSurface:      isDark ? AppColorsLight.surface : AppColors.surface,
        onInverseSurface:    isDark ? AppColorsLight.textPrimary : AppColors.textPrimary,
        inversePrimary:      AppColors.primaryDim,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: txtPri),
        displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: txtPri),
        displaySmall:  GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: txtPri),
        headlineMedium:GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: txtPri),
        titleLarge:    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: txtPri),
        titleMedium:   GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: txtPri),
        bodyLarge:     GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: txtPri,  height: 1.6),
        bodyMedium:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: txtSec, height: 1.6),
        bodySmall:     GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: txtMut, height: 1.5),
        labelLarge:    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: txtPri),
        labelMedium:   GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: txtSec),
      ),
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: bord),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
          animationDuration: const Duration(milliseconds: 200),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txtPri,
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: bord),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfEl,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: txtMut),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: txtSec),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: bord),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: bord),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: txtPri, size: 24),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: txtPri,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surf,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: txtMut,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surf,
        selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: txtMut, size: 24),
        selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: txtMut, fontSize: 12),
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        useIndicator: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfTip,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: txtPri),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfEl,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: txtSec),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: bord),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0xFF16161F),
        circularTrackColor: Color(0xFF16161F),
      ),
      dividerTheme: DividerThemeData(color: bord, thickness: 1, space: 0),
      iconTheme: IconThemeData(color: txtSec, size: 24),
      listTileTheme: ListTileThemeData(
        iconColor: txtSec,
        textColor: txtPri,
        tileColor: surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: bord),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
        minVerticalPadding: 12,
      ),
    );
  }
}
