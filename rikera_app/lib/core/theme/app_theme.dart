import 'package:flutter/material.dart';

/// Application theme configuration optimized for driving visibility.
///
/// Provides day and night themes with high contrast colors, large fonts,
/// and touch targets suitable for use while driving.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Day mode theme optimized for driving visibility
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
      textTheme: _textTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      floatingActionButtonTheme: _fabTheme,
      cardTheme: _cardTheme,
      appBarTheme: _appBarTheme(Brightness.light),
      iconTheme: _iconTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.comfortable,
    );
  }

  /// Night mode theme optimized for night driving
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      textTheme: _textTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      floatingActionButtonTheme: _fabTheme,
      cardTheme: _cardTheme,
      appBarTheme: _appBarTheme(Brightness.dark),
      iconTheme: _iconTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.comfortable,
    );
  }

  /// Light color scheme with high contrast for day driving
  static final ColorScheme _lightColorScheme = ColorScheme.light(
    primary: AppColors.primaryLight,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight.withOpacity(0.2),
    onPrimaryContainer: AppColors.primaryLight,
    secondary: AppColors.secondaryLight,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.secondaryLight.withOpacity(0.2),
    onSecondaryContainer: AppColors.secondaryLight,
    error: AppColors.errorLight,
    onError: Colors.white,
    errorContainer: AppColors.errorLight.withOpacity(0.2),
    onErrorContainer: AppColors.errorLight,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onSurfaceLight,
    surfaceContainerHighest: AppColors.surfaceVariantLight,
    onSurfaceVariant: AppColors.onSurfaceVariantLight,
    outline: AppColors.outlineLight,
    shadow: Colors.black.withOpacity(0.15),
  );

  /// Dark color scheme with reduced brightness for night driving
  static final ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: AppColors.primaryDark,
    onPrimary: Colors.black,
    primaryContainer: AppColors.primaryDark.withOpacity(0.3),
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.secondaryDark,
    onSecondary: Colors.black,
    secondaryContainer: AppColors.secondaryDark.withOpacity(0.3),
    onSecondaryContainer: AppColors.secondaryDark,
    error: AppColors.errorDark,
    onError: Colors.black,
    errorContainer: AppColors.errorDark.withOpacity(0.3),
    onErrorContainer: AppColors.errorDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurfaceDark,
    surfaceContainerHighest: AppColors.surfaceVariantDark,
    onSurfaceVariant: AppColors.onSurfaceVariantDark,
    outline: AppColors.outlineDark,
    shadow: Colors.black.withOpacity(0.5),
  );

  /// Text theme with large, readable fonts for driving
  static const TextTheme _textTheme = TextTheme(
    // Display styles - for critical information
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.25,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      height: 1.16,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      height: 1.22,
    ),
    // Headline styles - for prominent information
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      height: 1.29,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: 0,
      height: 1.33,
    ),
    // Title styles - for section headers
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.27,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.50,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    // Body styles - for general content
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.5,
      height: 1.50,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.25,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.4,
      height: 1.33,
    ),
    // Label styles - for buttons and labels
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.45,
    ),
  );

  /// Elevated button theme with large touch targets
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );

  /// Outlined button theme with large touch targets
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );

  /// Floating action button theme
  static final FloatingActionButtonThemeData _fabTheme =
      FloatingActionButtonThemeData(
        sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
        iconSize: 24,
      );

  /// Card theme
  static const CardThemeData _cardTheme = CardThemeData(
    elevation: 2,
    margin: EdgeInsets.all(8),
  );

  /// App bar theme
  static AppBarTheme _appBarTheme(Brightness brightness) {
    return AppBarTheme(
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: brightness == Brightness.light
            ? AppColors.onSurfaceLight
            : AppColors.onSurfaceDark,
      ),
    );
  }

  /// Icon theme
  static const IconThemeData _iconTheme = IconThemeData(size: 24);
}

/// Color palette optimized for driving visibility
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // Light theme colors - high contrast for day driving
  static const Color primaryLight = Color(0xFF1976D2); // Blue
  static const Color secondaryLight = Color(0xFF388E3C); // Green
  static const Color errorLight = Color(0xFFD32F2F); // Red
  static const Color warningLight = Color(0xFFF57C00); // Orange
  static const Color surfaceLight = Color(0xFFFFFFFF); // White
  static const Color surfaceVariantLight = Color(0xFFF5F5F5); // Light gray
  static const Color onSurfaceLight = Color(0xFF212121); // Dark gray
  static const Color onSurfaceVariantLight = Color(0xFF757575); // Medium gray
  static const Color outlineLight = Color(0xFFBDBDBD); // Light gray

  // Dark theme colors - reduced brightness for night driving
  static const Color primaryDark = Color(0xFF64B5F6); // Light blue
  static const Color secondaryDark = Color(0xFF81C784); // Light green
  static const Color errorDark = Color(0xFFEF5350); // Light red
  static const Color warningDark = Color(0xFFFFB74D); // Light orange
  static const Color surfaceDark = Color(0xFF121212); // Very dark gray
  static const Color surfaceVariantDark = Color(0xFF1E1E1E); // Dark gray
  static const Color onSurfaceDark = Color(0xFFE0E0E0); // Light gray
  static const Color onSurfaceVariantDark = Color(0xFFBDBDBD); // Medium gray
  static const Color outlineDark = Color(0xFF424242); // Dark gray

  // Navigation-specific colors
  static const Color speedNormal = Color(0xFF4CAF50); // Green
  static const Color speedWarning = Color(0xFFFF9800); // Orange
  static const Color speedExceeded = Color(0xFFF44336); // Red

  // Map overlay colors
  static const Color routeColor = Color(0xFF2196F3); // Blue
  static const Color routeColorDark = Color(0xFF64B5F6); // Light blue
  static const Color locationMarker = Color(0xFF1976D2); // Blue
  static const Color locationMarkerDark = Color(0xFF64B5F6); // Light blue

  // Bookmark category colors
  static const Color bookmarkHome = Color(0xFF4CAF50); // Green
  static const Color bookmarkWork = Color(0xFF2196F3); // Blue
  static const Color bookmarkFavorite = Color(0xFFF44336); // Red
  static const Color bookmarkOther = Color(0xFF9C27B0); // Purple
}

/// Spacing constants for consistent layout
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Size constants for UI elements
class AppSizes {
  AppSizes._();

  // Minimum touch target size (48dp as per Material Design)
  static const double minTouchTarget = 48.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Button heights
  static const double buttonHeight = 48.0;
  static const double buttonHeightLarge = 56.0;

  // FAB sizes
  static const double fabSize = 56.0;
  static const double fabSizeMini = 40.0;
}
