import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A big carnival-styled button used across menu / game-over screens.
class JesterButton extends StatelessWidget {
  const JesterButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.fontSize = 22,
    this.horizontalPadding = 36,
    this.verticalPadding = 16,
    this.borderColor = AppColors.goldDeep,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            gradient: AppGradients.goldButton,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: borderColor, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.ink, size: fontSize + 4),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
