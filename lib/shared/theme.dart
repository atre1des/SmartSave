import 'package:flutter/material.dart';

abstract final class _Brand {
  static const mint = Color(0xFF8FD1B1);
  static const seafoam = Color(0xFF6DB5A7);
  static const turquoise = Color(0xFF549999);
  static const blueTeal = Color(0xFF437D87);
  static const slateTeal = Color(0xFF386271);
  static const slate = Color(0xFF2F4858);
  static const black = Color(0xFF020202);
  static const ice = Color(0xFFEDF5F5);
  static const sage = Color(0xFFB9CAB4);
  static const sand = Color(0xFFE0E0C9);
  static const deep = Color(0xFF033236);
  static const teal = Color(0xFF056E72);
  static const amber = Color(0xFFEEB760);
  static const deepTeal = Color(0xFF034044);
  static const white = Color(0xFFFFFFFF);
  static const green = Color(0xFF73BEA5);

  static final charcoal = Color.lerp(black, ice, .105)!;
}

class AppColors {
  const AppColors(this.brightness);

  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;
  Color get canvas => isDark ? _Brand.charcoal : _Brand.ice;
  Color get surface => isDark ? _Brand.deep : _Brand.white;
  Color get subtleSurface => isDark ? _Brand.deepTeal : _Brand.ice;
  Color get mutedSurface => isDark ? _Brand.slate : _Brand.sage;
  Color get noticeSurface => isDark ? _Brand.slate : _Brand.sand;
  Color get text => isDark ? _Brand.white : _Brand.deep;
  Color get muted => isDark ? _Brand.sage : _Brand.slateTeal;
  Color get outline => isDark ? _Brand.blueTeal : _Brand.sage;
  Color get fieldOutline => isDark ? _Brand.seafoam : _Brand.slateTeal;
  Color get action => isDark ? _Brand.mint : _Brand.teal;
  Color get primary => isDark ? _Brand.mint : _Brand.deep;
  Color get onPrimary => isDark ? _Brand.black : _Brand.white;
  Color get emphasis => _Brand.deep;
  Color get onEmphasis => _Brand.white;
  Color get emphasisMuted => _Brand.mint;
  Color get progress => isDark ? _Brand.green : _Brand.seafoam;
  Color get highlight => _Brand.green;
  Color get positive => action;
  Color get warning => isDark ? _Brand.sand : _Brand.slate;
  Color get error => isDark ? _Brand.sand : _Brand.deep;
  Color get premium => _Brand.amber;
  Color get onPremium => _Brand.black;
  Color get selection => isDark ? _Brand.mint : _Brand.deep;
  Color get onSelection => isDark ? _Brand.black : _Brand.white;
  List<Color> get chartSeries => isDark
      ? const [
          _Brand.mint,
          _Brand.seafoam,
          _Brand.blueTeal,
          _Brand.green,
          _Brand.sand,
        ]
      : const [
          _Brand.deep,
          _Brand.teal,
          _Brand.turquoise,
          _Brand.seafoam,
          _Brand.slate,
        ];
}

extension AppThemeContext on BuildContext {
  AppColors get colors => AppColors(Theme.of(this).brightness);
}

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final colors = AppColors(brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.action,
    onSecondary: colors.onPrimary,
    secondaryContainer: colors.selection,
    onSecondaryContainer: colors.onSelection,
    surface: colors.surface,
    onSurface: colors.text,
    onSurfaceVariant: colors.muted,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.subtleSurface,
    surfaceContainerHighest: colors.mutedSurface,
    outline: colors.fieldOutline,
    outlineVariant: colors.outline,
    error: colors.error,
    onError: colors.canvas,
    errorContainer: colors.noticeSurface,
    onErrorContainer: colors.text,
    inverseSurface: colors.emphasis,
    onInverseSurface: colors.onEmphasis,
    shadow: _Brand.black,
    scrim: _Brand.black,
    surfaceTint: Colors.transparent,
  );
  final text = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 24,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: colors.text,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: colors.text,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: colors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: colors.text,
    ),
    bodyLarge: TextStyle(fontSize: 14, height: 1.4, color: colors.text),
    bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: colors.text),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: colors.muted),
    labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );
  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    fontFamily: 'Inter',
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineLarge,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline),
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: colors.surface),
    dialogTheme: DialogThemeData(backgroundColor: colors.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: colors.surface),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: colors.subtleSurface,
      side: BorderSide(color: colors.fieldOutline),
      labelStyle: TextStyle(color: colors.text, fontFamily: 'Inter'),
      secondaryLabelStyle: TextStyle(color: colors.text),
      checkmarkColor: colors.action,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.progress,
      linearTrackColor: colors.mutedSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: fieldBorder(colors.fieldOutline),
      enabledBorder: fieldBorder(colors.fieldOutline),
      focusedBorder: fieldBorder(colors.action, 2),
      errorBorder: fieldBorder(colors.error, 2),
      focusedErrorBorder: fieldBorder(colors.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.action,
        side: BorderSide(color: colors.fieldOutline),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colors.action),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.emphasis,
      contentTextStyle: TextStyle(color: colors.onEmphasis),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
