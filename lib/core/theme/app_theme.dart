import 'package:flutter/material.dart';

class AppTheme {
  // Vibrant Purple Core Palette
  static const Color primaryColor = Color(0xFF7F3DFF); // Vibrant Digital Purple
  static const Color primaryLight = Color(0xFFEEE5FF);
  static const Color secondaryColor = Color(0xFF00B156); // Fresh Green for Success/Income
  static const Color expenseColor = Color(0xFFFD3C4A); // Warning Red for Expenses
  static const Color infoColor = Color(0xFF0077FF); // Bright Blue for transfers/info

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF9F9FB);
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0D0E0F);
  static const Color lightTextSecondary = Color(0xFF91919F);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF130E26); // Deep space purple
  static const Color darkCard = Color(0xFF1F193C); // Rich dark purple card
  static const Color darkTextPrimary = Color(0xFFFDFFFE);
  static const Color darkTextSecondary = Color(0xFF91919F);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      canvasColor: lightCard,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: Color(0xFF8B5CF6),
        tertiary: Color(0xFFFFC0E4),
        surface: lightBg,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: lightBg,
        surfaceContainerHighest: Color(0xFFF0F0F5),
        onSurface: lightTextPrimary,
        error: expenseColor,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: lightTextPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCard,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightCard,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: lightTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: lightTextSecondary,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        modalBackgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: lightTextPrimary,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: primaryColor,
        labelColor: primaryColor,
        unselectedLabelColor: lightTextSecondary,
        dividerColor: Color(0xFFEEEEEE),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: lightTextSecondary,
        textColor: lightTextPrimary,
      ),
      datePickerTheme: const DatePickerThemeData(
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: const TextStyle(color: lightTextSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      canvasColor: darkCard,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: Color(0xFF9F75FF),
        tertiary: Color(0xFFFFD4EC),
        surface: darkBg,
        surfaceContainerLowest: darkBg,
        surfaceContainerLow: darkCard,
        surfaceContainer: darkCard,
        surfaceContainerHigh: Color(0xFF261F48),
        surfaceContainerHighest: Color(0xFF2F2757),
        onSurface: darkTextPrimary,
        error: expenseColor,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2454), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: darkTextPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: Color(0xFF9F75FF),
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF2C2454),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF9F75FF));
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9F75FF),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: darkTextSecondary,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        modalBackgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: primaryColor,
        labelColor: Color(0xFF9F75FF),
        unselectedLabelColor: darkTextSecondary,
        dividerColor: Color(0xFF2C2454),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C2454),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkTextSecondary,
        textColor: darkTextPrimary,
      ),
      datePickerTheme: const DatePickerThemeData(
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2C2454)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2C2454)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextSecondary),
      ),
    );
  }
}
