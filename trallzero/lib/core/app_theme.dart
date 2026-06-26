import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tema centralizado do Trall.
///
/// Use [AppTheme.dark] para obter o [ThemeData] configurado.
/// Qualquer ajuste de tema deve ser feito aqui — não inline nos widgets.
abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.amber,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: AppColors.bgBase,
      // ── SnackBar com visual do design system ──────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgTile,
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // ── BottomSheet com fundo padrão do design system ─────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.bgPanel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      // ── Dialogs ───────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      // ── Switches ──────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.amber;
          return Colors.white54;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.amber.withValues(alpha: 0.5);
          }
          return Colors.white12;
        }),
      ),
    );
  }
}
