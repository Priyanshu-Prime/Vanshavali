import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_spacing.dart';

/// App-wide design tokens + Material component themes.
///
/// Both themes are built from ONE function ([_build]) so light and dark can
/// never drift apart again (they had: a component styled in one theme was
/// routinely missed in the other). Screens should take colours from
/// `Theme.of(context).colorScheme` roles, never hard-code them.
///
/// Every ColorScheme role a screen reads is set explicitly. Leaving roles
/// like `outline` / `onPrimaryContainer` unset made Flutter fall back to
/// `onSurface` / `onPrimary` — that is what rendered empty-relation icons
/// pure black, and the dark-mode sibling avatar's initial dark-on-dark-green.
class AppTheme {
  // Brand colours (green brand + amber/orange accent).
  static const Color primaryColor = Color(0xFF1B5E20); // Dark Green
  static const Color primaryLight = Color(0xFF4CAF50); // Green
  static const Color primaryDark = Color(0xFF0D3610); // Darker Green
  static const Color primaryTint = Color(0xFFC8E6C9); // Green 100

  /// Accent for the primary floating action. Orange 900 rather than the old
  /// #FF6F00: white text on #FF6F00 was only ~2.8:1; on #E65100 it is 4.5:1.
  static const Color secondaryColor = Color(0xFFE65100);
  static const Color secondaryLight = Color(0xFFFFB300); // Amber (selection)

  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF7F8F7);
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF1C1C1C);
  static const Color lightTextSecondary = Color(0xFF616161);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkText = Color(0xFFEEEEEE);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // Family Tree Node Colors
  static const Color maleNodeColor = Color(0xFF1976D2); // Blue
  static const Color femaleNodeColor = Color(0xFFD81B60); // Pink
  static const Color otherNodeColor = Color(0xFF7B1FA2); // Purple
  static const Color unclaimedNodeColor = Color(0xFF9E9E9E); // Grey

  // Shape tokens — see docs/UI_UX_AUDIT.md "Design system".
  static const double radiusControl = 12; // buttons, inputs, chips
  static const double radiusCard = 16; // cards, list containers
  static const double radiusSheet = 24; // dialogs, bottom sheets

  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final text = isDark ? darkText : lightText;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    final scheme = isDark
        ? const ColorScheme.dark(
            primary: primaryLight,
            onPrimary: Colors.black,
            primaryContainer: primaryColor,
            onPrimaryContainer: primaryTint,
            secondary: secondaryLight,
            onSecondary: Colors.black,
            secondaryContainer: secondaryLight,
            onSecondaryContainer: Colors.black,
            surface: darkSurface,
            onSurface: darkText,
            onSurfaceVariant: darkTextSecondary,
            surfaceContainerHighest: Color(0xFF2A2A2A),
            error: Color(0xFFEF5350),
            onError: Colors.black,
            errorContainer: Color(0xFF5C1A1A),
            onErrorContainer: Color(0xFFFFDAD6),
            outline: Color(0xFF9E9E9E),
            outlineVariant: Color(0xFF3A3A3A),
          )
        : const ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            primaryContainer: primaryTint,
            onPrimaryContainer: primaryDark,
            secondary: secondaryColor,
            onSecondary: Colors.white,
            secondaryContainer: secondaryLight,
            onSecondaryContainer: Colors.black,
            surface: lightSurface,
            onSurface: lightText,
            onSurfaceVariant: lightTextSecondary,
            surfaceContainerHighest: Color(0xFFF0F2F0),
            error: errorColor,
            onError: Colors.white,
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            outline: Color(0xFF757575),
            outlineVariant: Color(0xFFE0E0E0),
          );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusControl),
    );
    final buttonText = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );
    const buttonMinSize = Size(64, AppSpacing.minTapTarget);
    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c, width: w),
        );

    // Overlay for the green (light) / dark-surface (dark) app bar: white
    // status-bar icons in both cases.
    const appBarOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkSurface : primaryColor,
        foregroundColor: isDark ? darkText : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: appBarOverlay,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? darkText : Colors.white,
        ),
      ),
      // The only TabBar (Directory) sits in AppBar.bottom on the app bar
      // colour. M3 defaults (selected = primary) are green-on-green there.
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? darkText : Colors.white,
        unselectedLabelColor: isDark ? darkTextSecondary : Colors.white70,
        indicatorColor: isDark ? darkText : Colors.white,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle:
            GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      // Type scale: Poppins for headings/labels, Noto Sans (has Gujarati
      // glyphs) for body. Section headings everywhere use titleLarge.
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
            fontSize: 32, fontWeight: FontWeight.bold, color: text),
        displayMedium: GoogleFonts.poppins(
            fontSize: 28, fontWeight: FontWeight.bold, color: text),
        displaySmall: GoogleFonts.poppins(
            fontSize: 24, fontWeight: FontWeight.w600, color: text),
        headlineMedium: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w600, color: text),
        headlineSmall: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w600, color: text),
        titleLarge: GoogleFonts.poppins(
            fontSize: 17, fontWeight: FontWeight.w600, color: text),
        titleMedium: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w500, color: text),
        titleSmall: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: text),
        bodyLarge: GoogleFonts.notoSans(fontSize: 16, color: text),
        bodyMedium: GoogleFonts.notoSans(fontSize: 14, color: text),
        bodySmall: GoogleFonts.notoSans(fontSize: 13, color: textSecondary),
        labelLarge: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: text),
      ),
      // One button shape everywhere. FilledButton had no theme before, so it
      // rendered as an M3 pill next to 12dp-rounded Elevated/Outlined buttons
      // (Requests: pill "Approve" beside a rounded-rect "Reject").
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: buttonMinSize,
          shape: controlShape,
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonMinSize,
          side: BorderSide(color: scheme.outline),
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // ChoiceChip/FilterChip default to ~32dp — below the 48dp floor. The
      // padding pushes them past AppSpacing.minTapTarget. An explicit label
      // colour is required: with only a font set, M3 skips its default
      // label-colour resolution and unselected text went invisible.
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        shape: controlShape,
        side: BorderSide(color: scheme.outline),
        labelStyle: GoogleFonts.notoSans(fontSize: 15, color: text),
        // Selected chip sits on the amber secondaryContainer: dark text.
        secondaryLabelStyle:
            GoogleFonts.notoSans(fontSize: 15, color: lightText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        disabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary, 2),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 2),
        labelStyle: GoogleFonts.notoSans(fontSize: 15, color: textSecondary),
        hintStyle: GoogleFonts.notoSans(fontSize: 15, color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      // Flat cards with a hairline border instead of a 2dp drop shadow: the
      // shadows stacked into a heavy, blurry look on long forms.
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape: controlShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        contentTextStyle: GoogleFonts.notoSans(fontSize: 16, color: text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle:
            GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.notoSans(fontSize: 13),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 3,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkText : lightText,
        contentTextStyle: GoogleFonts.notoSans(
          fontSize: 15,
          color: isDark ? Colors.black : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Status-bar style for screens with NO app bar (login, sign-up,
  /// onboarding): dark icons on the light background, light icons in dark
  /// mode. Applied app-wide in `main.dart`; an AppBar overrides it with
  /// [AppBarTheme.systemOverlayStyle] for its own area.
  static SystemUiOverlayStyle bodyOverlayStyle(Brightness brightness) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
      );

  static Color getNodeColor(String? gender, bool isClaimed) {
    if (!isClaimed) return unclaimedNodeColor;

    switch (gender) {
      case 'Male':
        return maleNodeColor;
      case 'Female':
        return femaleNodeColor;
      default:
        return otherNodeColor;
    }
  }
}
