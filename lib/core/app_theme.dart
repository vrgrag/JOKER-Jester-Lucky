import 'package:flutter/material.dart';

/// Carnival / royal-treasury color palette shared across every screen.
class AppColors {
  AppColors._();

  static const Color gold = Color(0xFFFFC94D);
  static const Color goldDeep = Color(0xFFB8860B);
  static const Color goldLight = Color(0xFFFFE9A8);
  static const Color purple = Color(0xFF6A1B9A);
  static const Color purpleDeep = Color(0xFF3B0764);
  static const Color green = Color(0xFF1B7A3D);
  static const Color greenDeep = Color(0xFF0F4D24);
  static const Color red = Color(0xFFC62828);
  static const Color ink = Color(0xFF1A1206);
  static const Color parchment = Color(0xFFFFF3D6);
}

/// A reusable gold gradient used for buttons, borders and progress fills.
class AppGradients {
  AppGradients._();

  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDeep],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient goldFill = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.goldDeep, AppColors.gold, AppColors.goldLight],
  );

  static const LinearGradient jesterCurtain = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.purpleDeep, Color(0xFF120521)],
  );
}

/// Text style helper for the carnival-styled bold headings used
/// throughout the UI (menu titles, buttons, HUD counters).
TextStyle jesterTextStyle({
  required double size,
  Color color = AppColors.parchment,
  FontWeight weight = FontWeight.w900,
  double letterSpacing = 1.2,
  List<Shadow>? shadows,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.0,
    shadows: shadows ??
        const [
          Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 4),
          Shadow(color: AppColors.ink, offset: Offset(0, 0), blurRadius: 10),
        ],
  );
}
