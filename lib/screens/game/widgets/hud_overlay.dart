import 'package:flutter/material.dart';

import '../../../core/app_assets.dart';
import '../../../core/app_theme.dart';
import '../../../game/jester_lucky_game.dart';

/// Always-on gameplay HUD: score, coins collected and the Jackpot gauge.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final JesterLuckyGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: game.score,
                  builder: (context, value, _) => _Chip(
                    icon: Icons.star_rounded,
                    iconColor: AppColors.gold,
                    label: '$value',
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: game.coins,
                  builder: (context, value, _) => _Chip(
                    imageAsset: AppAssets.coin,
                    label: '$value',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: Listenable.merge([game.jackpot, game.jackpotReady]),
              builder: (context, _) {
                return _JackpotGauge(
                  progress: game.jackpot.value,
                  ready: game.jackpotReady.value,
                  onTap: game.jackpotReady.value ? game.activateJackpot : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({this.icon, this.iconColor, this.imageAsset, required this.label});

  final IconData? icon;
  final Color? iconColor;
  final String? imageAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldDeep, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: iconColor, size: 20),
          if (imageAsset != null) Image.asset(imageAsset!, width: 22, height: 22),
          const SizedBox(width: 8),
          Text(label, style: jesterTextStyle(size: 18)),
        ],
      ),
    );
  }
}

class _JackpotGauge extends StatelessWidget {
  const _JackpotGauge({
    required this.progress,
    required this.ready,
    required this.onTap,
  });

  final double progress;
  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: ready ? AppColors.gold : AppColors.goldDeep,
            width: ready ? 3 : 2,
          ),
          boxShadow: ready
              ? const [BoxShadow(color: AppColors.gold, blurRadius: 14, spreadRadius: 1)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.3)),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppGradients.goldFill,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  ready ? 'TAP FOR JACKPOT!' : 'JACKPOT',
                  style: jesterTextStyle(
                    size: 14,
                    color: ready ? AppColors.ink : AppColors.parchment,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              child: Image.asset(AppAssets.jackpot, width: 34, height: 34),
            ),
          ],
        ),
      ),
    );
  }
}
