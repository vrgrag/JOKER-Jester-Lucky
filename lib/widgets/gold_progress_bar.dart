import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A left-to-right loading bar with a beveled gold frame.
///
/// [progress] must always reflect *real* completed work (0.0 - 1.0). The
/// widget only smooths the visual transition between updates -- it never
/// invents progress on its own, so the bar can never appear to finish
/// before the actual loading work behind it has completed.
class GoldProgressBar extends StatelessWidget {
  const GoldProgressBar({super.key, required this.progress, this.height = 26});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: AppColors.goldDeep, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(color: Colors.black.withValues(alpha: 0.3)),
            LayoutBuilder(
              builder: (context, constraints) {
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: clamped),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  builder: (context, value, _) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        heightFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppGradients.goldFill,
                            borderRadius: BorderRadius.circular(height),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.gold,
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
