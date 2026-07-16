import 'package:flutter/material.dart';

import '../../core/app_assets.dart';
import '../../core/app_theme.dart';
import '../../edge/insight.dart';
import '../../services/storage_service.dart';
import '../../widgets/jester_button.dart';
import '../game/game_screen.dart';
import '../webview/web_view_screen.dart';

class MainMenuScreen extends StatefulWidget {
  static const route = '/menu';

  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _bestScore = 0;
  int _bestCoins = 0;

  @override
  void initState() {
    super.initState();
    Insight.screen('menu');
    _loadBest();
  }

  Future<void> _loadBest() async {
    final storage = await StorageService.getInstance();
    if (!mounted) return;
    setState(() {
      _bestScore = storage.bestScore;
      _bestCoins = storage.bestCoins;
    });
  }

  Future<void> _play() async {
    await Navigator.of(context).pushNamed(GameScreen.route);
    _loadBest();
  }

  void _openWeb(String title, String url) {
    Navigator.of(context).pushNamed(
      WebViewScreen.route,
      arguments: WebViewScreenArgs(title: title, url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.background, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Image.asset(AppAssets.gameLogo, fit: BoxFit.contain),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          AppAssets.hero,
                          fit: BoxFit.contain,
                          height: 320,
                        ),
                      ),
                    ],
                  ),
                ),
                _RecordCard(bestScore: _bestScore, bestCoins: _bestCoins),
                const SizedBox(height: 18),
                JesterButton(label: 'PLAY', onTap: _play, icon: Icons.play_arrow_rounded, fontSize: 26),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FooterLink(
                      label: 'Privacy Policy',
                      onTap: () => _openWeb(
                        'Privacy Policy',
                        'https://jesterlucky.com/privacy-policy.html',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      color: AppColors.goldLight.withValues(alpha: 0.5),
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    _FooterLink(
                      label: 'Support',
                      onTap: () => _openWeb(
                        'Support',
                        'https://jesterlucky.com/support.html',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.bestScore, required this.bestCoins});

  final int bestScore;
  final int bestCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldDeep, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Text('BEST $bestScore', style: jesterTextStyle(size: 16)),
          const SizedBox(width: 18),
          Image.asset(AppAssets.coin, width: 20, height: 20),
          const SizedBox(width: 6),
          Text('$bestCoins', style: jesterTextStyle(size: 16)),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.goldLight.withValues(alpha: 0.85),
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.goldLight.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
