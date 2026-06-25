import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // Size scale from RN: 36/30/24/20/18/16/14/12/10/8 px
  static const TextStyle text5xl = TextStyle(fontSize: 36, fontWeight: FontWeight.w400);
  static const TextStyle text4xl = TextStyle(fontSize: 30, fontWeight: FontWeight.w400);
  static const TextStyle text3xl = TextStyle(fontSize: 24, fontWeight: FontWeight.w400);
  static const TextStyle text2xl = TextStyle(fontSize: 20, fontWeight: FontWeight.w400);
  static const TextStyle textXl  = TextStyle(fontSize: 18, fontWeight: FontWeight.w400);
  static const TextStyle textLg  = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
  static const TextStyle textBase = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const TextStyle textSm  = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
  static const TextStyle textXs  = TextStyle(fontSize: 10, fontWeight: FontWeight.w400);
  static const TextStyle text2xs = TextStyle(fontSize: 8,  fontWeight: FontWeight.w400);

  // Bold variants
  static const TextStyle text5xlBold = TextStyle(fontSize: 36, fontWeight: FontWeight.w700);
  static const TextStyle text4xlBold = TextStyle(fontSize: 30, fontWeight: FontWeight.w700);
  static const TextStyle text3xlBold = TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
  static const TextStyle text2xlBold = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  static const TextStyle textXlBold  = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const TextStyle textLgBold  = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle textBaseBold = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const TextStyle textSmBold  = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
  static const TextStyle textXsBold  = TextStyle(fontSize: 10, fontWeight: FontWeight.w700);

  // Extra-bold (900)
  static const TextStyle textXlBlack  = TextStyle(fontSize: 18, fontWeight: FontWeight.w900);
  static const TextStyle text2xlBlack = TextStyle(fontSize: 20, fontWeight: FontWeight.w900);
  static const TextStyle text3xlBlack = TextStyle(fontSize: 24, fontWeight: FontWeight.w900);

  // Semi-bold (600)
  static const TextStyle textLgSemiBold  = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const TextStyle textBaseSemiBold = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const TextStyle textSmSemiBold  = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
}
