import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/app_assets.dart';
import '../../core/app_theme.dart';
import '../../edge/insight.dart';
import '../../game/jester_lucky_game.dart';
import '../../services/storage_service.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/hud_overlay.dart';

class GameScreen extends StatefulWidget {
  static const route = '/game';

  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final JesterLuckyGame _game;

  bool _showGameOver = false;
  int _finalScore = 0;
  int _finalCoins = 0;
  bool _isNewRecord = false;
  int _bestScore = 0;
  int _bestCoins = 0;

  @override
  void initState() {
    super.initState();
    Insight.screen('game');
    Insight.event('game_start');
    _game = JesterLuckyGame(onGameOver: _handleGameOver);
  }

  Future<void> _handleGameOver(int score, int coins) async {
    final storage = await StorageService.getInstance();
    final isNew = await storage.reportRun(score: score, coins: coins);
    if (!mounted) return;
    Insight.event('game_over');
    Insight.tag('last_game_score', '$score');
    Insight.tag('last_game_coins', '$coins');
    if (isNew) Insight.event('game_new_record');
    setState(() {
      _finalScore = score;
      _finalCoins = coins;
      _isNewRecord = isNew;
      _bestScore = storage.bestScore;
      _bestCoins = storage.bestCoins;
      _showGameOver = true;
    });
  }

  void _retry() {
    Insight.event('game_retry');
    setState(() => _showGameOver = false);
    _game.reset();
  }

  void _goHome() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.background, fit: BoxFit.cover),
          GameWidget(game: _game),
          HudOverlay(game: _game),
          if (_showGameOver)
            GameOverOverlay(
              score: _finalScore,
              coins: _finalCoins,
              bestScore: _bestScore,
              bestCoins: _bestCoins,
              isNewRecord: _isNewRecord,
              onRetry: _retry,
              onHome: _goHome,
            ),
        ],
      ),
    );
  }
}
