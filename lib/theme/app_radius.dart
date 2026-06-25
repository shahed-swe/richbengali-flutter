import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double full       = 999.0;
  static const double r24        = 24.0;
  static const double r16        = 16.0;
  static const double r12        = 12.0;
  static const double r8         = 8.0;
  static const double sheetTop   = 30.0;
  static const double plansHeaderBottom = 48.0;

  static const BorderRadius borderFull   = BorderRadius.all(Radius.circular(full));
  static const BorderRadius border24     = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius border16     = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius border12     = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius border8      = BorderRadius.all(Radius.circular(r8));
  static BorderRadius borderSheetTop     = const BorderRadius.only(
    topLeft:  Radius.circular(sheetTop),
    topRight: Radius.circular(sheetTop),
  );
}
