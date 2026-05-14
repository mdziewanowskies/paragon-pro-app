import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_theme_colors.dart';

class AppTheme {
  AppTheme._();

  static const double borderRadius = 12.0;

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        extensions: const [AppThemeColors.light],
        colorScheme: const ColorScheme.light(
          primary: AppColors.lightPrimary,
          secondary: AppColors.lightSecondary,
          surface: AppColors.lightCard,
          error: AppColors.lightDestructive,
          onPrimary: Colors.white,
          onSecondary: AppColors.lightForeground,
          onSurface: AppColors.lightForeground,
          onError: Colors.white,
          outline: AppColors.lightBorder,
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        textTheme: AppTextStyles.textTheme.apply(
          bodyColor: AppColors.lightForeground,
          displayColor: AppColors.lightForeground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBackground,
          foregroundColor: AppColors.lightForeground,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lightPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            textStyle: AppTextStyles.textTheme.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.lightPrimary,
            side: const BorderSide(color: AppColors.lightPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            textStyle: AppTextStyles.textTheme.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.lightPrimary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide:
                const BorderSide(color: AppColors.lightPrimary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.lightDestructive),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
            color: AppColors.lightMutedForeground,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightBackground,
          selectedItemColor: AppColors.lightPrimary,
          unselectedItemColor: AppColors.lightMutedForeground,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.lightBackground,
          indicatorColor: AppColors.primary400.withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.primary400
                  : AppColors.lightMutedForeground,
              letterSpacing: 0.2,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: selected
                  ? AppColors.primary400
                  : AppColors.lightMutedForeground,
            );
          }),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.lightPrimary,
          unselectedLabelColor: AppColors.lightMutedForeground,
          indicatorColor: AppColors.lightPrimary,
          dividerColor: AppColors.lightBorder,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.lightSecondary,
          selectedColor: AppColors.lightPrimary,
          labelStyle: AppTextStyles.textTheme.labelMedium!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: const [AppThemeColors.dark],
        colorScheme: const ColorScheme.dark(
          primary: AppColors.darkPrimary,
          secondary: AppColors.darkSecondary,
          surface: AppColors.darkCard,
          error: AppColors.darkDestructive,
          onPrimary: Colors.white,
          onSecondary: AppColors.darkForeground,
          onSurface: AppColors.darkForeground,
          onError: Colors.white,
          outline: AppColors.darkBorder,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: AppTextStyles.textTheme.apply(
          bodyColor: AppColors.darkForeground,
          displayColor: AppColors.darkForeground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkForeground,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            textStyle: AppTextStyles.textTheme.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkAccent,
            side: const BorderSide(color: AppColors.darkAccent),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            textStyle: AppTextStyles.textTheme.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.darkAccent,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide:
                const BorderSide(color: AppColors.darkPrimary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.darkDestructive),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
            color: AppColors.darkMutedForeground,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkBackground,
          selectedItemColor: AppColors.darkAccent,
          unselectedItemColor: AppColors.darkMutedForeground,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        // Material 3 NavigationBar (używany w DashboardScreen).
        // Capsule pod aktywnym tabem to standard M3 — dodajemy
        // semantyczne kolory (primary400 z opacity 0.16) zamiast
        // niebieskiego defaultu.
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface0,
          indicatorColor: AppColors.primary400.withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.primary400
                  : AppColors.textSecondary,
              letterSpacing: 0.2,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: selected
                  ? AppColors.primary400
                  : AppColors.textSecondary,
            );
          }),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.darkAccent,
          unselectedLabelColor: AppColors.darkMutedForeground,
          indicatorColor: AppColors.darkAccent,
          dividerColor: AppColors.darkBorder,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.darkSecondary,
          selectedColor: AppColors.darkPrimary,
          labelStyle: AppTextStyles.textTheme.labelMedium!.copyWith(
            color: AppColors.darkForeground,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.darkCard,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        pageTransitionsTheme: _smoothTransitions,
        splashFactory: InkSparkle.splashFactory,
      );

  static const PageTransitionsTheme _smoothTransitions =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    },
  );
}
