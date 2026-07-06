import 'package:flutter/material.dart';

import '../../../core/app_assets.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/jester_button.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.coins,
    required this.bestScore,
    required this.bestCoins,
    required this.isNewRecord,
    required this.onRetry,
    required this.onHome,
  });

  final int score;
  final int coins;
  final int bestScore;
  final int bestCoins;
  final bool isNewRecord;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
          decoration: BoxDecoration(
            gradient: AppGradients.jesterCurtain,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.goldDeep, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNewRecord ? 'NEW RECORD!' : 'TREASURY RAIDED!',
                textAlign: TextAlign.center,
                style: jesterTextStyle(size: 26, color: AppColors.gold),
              ),
              const SizedBox(height: 18),
              _StatRow(label: 'SCORE', value: '$score', icon: Icons.star_rounded),
              const SizedBox(height: 10),
              _StatRow(label: 'LUCKY COINS', value: '$coins', imageAsset: AppAssets.coin),
              const SizedBox(height: 10),
              _StatRow(
                label: 'BEST RECORD',
                value: '$bestScore  •  $bestCoins',
                icon: Icons.emoji_events_rounded,
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: JesterButton(
                      label: 'RETRY',
                      icon: Icons.replay_rounded,
                      fontSize: 18,
                      horizontalPadding: 18,
                      onTap: onRetry,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: JesterButton(
                      label: 'HOME',
                      icon: Icons.home_rounded,
                      fontSize: 18,
                      horizontalPadding: 18,
                      borderColor: AppColors.purpleDeep,
                      onTap: onHome,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.icon, this.imageAsset});

  final String label;
  final String value;
  final IconData? icon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: jesterTextStyle(size: 15, color: AppColors.goldLight)),
        Row(
          children: [
            if (icon != null) Icon(icon, color: AppColors.gold, size: 18),
            if (imageAsset != null) Image.asset(imageAsset!, width: 20, height: 20),
            const SizedBox(width: 6),
            Text(value, style: jesterTextStyle(size: 18)),
          ],
        ),
      ],
    );
  }
}
