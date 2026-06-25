import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  AppGradients._();

  /// Background decorative — top-right pink
  static const LinearGradient bgPinkTopRight = LinearGradient(
    colors: [Color(0x1Fe91d7c), Color(0x00e91d7c)],
    begin: Alignment.topRight,
    end: Alignment.centerLeft,
  );

  /// Background decorative — bottom-left purple
  static const LinearGradient bgPurpleBottomLeft = LinearGradient(
    colors: [Color(0x14402e91), Color(0x00402e91)],
    begin: Alignment.bottomLeft,
    end: Alignment.center,
  );

  /// Me header — indigo → pink → rose
  static const LinearGradient meHeader = LinearGradient(
    colors: [Color(0xFF312e81), Color(0xFFe91d7c), Color(0xFFf43f5e)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Save button — pink → purple
  static const LinearGradient saveButton = LinearGradient(
    colors: [AppColors.brandPink, AppColors.brandPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Plans header — rose → pink → orange
  static const LinearGradient plansHeader = LinearGradient(
    colors: [Color(0xFFf43f5e), Color(0xFFe91d7c), Color(0xFFf97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Earnings header — green
  static const LinearGradient earningsHeader = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF16a34a)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Chat send button — rose → rose400
  static const LinearGradient chatSend = LinearGradient(
    colors: [Color(0xFFf43f5e), Color(0xFFf472b6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Say-Hi button — rose → orange
  static const LinearGradient sayHi = LinearGradient(
    colors: [Color(0xFFf43f5e), Color(0xFFf97316)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Payout modal — indigo → pink
  static const LinearGradient payoutModal = LinearGradient(
    colors: [Color(0xFF312e81), Color(0xFFe91d7c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
