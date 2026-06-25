import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brandPink,
      primary: AppColors.brandPink,
      secondary: AppColors.brandPurple,
      surface: AppColors.white,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.gray900,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: TextTheme(
      displayLarge:  AppTextStyles.text5xl,
      displayMedium: AppTextStyles.text4xl,
      displaySmall:  AppTextStyles.text3xl,
      headlineLarge: AppTextStyles.text2xlBold,
      headlineMedium: AppTextStyles.textXlBold,
      headlineSmall:  AppTextStyles.textLgBold,
      titleLarge:   AppTextStyles.textXlBold,
      titleMedium:  AppTextStyles.textLgSemiBold,
      titleSmall:   AppTextStyles.textBaseSemiBold,
      bodyLarge:    AppTextStyles.textLg,
      bodyMedium:   AppTextStyles.textBase,
      bodySmall:    AppTextStyles.textSm,
      labelLarge:   AppTextStyles.textSmBold,
      labelMedium:  AppTextStyles.textXsBold,
      labelSmall:   AppTextStyles.text2xs,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPink,
        foregroundColor: AppColors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        textStyle: AppTextStyles.textBaseBold,
      ),
    ),
    dividerColor: AppColors.border100,
    cardColor: AppColors.white,
  );
}
