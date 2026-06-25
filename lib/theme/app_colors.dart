import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static Color fromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  // Brand Pink
  static const Color brandPink = Color(0xFFe91d7c);
  static const Color brandPink400 = Color(0xFFf472b6);
  static const Color brandPink500 = Color(0xFFec4899);
  static const Color brandPink700 = Color(0xFFbe185d);

  // Brand Purple
  static const Color brandPurple = Color(0xFF402e91);
  static const Color brandPurple400 = Color(0xFF818cf8);
  static const Color brandPurple500 = Color(0xFF6366f1);
  static const Color brandPurple700 = Color(0xFF312e81);

  // Gray scale
  static const Color gray50  = Color(0xFFf9fafb);
  static const Color gray100 = Color(0xFFf3f4f6);
  static const Color gray200 = Color(0xFFe5e7eb);
  static const Color gray300 = Color(0xFFd1d5db);
  static const Color gray400 = Color(0xFF9ca3af);
  static const Color gray500 = Color(0xFF6b7280);
  static const Color gray600 = Color(0xFF4b5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1f2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color graySlate = Color(0xFF0f172a);

  // Greens
  static const Color green400 = Color(0xFF4ade80);
  static const Color green500 = Color(0xFF22c55e);
  static const Color green600 = Color(0xFF16a34a);
  static const Color green700 = Color(0xFF15803d);
  static const Color green800 = Color(0xFF166534);
  static const Color emerald500 = Color(0xFF10b981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);

  // Rose / danger
  static const Color rose500 = Color(0xFFf43f5e);
  static const Color orange500 = Color(0xFFf97316);
  static const Color danger    = Color(0xFFef4444);
  static const Color dangerIOS = Color(0xFFff3b30);

  // Call darks
  static const Color callDarkBg  = Color(0xFF0b141a);
  static const Color callBlack   = Color(0xFF000000);
  static const Color callDarkIOS = Color(0xFF1c1c1e);

  // Borders
  static const Color border100 = Color(0xFFf3f4f6);
  static const Color border200 = Color(0xFFe5e7eb);
  static const Color border300 = Color(0xFFd1d5db);

  // Card backgrounds
  static const Color cardRose   = Color(0xFFfff1f2);
  static const Color cardBlue   = Color(0xFFeff6ff);
  static const Color cardBlue100 = Color(0xFFdbeafe);
  static const Color cardAmber  = Color(0xFFfffbeb);
  static const Color cardAmber100 = Color(0xFFfef3c7);

  static const Color white = Color(0xFFffffff);
}
