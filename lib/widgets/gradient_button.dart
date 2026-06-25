import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Pill button with gradient fill — used for Save, Say-Hi, etc.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.gradient,
    this.onPressed,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
  });

  final String label;
  final LinearGradient gradient;
  final VoidCallback? onPressed;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadius.borderFull,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: (textStyle ?? AppTextStyles.textBaseBold)
              .copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}
